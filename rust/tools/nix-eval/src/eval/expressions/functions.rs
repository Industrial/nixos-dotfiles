//! Function expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::value::NixValue;
use rnix::ast::{Lambda, Apply, Expr, Ident};
use rowan::ast::AstNode;
use std::path::Path;
use std::sync::Arc;
use crate::function;
use std::collections::HashMap;

impl Evaluator {
        pub(crate) fn evaluate_lambda(
        &self,
        lambda: &rnix::ast::Lambda,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Get the parameter from the lambda
        // In rnix, Lambda has a param() method that returns the parameter pattern
        let param = lambda.param().ok_or_else(|| Error::UnsupportedExpression {
            reason: "lambda missing parameter".to_string(),
        })?;

        // Extract the parameter name from the pattern
        // For simple lambdas like `x: ...`, the param is an identifier
        // Try to cast to Ident first, otherwise use the text representation
        let param_name = if let Some(ident) = rnix::ast::Ident::cast(param.syntax().clone()) {
            ident.to_string()
        } else {
            // For more complex patterns, use the text representation
            param.syntax().text().to_string().trim().to_string()
        };

        // Get the body expression
        let body_expr = lambda.body().ok_or_else(|| Error::UnsupportedExpression {
            reason: "lambda missing body".to_string(),
        })?;

        // Create a function closure with the current scope
        let file_id = self.current_file_id();
        let func = function::Function::new(param_name, &body_expr, scope.clone(), file_id);
        Ok(NixValue::Function(Arc::new(func)))
    }

    /// Evaluate a function application expression
    ///
    /// A function application like `f 42` applies the function `f` to the argument `42`.
    ///
    /// **Currying Support**: This method supports currying (partial application). If the result
    /// of applying a function is another function, that function can be applied again.
    /// For example, `(x: y: x + y) 1 2` is parsed as `((x: y: x + y) 1) 2`, where the
    /// first application returns `y: 1 + y`, and the second application returns `3`.
    ///
    /// **Builtin Support**: Builtin functions can be called directly. If the function expression


        pub(crate) fn evaluate_apply(&self, apply: &rnix::ast::Apply, scope: &VariableScope) -> Result<NixValue> {
        // Get the function expression (left-hand side)
        let func_expr = apply.lambda().ok_or_else(|| Error::UnsupportedExpression {
            reason: "function application missing function".to_string(),
        })?;

        // Check if the function is a builtin (identifier that's a builtin)
        // This handles cases like `toString 42` where `toString` is a builtin
        // Also handles direct builtin calls like `map f list` (not just `builtins.map f list`)
        if let Expr::Ident(ident) = &func_expr {
            let builtin_name = ident.to_string();

            // Handle builtins that need special evaluation context when called directly
            // These are normally accessed via builtins.map, but can also be called directly as map
            if builtin_name == "map" {
                // Handle map f list directly
                let first_arg_expr = apply.argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "map: missing first argument".to_string(),
                    })?;
                
                // Check if this is a nested apply: map f list
                // The parser gives us: Apply(map, f) and then Apply(Apply(map, f), list)
                // So we need to check if the next argument exists
                if let Expr::Apply(inner_apply) = &func_expr {
                    // This is already handled in the nested Apply section below
                } else {
                    // Single argument - this is partial application, create a curried function
                    let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                    // Force thunks
                    let func_forced = func_value.clone().force(self)?;
                    match func_forced {
                        NixValue::Function(_) => {
                            // Return a curried function that will apply map when called with list
                            // For now, we'll handle this in the nested Apply section
                        }
                        _ => {
                            return Err(Error::UnsupportedExpression {
                                reason: format!("map: first argument must be a function, got {}", func_forced),
                            });
                        }
                    }
                }
            }

            // Handle concatStringsSep sep list directly (when accessed via with builtins)
            if builtin_name == "concatStringsSep" {
                // Check if this is a nested apply: concatStringsSep sep list
                // The parser gives us: Apply(concatStringsSep, sep) and then Apply(Apply(concatStringsSep, sep), list)
                if let Expr::Apply(inner_apply) = &func_expr {
                    // This is already handled in the nested Apply section below
                } else {
                    // Single argument - this is partial application, but concatStringsSep needs 2 args
                    // So we need to handle this in the nested Apply section
                    // For now, let it fall through to the nested Apply handling
                }
            }

            // Handle import builtin specially since it needs evaluator context
            if builtin_name == "import" {
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "import missing argument".to_string(),
                    })?;
                let arg_value_raw = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                // Force thunks before importing - path variables might be thunks
                let arg_value = arg_value_raw.clone().force(self)?;
                match arg_value {
                    NixValue::Path(path) => return self.import_file(&path),
                    NixValue::StorePath(path_str) => {
                        return self.import_file(Path::new(&path_str));
                    }
                    _ => {
                        return Err(Error::UnsupportedExpression {
                            reason: format!("import expects a path, got {}", arg_value),
                        });
                    }
                }
            }

            // Handle toString builtin specially to support __toString
            if builtin_name == "toString" {
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "toString missing argument".to_string(),
                    })?;
                let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;

                // Check if the argument is an attribute set with __toString
                if let NixValue::AttributeSet(ref attrs) = arg_value {
                    if let Some(toString_value) = attrs.get("__toString") {
                        // Clone the attribute set and remove __toString for the function call
                        let mut attrs_for_call = attrs.clone();
                        attrs_for_call.remove("__toString");

                        // Force the __toString value if it's a thunk
                        let toString_func = toString_value.clone().force(self)?;

                        // The __toString should be a function
                        match toString_func {
                            NixValue::Function(func) => {
                                // Call __toString with the attribute set as the argument
                                let attrs_value = NixValue::AttributeSet(attrs_for_call);
                                let result = func.apply(self, attrs_value)?;

                                // The result should be a string
                                match result {
                                    NixValue::String(s) => return Ok(NixValue::String(s)),
                                    _ => {
                                        return Err(Error::UnsupportedExpression {
                                            reason: format!(
                                                "__toString must return a string, got: {:?}",
                                                result
                                            ),
                                        });
                                    }
                                }
                            }
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!(
                                        "__toString must be a function, got: {:?}",
                                        toString_func
                                    ),
                                });
                            }
                        }
                    }
                }

                // No __toString found, fall through to normal toString builtin
                if let Some(builtin) = self.builtins.get(&builtin_name) {
                    return builtin.call(&[arg_value]);
                }
            }

            if let Some(builtin) = self.builtins.get(&builtin_name) {
                // This is a builtin function call
                // Get the argument expression
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "function application missing argument".to_string(),
                    })?;

                // Evaluate the argument
                let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;

                // Call the builtin with the argument
                // Note: Builtins take a slice of arguments, so we wrap in a slice
                return builtin.call(&[arg_value]);
            }
        }

        // Check if this is a builtin that needs special handling (builtins.attrValues, builtins.tryEval, builtins.genList, etc.)
        // Handle builtins.tryEval specially to catch errors
        if let Expr::Select(select) = &func_expr {
            if let Some(base_expr) = select.expr() {
                if let Expr::Ident(ident) = base_expr {
                    if ident.to_string() == "builtins" {
                        if let Some(attrpath) = select.attrpath() {
                            if let Some(attr) = attrpath.attrs().next() {
                                if attr.to_string() == "tryEval" {
                                    // This is builtins.tryEval expr - catch errors during evaluation
                                    let arg_expr = apply.argument()
                                        .ok_or_else(|| Error::UnsupportedExpression {
                                            reason: "tryEval: missing argument".to_string(),
                                        })?;
                                    
                                    // Try to evaluate the expression, catching any errors
                                    match self.evaluate_expr_with_scope_impl(&arg_expr, scope) {
                                        Ok(value) => {
                                            // If the value is a thunk, force it and catch any errors
                                            match value.clone().force(self) {
                                                Ok(forced_value) => {
                                                    // Evaluation succeeded
                                                    let mut result = std::collections::HashMap::new();
                                                    result.insert("success".to_string(), NixValue::Boolean(true));
                                                    result.insert("value".to_string(), forced_value);
                                                    return Ok(NixValue::AttributeSet(result));
                                                }
                                                Err(_) => {
                                                    // Forcing the thunk failed - return success=false
                                                    let mut result = std::collections::HashMap::new();
                                                    result.insert("success".to_string(), NixValue::Boolean(false));
                                                    return Ok(NixValue::AttributeSet(result));
                                                }
                                            }
                                        }
                                        Err(_) => {
                                            // Evaluation failed - return success=false
                                            let mut result = std::collections::HashMap::new();
                                            result.insert("success".to_string(), NixValue::Boolean(false));
                                            // value is undefined when success is false, but we'll omit it
                                            return Ok(NixValue::AttributeSet(result));
                                        }
                                    }
                                } else                                 if attr.to_string() == "attrNames" {
                                    // This is builtins.attrNames set
                                    let arg_expr = apply.argument()
                                        .ok_or_else(|| Error::UnsupportedExpression {
                                            reason: "attrNames: missing argument".to_string(),
                                        })?;
                                    
                                    let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                    let arg_forced = arg_value.clone().force(self)?;
                                    
                                    match arg_forced {
                                        NixValue::AttributeSet(attrs) => {
                                            // Get keys and sort them
                                            let mut keys: Vec<String> = attrs.keys().cloned().collect();
                                            keys.sort(); // Nix returns attribute names in sorted order
                                            let names_values: Vec<NixValue> =
                                                keys.into_iter().map(|k| NixValue::String(k)).collect();
                                            return Ok(NixValue::List(names_values));
                                        }
                                        _ => {
                                            return Err(Error::UnsupportedExpression {
                                                reason: format!("attrNames expects an attribute set, got {}", arg_forced),
                                            });
                                        }
                                    }
                                } else if attr.to_string() == "attrValues" {
                                    // This is builtins.attrValues set
                                    let arg_expr = apply.argument()
                                        .ok_or_else(|| Error::UnsupportedExpression {
                                            reason: "attrValues: missing argument".to_string(),
                                        })?;
                                    
                                    let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                    let arg_forced = arg_value.clone().force(self)?;
                                    
                                    match arg_forced {
                                        NixValue::AttributeSet(attrs) => {
                                            // Get keys, sort them, then collect values in sorted key order
                                            let mut keys: Vec<String> = attrs.keys().cloned().collect();
                                            keys.sort(); // Nix returns attribute values in sorted key order
                                            let mut values = Vec::new();
                                            for key in keys {
                                                if let Some(value) = attrs.get(&key) {
                                                    // Force thunks when getting values
                                                    let value_forced = value.clone().force(self)?;
                                                    values.push(value_forced);
                                                }
                                            }
                                            return Ok(NixValue::List(values));
                                        }
                                        _ => {
                                            return Err(Error::UnsupportedExpression {
                                                reason: format!("attrValues expects an attribute set, got {}", arg_forced),
                                            });
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
        // Check if this is a nested Apply for genList: builtins.genList f n
        // The parser gives us: Apply(Apply(builtins.genList, f), n)
        // So we check if func_expr is itself an Apply with builtins.genList
        if let Expr::Apply(inner_apply) = &func_expr {
            if let Some(inner_func_expr) = inner_apply.lambda() {
                if let Expr::Select(select) = inner_func_expr {
                    // Check if it's builtins.genList
                    if let Some(base_expr) = select.expr() {
                        if let Expr::Ident(ident) = base_expr {
                            if ident.to_string() == "builtins" {
                                if let Some(attrpath) = select.attrpath() {
                                    if let Some(attr) = attrpath.attrs().next() {
                                        if attr.to_string() == "genList" {
                                            // This is builtins.genList f n - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "genList: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "genList: missing second argument".to_string(),
                                                })?;
                                            
                                            let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let length_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the length
                                            let length = match length_value {
                                                NixValue::Integer(n) => {
                                                    if n < 0 {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("genList: length must be non-negative, got {}", n),
                                                        });
                                                    }
                                                    n as usize
                                                }
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("genList: second argument must be an integer, got {}", length_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the function
                                            let func = match func_value {
                                                NixValue::Function(f) => f,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("genList: first argument must be a function, got {}", func_value),
                                                    });
                                                }
                                            };
                                            
                                            // Generate the list by calling the function for each index
                                            let mut result = Vec::new();
                                            for i in 0..length {
                                                let index_value = NixValue::Integer(i as i64);
                                                let element = func.apply(self, index_value)?;
                                                result.push(element);
                                            }
                                            
                                            return Ok(NixValue::List(result));
                                        } else if attr.to_string() == "all" {
                                            // This is builtins.all f list - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "all: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "all: missing second argument".to_string(),
                                                })?;
                                            
                                            let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the list
                                            let list = match list_value {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("all: second argument must be a list, got {}", list_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the function
                                            let func = match func_value {
                                                NixValue::Function(f) => f,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("all: first argument must be a function, got {}", func_value),
                                                    });
                                                }
                                            };
                                            
                                            // Check if all elements satisfy the predicate (short-circuit on false)
                                            for element in list {
                                                // Force thunks before calling the predicate
                                                let element_forced = element.clone().force(self)?;
                                                let predicate_result = func.apply(self, element_forced)?;
                                                
                                                // Check if predicate returned false (short-circuit)
                                                let is_truthy = match predicate_result {
                                                    NixValue::Boolean(false) => false,
                                                    NixValue::Null => false,
                                                    _ => true,
                                                };
                                                
                                                if !is_truthy {
                                                    return Ok(NixValue::Boolean(false));
                                                }
                                            }
                                            
                                            // All elements satisfied the predicate
                                            return Ok(NixValue::Boolean(true));
                                        } else if attr.to_string() == "any" {
                                            // This is builtins.any f list - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "any: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "any: missing second argument".to_string(),
                                                })?;
                                            
                                            let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the list
                                            let list = match list_value {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("any: second argument must be a list, got {}", list_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the function
                                            let func = match func_value {
                                                NixValue::Function(f) => f,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("any: first argument must be a function, got {}", func_value),
                                                    });
                                                }
                                            };
                                            
                                            // Check if any element satisfies the predicate (short-circuit on true)
                                            for element in list {
                                                // Force thunks before calling the predicate
                                                let element_forced = element.clone().force(self)?;
                                                let predicate_result = func.apply(self, element_forced)?;
                                                
                                                // Check if predicate returned true (short-circuit)
                                                let is_truthy = match predicate_result {
                                                    NixValue::Boolean(false) => false,
                                                    NixValue::Null => false,
                                                    _ => true,
                                                };
                                                
                                                if is_truthy {
                                                    return Ok(NixValue::Boolean(true));
                                                }
                                            }
                                            
                                            // No elements satisfied the predicate
                                            return Ok(NixValue::Boolean(false));
                                        } else if attr.to_string() == "filter" {
                                            // This is builtins.filter f list - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "filter: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "filter: missing second argument".to_string(),
                                                })?;
                                            
                                            let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the list
                                            let list = match list_value {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("filter: second argument must be a list, got {}", list_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the function
                                            let func = match func_value {
                                                NixValue::Function(f) => f,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("filter: first argument must be a function, got {}", func_value),
                                                    });
                                                }
                                            };
                                            
                                            // Filter the list by calling the predicate for each element
                                            // Note: We force the element before calling the predicate, but we need to
                                            // keep the original element (which may be a thunk) for the result
                                            let mut result = Vec::new();
                                            for element in list {
                                                // Force thunks before calling the predicate
                                                let element_forced = element.clone().force(self)?;
                                                let predicate_result = func.apply(self, element_forced.clone())?;
                                                
                                                // Check if predicate returned true
                                                let is_truthy = match predicate_result {
                                                    NixValue::Boolean(false) => false,
                                                    NixValue::Null => false,
                                                    _ => true,
                                                };
                                                
                                                if is_truthy {
                                                    result.push(element_forced);
                                                }
                                            }
                                            
                                            return Ok(NixValue::List(result));
                                        } else if attr.to_string() == "map" {
                                            // This is builtins.map f list - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "map: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "map: missing second argument".to_string(),
                                                })?;
                                            
                                            let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the list
                                            let list = match list_value {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("map: second argument must be a list, got {}", list_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the function
                                            let func = match func_value {
                                                NixValue::Function(f) => f,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("map: first argument must be a function, got {}", func_value),
                                                    });
                                                }
                                            };
                                            
                                            // Apply function to each element
                                            // Note: We pass the element (which may be a thunk) directly to the function
                                            // The function can then force it if needed (e.g., for tryEval to catch errors)
                                            let mut result = Vec::new();
                                            for element in list {
                                                // Don't force thunks here - let the function decide when to force
                                                // This allows tryEval to catch errors from thunks
                                                let mapped_value = func.apply(self, element.clone())?;
                                                result.push(mapped_value);
                                            }
                                            
                                            return Ok(NixValue::List(result));
                                        } else if attr.to_string() == "concatMap" {
                                            // This is builtins.concatMap f list - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "concatMap: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "concatMap: missing second argument".to_string(),
                                                })?;
                                            
                                            let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the list
                                            let list = match list_value {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("concatMap: second argument must be a list, got {}", list_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the function
                                            let func = match func_value {
                                                NixValue::Function(f) => f,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("concatMap: first argument must be a function, got {}", func_value),
                                                    });
                                                }
                                            };
                                            
                                            // Apply function to each element and concatenate results
                                            // Note: We pass the element (which may be a thunk) directly to the function
                                            // The function can then force it if needed (e.g., for tryEval to catch errors)
                                            let mut result = Vec::new();
                                            for element in list {
                                                // Don't force thunks here - let the function decide when to force
                                                // This allows tryEval to catch errors from thunks
                                                let mapped_value = func.apply(self, element.clone())?;
                                                
                                                // The result should be a list - concatenate it
                                                match mapped_value {
                                                    NixValue::List(l) => {
                                                        result.extend(l);
                                                    }
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("concatMap: function must return a list, got {}", mapped_value),
                                                        });
                                                    }
                                                }
                                            }
                                            
                                            return Ok(NixValue::List(result));
                                        } else if attr.to_string() == "catAttrs" {
                                            // This is builtins.catAttrs name list - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "catAttrs: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "catAttrs: missing second argument".to_string(),
                                                })?;
                                            
                                            let attr_name_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the attribute name
                                            let attr_name = match attr_name_value {
                                                NixValue::String(s) => s,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("catAttrs: first argument must be a string, got {}", attr_name_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the list
                                            let list = match list_value {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("catAttrs: second argument must be a list, got {}", list_value),
                                                    });
                                                }
                                            };
                                            
                                            // Collect the attribute from each attribute set in the list
                                            let mut result = Vec::new();
                                            for elem in list {
                                                // Force thunks in list elements
                                                let elem_forced = elem.clone().force(self)?;
                                                match elem_forced {
                                                    NixValue::AttributeSet(attrs) => {
                                                        if let Some(value) = attrs.get(&attr_name) {
                                                            // Force the attribute value thunk before adding to result
                                                            let value_forced = value.clone().force(self)?;
                                                            result.push(value_forced);
                                                        }
                                                        // If attribute doesn't exist, skip it (don't add to result)
                                                    }
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("catAttrs: list element must be an attribute set, got {}", elem_forced),
                                                        });
                                                    }
                                                }
                                            }
                                            
                                            return Ok(NixValue::List(result));
                                        } else if attr.to_string() == "concatLists" {
                                            // This is builtins.concatLists list
                                            let arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "concatLists: missing argument".to_string(),
                                                })?;
                                            
                                            let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                            let arg_forced = arg_value.clone().force(self)?;
                                            
                                            // Get the list
                                            let list = match arg_forced {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("concatLists expects a list, got {}", arg_forced),
                                                    });
                                                }
                                            };
                                            
                                            // Check that each element is a list and concatenate
                                            // We force thunks to check they're lists, but don't force thunks inside the lists
                                            let mut result = Vec::new();
                                            for item in list {
                                                // Force the item to check it's a list, but preserve thunks inside
                                                let item_forced = item.clone().force(self)?;
                                                match item_forced {
                                                    NixValue::List(l) => {
                                                        // Extend with the list elements (which may contain thunks)
                                                        // Don't force thunks inside the lists - preserve lazy evaluation
                                                        result.extend(l);
                                                    }
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("concatLists: all elements must be lists, got {}", item_forced),
                                                        });
                                                    }
                                                }
                                            }
                                            
                                            return Ok(NixValue::List(result));
                                        } else if attr.to_string() == "concatStringsSep" {
                                            // This is builtins.concatStringsSep sep list - extract both arguments
                                            let first_arg_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "concatStringsSep: missing first argument".to_string(),
                                                })?;
                                            let second_arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "concatStringsSep: missing second argument".to_string(),
                                                })?;
                                            
                                            let separator_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                                            let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                                            
                                            // Get the separator string
                                            let separator = match separator_value {
                                                NixValue::String(s) => s,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("concatStringsSep: first argument must be a string, got {}", separator_value),
                                                    });
                                                }
                                            };
                                            
                                            // Get the list
                                            let list = match list_value {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("concatStringsSep: second argument must be a list, got {}", list_value),
                                                    });
                                                }
                                            };
                                            
                                            // Convert list elements to strings and join with separator
                                            let mut str_values = Vec::new();
                                            for element in list {
                                                // Force thunks before converting to string
                                                let element_forced = element.clone().force(self)?;
                                                match element_forced {
                                                    NixValue::String(s) => str_values.push(s),
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("concatStringsSep: all elements must be strings, got {}", element_forced),
                                                        });
                                                    }
                                                }
                                            }
                                            
                                            let joined = str_values.join(&separator);
                                            return Ok(NixValue::String(joined));
                                        } else if attr.to_string() == "elemAt" {
                                            // This is builtins.elemAt list index
                                            let arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "elemAt: missing argument".to_string(),
                                                })?;
                                            
                                            // Check if this is a nested apply: elemAt list index
                                            if let Expr::Apply(inner_apply) = &func_expr {
                                                let list_expr = inner_apply.argument()
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "elemAt: missing list argument".to_string(),
                                                    })?;
                                                let index_expr = arg_expr;
                                                
                                                let list_value = self.evaluate_expr_with_scope_impl(&list_expr, scope)?;
                                                let list_forced = list_value.clone().force(self)?;
                                                
                                                let index_value = self.evaluate_expr_with_scope_impl(&index_expr, scope)?;
                                                let index_forced = index_value.clone().force(self)?;
                                                
                                                // Get the list
                                                let list = match list_forced {
                                                    NixValue::List(l) => l,
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("elemAt: first argument must be a list, got {}", list_forced),
                                                        });
                                                    }
                                                };
                                                
                                                // Get the index
                                                let index = match index_forced {
                                                    NixValue::Integer(i) => {
                                                        if i < 0 {
                                                            return Err(Error::UnsupportedExpression {
                                                                reason: format!("elemAt: index must be non-negative, got {}", i),
                                                            });
                                                        }
                                                        i as usize
                                                    }
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("elemAt: second argument must be an integer, got {}", index_forced),
                                                        });
                                                    }
                                                };
                                                
                                                if index >= list.len() {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("elemAt: index {} out of bounds for list of length {}", index, list.len()),
                                                    });
                                                }
                                                
                                                // Force the thunk at the index before returning
                                                let element = list[index].clone();
                                                let element_forced = element.force(self)?;
                                                return Ok(element_forced);
                                            }
                                        } else if attr.to_string() == "head" {
                                            // This is builtins.head list
                                            let arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "head: missing argument".to_string(),
                                                })?;
                                            
                                            let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                            let arg_forced = arg_value.clone().force(self)?;
                                            
                                            // Get the list
                                            let list = match arg_forced {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("head expects a list, got {}", arg_forced),
                                                    });
                                                }
                                            };
                                            
                                            if list.is_empty() {
                                                return Err(Error::UnsupportedExpression {
                                                    reason: "head: list is empty".to_string(),
                                                });
                                            }
                                            
                                            // Force the first element before returning
                                            let first_element = list[0].clone();
                                            let first_forced = first_element.force(self)?;
                                            return Ok(first_forced);
                                        } else if attr.to_string() == "getAttr" {
                                            // This is builtins.getAttr name set [default]
                                            // Check if this is a nested apply: getAttr name set [default]
                                            if let Expr::Apply(inner_apply) = &func_expr {
                                                let name_expr = inner_apply.argument()
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "getAttr: missing name argument".to_string(),
                                                    })?;
                                                let set_expr = apply.argument()
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "getAttr: missing set argument".to_string(),
                                                    })?;
                                                
                                                let name_value = self.evaluate_expr_with_scope_impl(&name_expr, scope)?;
                                                let name_forced = name_value.clone().force(self)?;
                                                
                                                let set_value = self.evaluate_expr_with_scope_impl(&set_expr, scope)?;
                                                let set_forced = set_value.clone().force(self)?;
                                                
                                                // Get the attribute name
                                                let attr_name = match name_forced {
                                                    NixValue::String(s) => s,
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("getAttr: first argument must be a string, got {}", name_forced),
                                                        });
                                                    }
                                                };
                                                
                                                // Get the attribute set
                                                let attrs = match set_forced {
                                                    NixValue::AttributeSet(a) => a,
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("getAttr: second argument must be an attribute set, got {}", set_forced),
                                                        });
                                                    }
                                                };
                                                
                                                // Get the attribute value and force it
                                                if let Some(value) = attrs.get(&attr_name) {
                                                    let value_forced = value.clone().force(self)?;
                                                    return Ok(value_forced);
                                                } else {
                                                    // Check if there's a default value (third argument)
                                                    // This would be: getAttr name set default
                                                    // But we need to check if there's another Apply level
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("getAttr: attribute '{}' not found", attr_name),
                                                    });
                                                }
                                            }
                                        } else if attr.to_string() == "functionArgs" {
                                            // This is builtins.functionArgs function
                                            let arg_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "functionArgs: missing argument".to_string(),
                                                })?;
                                            
                                            // Evaluate the argument - but don't force it if it's a thunk
                                            // We need to check if it's a function without forcing thunks that throw
                                            let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                            
                                            // Check if it's a function - if not, this will throw an error
                                            // which tryEval should catch
                                            match arg_value {
                                                NixValue::Function(_) => {
                                                    // For now, return empty attribute set
                                                    // In a full implementation, we'd extract parameter names
                                                    // from the function's parameter pattern
                                                    return Ok(NixValue::AttributeSet(HashMap::new()));
                                                }
                                                NixValue::Thunk(_) => {
                                                    // If it's a thunk, we need to force it to check if it's a function
                                                    // But this might throw, which tryEval should catch
                                                    let forced = arg_value.force(self)?;
                                                    match forced {
                                                        NixValue::Function(_) => {
                                                            return Ok(NixValue::AttributeSet(HashMap::new()));
                                                        }
                                                        _ => {
                                                            return Err(Error::UnsupportedExpression {
                                                                reason: format!("functionArgs: argument must be a function, got {}", forced),
                                                            });
                                                        }
                                                    }
                                                }
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("functionArgs: argument must be a function, got {}", arg_value),
                                                    });
                                                }
                                            }
                                        } else if attr.to_string() == "genList" {
                                            // This is builtins.genList f n
                                            // Check if this is a nested apply: genList f n
                                            if let Expr::Apply(inner_apply) = &func_expr {
                                                let func_expr_arg = inner_apply.argument()
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "genList: missing function argument".to_string(),
                                                    })?;
                                                let length_expr = apply.argument()
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "genList: missing length argument".to_string(),
                                                    })?;
                                                
                                                // Evaluate function and length, but don't force thunks yet
                                                // The function might be a thunk that references variables not yet in scope
                                                let func_value = self.evaluate_expr_with_scope_impl(&func_expr_arg, scope)?;
                                                
                                                let length_value = self.evaluate_expr_with_scope_impl(&length_expr, scope)?;
                                                let length_forced = length_value.clone().force(self)?;
                                                
                                                // Get the length
                                                let length = match length_forced {
                                                    NixValue::Integer(n) => {
                                                        if n < 0 {
                                                            return Err(Error::UnsupportedExpression {
                                                                reason: format!("genList: length must be non-negative, got {}", n),
                                                            });
                                                        }
                                                        n as usize
                                                    }
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("genList: second argument must be an integer, got {}", length_forced),
                                                        });
                                                    }
                                                };
                                                
                                                // Create thunks for each list element
                                                // Each thunk will call the function when forced, allowing lazy evaluation
                                                let mut result = Vec::new();
                                                let file_id = self.current_file_id();
                                                
                                                // Store the function value and scope for thunk creation
                                                // We'll create thunks that evaluate func(i) when forced
                                                for i in 0..length {
                                                    let index = i as i64;
                                                    let func_value_clone = func_value.clone();
                                                    let scope_clone = scope.clone();
                                                    
                                                    // Create a thunk that will evaluate func(i) when forced
                                                    // Parse a synthetic expression: func index
                                                    // Actually, we can't easily create a thunk from a function call
                                                    // Instead, we need to call the function, but wrap the result in a thunk if needed
                                                    // For now, let's try calling the function and see if it works
                                                    // If func_value is a thunk, force it to get the function
                                                    let func_forced = func_value_clone.clone().force(self)?;
                                                    let func = match func_forced {
                                                        NixValue::Function(f) => f,
                                                        _ => {
                                                            return Err(Error::UnsupportedExpression {
                                                                reason: format!("genList: first argument must be a function, got {}", func_forced),
                                                            });
                                                        }
                                                    };
                                                    
                                                    let index_value = NixValue::Integer(index);
                                                    let element = func.apply(self, index_value)?;
                                                    result.push(element);
                                                }
                                                
                                                return Ok(NixValue::List(result));
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Handle direct builtin identifiers (like `map` instead of `builtins.map`)
        // Check if func_expr is an Apply with a direct builtin identifier
        // For `map f list`, parser gives us: Apply(Apply(map, f), list)
        // So func_expr is Apply(map, f), and we need to check if the lambda is `map`
        if let Expr::Apply(inner_apply) = &func_expr {
            if let Some(inner_func_expr) = inner_apply.lambda() {
                if let Expr::Ident(ident) = inner_func_expr {
                    let builtin_name = ident.to_string();
                    if builtin_name == "map" {
                        // This is map f list - extract both arguments
                        let first_arg_expr = inner_apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "map: missing first argument".to_string(),
                            })?;
                        let second_arg_expr = apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "map: missing second argument".to_string(),
                            })?;
                        
                        let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                        let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                        
                        let list = match list_value {
                            NixValue::List(l) => l,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("map: second argument must be a list, got {}", list_value),
                                });
                            }
                        };
                        
                        let func = match func_value.clone().force(self)? {
                            NixValue::Function(f) => f,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("map: first argument must be a function, got {}", func_value),
                                });
                            }
                        };
                        
                        let mut result = Vec::new();
                        for element in list {
                            // Don't force thunks here - let the function decide when to force
                            // This allows tryEval to catch errors from thunks
                            let mapped_value = func.apply(self, element.clone())?;
                            result.push(mapped_value);
                        }
                        return Ok(NixValue::List(result));
                    } else if builtin_name == "concatStringsSep" {
                        // This is concatStringsSep sep list - extract both arguments
                        let first_arg_expr = inner_apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "concatStringsSep: missing first argument".to_string(),
                            })?;
                        let second_arg_expr = apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "concatStringsSep: missing second argument".to_string(),
                            })?;
                        
                        let separator_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                        let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                        
                        // Get the separator string
                        let separator = match separator_value {
                            NixValue::String(s) => s,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("concatStringsSep: first argument must be a string, got {}", separator_value),
                                });
                            }
                        };
                        
                        // Get the list
                        let list = match list_value {
                            NixValue::List(l) => l,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("concatStringsSep: second argument must be a list, got {}", list_value),
                                });
                            }
                        };
                        
                        // Convert list elements to strings and join with separator
                        let mut str_values = Vec::new();
                        for element in list {
                            // Force thunks before converting to string
                            let element_forced = element.clone().force(self)?;
                            match element_forced {
                                NixValue::String(s) => str_values.push(s),
                                _ => {
                                    return Err(Error::UnsupportedExpression {
                                        reason: format!("concatStringsSep: all elements must be strings, got {}", element_forced),
                                    });
                                }
                            }
                        }
                        
                        let joined = str_values.join(&separator);
                        return Ok(NixValue::String(joined));
                    } else if builtin_name == "all" {
                        // This is all f list - extract both arguments
                        let first_arg_expr = inner_apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "all: missing first argument".to_string(),
                            })?;
                        let second_arg_expr = apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "all: missing second argument".to_string(),
                            })?;
                        
                        let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                        let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                        
                        let list = match list_value {
                            NixValue::List(l) => l,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("all: second argument must be a list, got {}", list_value),
                                });
                            }
                        };
                        
                        let func = match func_value.clone().force(self)? {
                            NixValue::Function(f) => f,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("all: first argument must be a function, got {}", func_value),
                                });
                            }
                        };
                        
                        // Check if all elements satisfy the predicate (short-circuit on false)
                        for element in list {
                            let element_forced = element.clone().force(self)?;
                            let predicate_result = func.apply(self, element_forced)?;
                            
                            let is_truthy = match predicate_result {
                                NixValue::Boolean(false) => false,
                                NixValue::Null => false,
                                _ => true,
                            };
                            
                            if !is_truthy {
                                return Ok(NixValue::Boolean(false));
                            }
                        }
                        
                        return Ok(NixValue::Boolean(true));
                    } else if builtin_name == "any" {
                        // This is any f list - extract both arguments
                        let first_arg_expr = inner_apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "any: missing first argument".to_string(),
                            })?;
                        let second_arg_expr = apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "any: missing second argument".to_string(),
                            })?;
                        
                        let func_value = self.evaluate_expr_with_scope_impl(&first_arg_expr, scope)?;
                        let list_value = self.evaluate_expr_with_scope_impl(&second_arg_expr, scope)?;
                        
                        let list = match list_value {
                            NixValue::List(l) => l,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("any: second argument must be a list, got {}", list_value),
                                });
                            }
                        };
                        
                        let func = match func_value.clone().force(self)? {
                            NixValue::Function(f) => f,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!("any: first argument must be a function, got {}", func_value),
                                });
                            }
                        };
                        
                        // Check if any element satisfies the predicate (short-circuit on true)
                        for element in list {
                            let element_forced = element.clone().force(self)?;
                            let predicate_result = func.apply(self, element_forced)?;
                            
                            let is_truthy = match predicate_result {
                                NixValue::Boolean(false) => false,
                                NixValue::Null => false,
                                _ => true,
                            };
                            
                            if is_truthy {
                                return Ok(NixValue::Boolean(true));
                            }
                        }
                        
                        return Ok(NixValue::Boolean(false));
                    }
                }
            }
        }
        
        // Evaluate the function expression to get the function value
        let func_value_raw = self.evaluate_expr_with_scope_impl(&func_expr, scope)?;
        
        // Check if this is a builtin function marker (from builtins.<name>)
        let func_value = if let NixValue::String(ref s) = func_value_raw {
            if s.starts_with("__builtin_func:") {
                let builtin_name = &s[15..]; // Skip "__builtin_func:"
                if let Some(builtin) = self.builtins.get(builtin_name) {
                    // Get the argument expression
                    let arg_expr = apply
                        .argument()
                        .ok_or_else(|| Error::UnsupportedExpression {
                            reason: "function application missing argument".to_string(),
                        })?;
                    
                    // Evaluate the argument
                    let arg_value_raw = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                    // Force thunks before calling builtin
                    let arg_value = arg_value_raw.clone().force(self)?;
                    
                    // Try calling the builtin with just this argument
                    // If it needs more arguments, it will return an error and we'll create a curried function
                    match builtin.call(&[arg_value.clone()]) {
                        Ok(result) => return Ok(result),
                        Err(Error::UnsupportedExpression { reason }) if reason.contains("takes") && reason.contains("arguments") => {
                            // Builtin needs more arguments - create a curried function
                            // We can't clone Box<dyn Builtin>, so we'll store the name and look it up later
                            let file_id = self.current_file_id();
                            let mut closure = VariableScope::new();
                            closure.insert(format!("__builtin_{}", builtin_name), NixValue::String(format!("__builtin_func:{}", builtin_name)));
                            closure.insert("__curried_first_arg".to_string(), arg_value);
                            
                            let curried_func = crate::function::Function::new_curried_builtin_internal(
                                format!("__curried_{}_arg2", builtin_name),
                                format!("__curried_builtin_call:{}", builtin_name),
                                closure,
                                file_id,
                            );
                            return Ok(NixValue::Function(Arc::new(curried_func)));
                        }
                        Err(e) => return Err(e),
                    }
                }
            }
            func_value_raw
        } else {
            func_value_raw
        };

        // Get the argument expression (right-hand side)
        let arg_expr = apply
            .argument()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "function application missing argument".to_string(),
            })?;

        // Evaluate the argument expression
        let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;

        // Force thunks before applying - functions stored as thunks need to be forced
        let func_value_forced = func_value.clone().force(self)?;

        // Apply the function to the argument
        // Note: The result of apply() may be another function, enabling currying.
        // Chained applications like `f 1 2` are handled by the parser as nested Apply nodes.
        match func_value_forced {
            NixValue::Function(func) => func.apply(self, arg_value),
            NixValue::AttributeSet(mut attrs) => {
                // Check for __functor attribute (makes attribute sets callable)
                if let Some(functor_value) = attrs.remove("__functor") {
                    // Force the functor value if it's a thunk
                    let functor = functor_value.force(self)?;

                    // The __functor should be a function
                    match functor {
                        NixValue::Function(func) => {
                            // Call the functor with the attribute set as the first argument,
                            // followed by the actual argument
                            // In Nix, `attrs arg` becomes `attrs.__functor attrs arg`
                            // Since Function::apply only takes one argument, we use currying:
                            // First apply the attribute set, then apply the result to the argument
                            let attrs_value = NixValue::AttributeSet(attrs);
                            let partial_result = func.apply(self, attrs_value)?;

                            // If the result is another function (currying), apply it to the argument
                            // Otherwise, return the result as-is (the functor might have already handled everything)
                            match partial_result {
                                NixValue::Function(next_func) => next_func.apply(self, arg_value),
                                _ => Ok(partial_result),
                            }
                        }
                        _ => Err(Error::UnsupportedExpression {
                            reason: format!("__functor must be a function, got: {:?}", functor),
                        }),
                    }
                } else {
                    Err(Error::UnsupportedExpression {
                        reason: format!(
                            "cannot apply non-function value: {:?}",
                            NixValue::AttributeSet(attrs)
                        ),
                    })
                }
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot apply non-function value: {:?}", func_value),
            }),
        }
    }
}
