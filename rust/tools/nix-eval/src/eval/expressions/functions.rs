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

            // Handle foldl' directly (when accessed via with builtins)
            // foldl' takes 3 arguments: f init list
            // But can be partially applied with 2 arguments: f init (returns a function that takes list)
            if builtin_name == "foldl'" {
                // Check if this is a nested apply: foldl' f init list
                // The parser gives us: Apply(foldl', f), Apply(Apply(foldl', f), init), Apply(Apply(Apply(foldl', f), init), list)
                // We need to handle all these cases
                if let Expr::Apply(inner_apply) = &func_expr {
                    // This is already handled in the nested Apply section below
                    // But we need to make sure it's handled there
                } else {
                    // Single argument - this is partial application with 1 arg
                    // But foldl' needs at least 2 args, so this should fall through
                    // Actually, let it fall through to check if it's in the nested Apply section
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

            // Handle listToAttrs builtin specially - needs evaluator context for lazy evaluation
            if builtin_name == "listToAttrs" {
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "listToAttrs missing argument".to_string(),
                    })?;
                let list_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                
                // Force the list to get the actual list
                let list_forced = list_value.clone().force(self)?;
                let list = match list_forced {
                    NixValue::List(l) => l,
                    _ => {
                        return Err(Error::UnsupportedExpression {
                            reason: format!("listToAttrs expects a list, got {}", list_forced),
                        });
                    }
                };
                
                let mut attrs = HashMap::new();
                
                // Process each element in the list
                for elem in list {
                    // Force the element to get the attribute set (but don't force nested values)
                    let elem_forced = elem.clone().force(self)?;
                    
                    // Each element should be an attribute set with "name" and "value" keys
                    let elem_attrs = match elem_forced {
                        NixValue::AttributeSet(a) => a,
                        _ => {
                            return Err(Error::UnsupportedExpression {
                                reason: format!("listToAttrs: list element must be an attribute set, got {}", elem_forced),
                            });
                        }
                    };
                    
                    // Get the "name" attribute - force it to get the string
                    let name_value = elem_attrs.get("name")
                        .ok_or_else(|| Error::UnsupportedExpression {
                            reason: format!("listToAttrs: element must have a 'name' attribute"),
                        })?;
                    let name_forced = name_value.clone().force(self)?;
                    let name = match name_forced {
                        NixValue::String(s) => s,
                        _ => {
                            return Err(Error::UnsupportedExpression {
                                reason: format!("listToAttrs: element must have a 'name' string attribute, got {}", name_forced),
                            });
                        }
                    };
                    
                    // Get the "value" attribute - DON'T force it! Just clone it (preserves thunks)
                    let value = elem_attrs.get("value")
                        .ok_or_else(|| Error::UnsupportedExpression {
                            reason: format!("listToAttrs: element must have a 'value' attribute"),
                        })?
                        .clone();
                    
                    // Insert into result (first occurrence wins if duplicate names)
                    attrs.entry(name).or_insert(value);
                }
                
                return Ok(NixValue::AttributeSet(attrs));
            }

            // Handle toJSON builtin specially to support __toString in attribute sets
            if builtin_name == "toJSON" {
                let arg_expr = apply
                    .argument()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "toJSON missing argument".to_string(),
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

                                // The result should be a string - JSON-encode it (add quotes and escape)
                                match result {
                                    NixValue::String(s) => {
                                        // JSON-encode the string: escape quotes and backslashes, wrap in quotes
                                        let escaped: String = s
                                            .chars()
                                            .map(|c| match c {
                                                '"' => "\\\"".to_string(),
                                                '\\' => "\\\\".to_string(),
                                                '\n' => "\\n".to_string(),
                                                '\r' => "\\r".to_string(),
                                                '\t' => "\\t".to_string(),
                                                _ => c.to_string(),
                                            })
                                            .collect();
                                        return Ok(NixValue::String(format!("\"{}\"", escaped)));
                                    }
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
                // No __toString found, fall through to normal toJSON builtin
                // For now, return an error since we don't have full JSON serialization yet
                return Err(Error::UnsupportedExpression {
                    reason: "toJSON: full JSON serialization not yet implemented (only __toString attribute sets supported)".to_string(),
                });
            }

            // Handle foldl' specially when called directly (not via builtins.foldl')
            // foldl' requires evaluator context, so it can't be called via builtin.call()
            if builtin_name == "foldl'" {
                // Check if this is a nested apply: foldl' f init list
                // The parser gives us: Apply(foldl', f), Apply(Apply(foldl', f), init), Apply(Apply(Apply(foldl', f), init), list)
                // We need to handle this in the nested Apply section
                // For now, let it fall through to the nested Apply handling below
            }

            if let Some(builtin) = self.builtins.get(&builtin_name) {
                // Skip foldl' here since it needs special handling
                if builtin_name == "foldl'" {
                    // This will be handled in the nested Apply section below
                } else {
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
        }

        // Check if this is a builtin that needs special handling (builtins.attrValues, builtins.tryEval, builtins.genList, etc.)
        // Handle builtins.seq first (before Select check) since it might be nested
        // Structure: Apply(Apply(builtins.seq, a), b)
        // When evaluating outer Apply: func_expr = Apply(builtins.seq, a)
        if let Expr::Apply(inner_apply) = &func_expr {
            if let Some(inner_func_expr) = inner_apply.lambda() {
                if let Expr::Select(select) = inner_func_expr {
                    if let Some(base_expr) = select.expr() {
                        if let Expr::Ident(ident) = base_expr {
                            if ident.to_string() == "builtins" {
                                if let Some(attrpath) = select.attrpath() {
                                    if let Some(attr) = attrpath.attrs().next() {
                                        if attr.to_string() == "seq" {
                                            // This is builtins.seq a b
                                            let a_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "seq: missing first argument".to_string(),
                                                })?;
                                            let b_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "seq: missing second argument".to_string(),
                                                })?;
                                            
                                            // Evaluate both arguments
                                            let a_value = self.evaluate_expr_with_scope_impl(&a_expr, scope)?;
                                            let b_value = self.evaluate_expr_with_scope_impl(&b_expr, scope)?;
                                            
                                            // Force the first argument (evaluate any thunks)
                                            let _a_forced = a_value.clone().force(self)?;
                                            
                                            // Return the second argument
                                            return Ok(b_value);
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        
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
                                } else if attr.to_string() == "toJSON" {
                                    // This is builtins.toJSON value - handle __toString specially
                                    let arg_expr = apply.argument()
                                        .ok_or_else(|| Error::UnsupportedExpression {
                                            reason: "toJSON: missing argument".to_string(),
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
                                                    
                                                    // The result should be a string - JSON-encode it (add quotes and escape)
                                                    match result {
                                                        NixValue::String(s) => {
                                                            // JSON-encode the string: escape quotes and backslashes, wrap in quotes
                                                            let escaped: String = s
                                                                .chars()
                                                                .map(|c| match c {
                                                                    '"' => "\\\"".to_string(),
                                                                    '\\' => "\\\\".to_string(),
                                                                    '\n' => "\\n".to_string(),
                                                                    '\r' => "\\r".to_string(),
                                                                    '\t' => "\\t".to_string(),
                                                                    _ => c.to_string(),
                                                                })
                                                                .collect();
                                                            return Ok(NixValue::String(format!("\"{}\"", escaped)));
                                                        }
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
                                    // No __toString found, fall through to normal toJSON builtin
                                    if let Some(builtin) = self.builtins.get("toJSON") {
                                        let arg_forced = arg_value.clone().force(self)?;
                                        return builtin.call(&[arg_forced]);
                                    }
                                } else if attr.to_string() == "listToAttrs" {
                                    // This is builtins.listToAttrs list - handle specially to force thunks in list elements
                                    // but preserve thunks in values (lazy evaluation)
                                    let arg_expr = apply.argument()
                                        .ok_or_else(|| Error::UnsupportedExpression {
                                            reason: "listToAttrs: missing argument".to_string(),
                                        })?;
                                    
                                    let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                    let arg_forced = arg_value.clone().force(self)?;
                                    
                                    let list = match arg_forced {
                                        NixValue::List(l) => l,
                                        _ => {
                                            return Err(Error::UnsupportedExpression {
                                                reason: format!("listToAttrs expects a list, got {}", arg_forced),
                                            });
                                        }
                                    };
                                    
                                    let mut result = HashMap::new();
                                    for item in list {
                                        // Force thunks in list elements to get the attribute set
                                        let item_forced = item.clone().force(self)?;
                                        match item_forced {
                                            NixValue::AttributeSet(attrs) => {
                                                // Extract name and value attributes
                                                let name = attrs.get("name")
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "listToAttrs: attribute set missing 'name' attribute".to_string(),
                                                    })?;
                                                let value = attrs.get("value")
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "listToAttrs: attribute set missing 'value' attribute".to_string(),
                                                    })?;
                                                
                                                // Force the name to get the string value (name must be evaluated)
                                                let name_forced = name.clone().force(self)?;
                                                let name_str = match name_forced {
                                                    NixValue::String(s) => s,
                                                    _ => {
                                                        return Err(Error::UnsupportedExpression {
                                                            reason: format!("listToAttrs: 'name' must be a string, got {}", name_forced),
                                                        });
                                                    }
                                                };
                                                
                                                // Insert into result (later entries override earlier ones with the same name)
                                                // Keep value as-is (may be a thunk for lazy evaluation)
                                                result.insert(name_str, value.clone());
                                            }
                                            _ => {
                                                return Err(Error::UnsupportedExpression {
                                                    reason: format!("listToAttrs: list elements must be attribute sets, got {}", item_forced),
                                                });
                                            }
                                        }
                                    }
                                    
                                    return Ok(NixValue::AttributeSet(result));
                                } else if attr.to_string() == "elem" {
                                    // This is builtins.elem x xs - check if x is in list xs
                                    let arg_expr = apply.argument()
                                        .ok_or_else(|| Error::UnsupportedExpression {
                                            reason: "elem: missing argument".to_string(),
                                        })?;
                                    
                                    let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                    
                                    // elem is curried: builtins.elem x xs
                                    // Check if func_expr is itself an Apply with builtins.elem x
                                    if let Expr::Apply(inner_apply) = &func_expr {
                                        if let Some(inner_func_expr) = inner_apply.lambda() {
                                            if let Expr::Select(select) = inner_func_expr {
                                                if let Some(base_expr) = select.expr() {
                                                    if let Expr::Ident(ident) = base_expr {
                                                        if ident.to_string() == "builtins" {
                                                            if let Some(attrpath) = select.attrpath() {
                                                                if let Some(inner_attr) = attrpath.attrs().next() {
                                                                    if inner_attr.to_string() == "elem" {
                                                                        // This is builtins.elem x xs
                                                                        let x_expr = inner_apply.argument()
                                                                            .ok_or_else(|| Error::UnsupportedExpression {
                                                                                reason: "elem: missing first argument".to_string(),
                                                                            })?;
                                                                        let xs_expr = apply.argument()
                                                                            .ok_or_else(|| Error::UnsupportedExpression {
                                                                                reason: "elem: missing second argument".to_string(),
                                                                            })?;
                                                                        
                                                                        let x_value = self.evaluate_expr_with_scope_impl(&x_expr, scope)?;
                                                                        let xs_value = self.evaluate_expr_with_scope_impl(&xs_expr, scope)?;
                                                                        
                                                                        // Force the list to check elements
                                                                        let xs_forced = xs_value.clone().force(self)?;
                                                                        let list = match xs_forced {
                                                                            NixValue::List(l) => l,
                                                                            _ => {
                                                                                return Err(Error::UnsupportedExpression {
                                                                                    reason: format!("elem: second argument must be a list, got {}", xs_forced),
                                                                                });
                                                                            }
                                                                        };
                                                                        
                                                                        // Check if x is in the list (force thunks in list elements for comparison)
                                                                        for item in list {
                                                                            let item_forced = item.clone().force(self)?;
                                                                            // Compare using equality
                                                                            let eq_result = self.evaluate_equal(&x_value, &item_forced)?;
                                                                            if let NixValue::Boolean(true) = eq_result {
                                                                                return Ok(NixValue::Boolean(true));
                                                                            }
                                                                        }
                                                                        
                                                                        return Ok(NixValue::Boolean(false));
                                                                    }
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    // If not curried, return error (elem requires two arguments)
                                    return Err(Error::UnsupportedExpression {
                                        reason: "elem: requires two arguments (elem x xs)".to_string(),
                                    });
                                } else if attr.to_string() == "dirOf" {
                                    // This is builtins.dirOf path - extract directory from path
                                    let arg_expr = apply.argument()
                                        .ok_or_else(|| Error::UnsupportedExpression {
                                            reason: "dirOf: missing argument".to_string(),
                                        })?;
                                    
                                    let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                                    let arg_forced = arg_value.clone().force(self)?;
                                    
                                    let path_str = match arg_forced {
                                        NixValue::String(s) => s,
                                        NixValue::Path(p) => p.to_string_lossy().to_string(),
                                        _ => {
                                            return Err(Error::UnsupportedExpression {
                                                reason: format!("dirOf: argument must be a string or path, got {}", arg_forced),
                                            });
                                        }
                                    };
                                    
                                    // Extract directory from path
                                    let dir = if path_str.is_empty() {
                                        ".".to_string()
                                    } else if let Some(last_slash) = path_str.rfind('/') {
                                        if last_slash == 0 {
                                            "/".to_string()
                                        } else {
                                            path_str[..last_slash].to_string()
                                        }
                                    } else {
                                        ".".to_string()
                                    };
                                    
                                    return Ok(NixValue::String(dir));
                                } else if attr.to_string() == "attrNames" {
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
        // Also check for foldl' which has three arguments: Apply(Apply(Apply(builtins.foldl', f), init), list)
        // Also check for direct foldl' calls: Apply(Apply(foldl', f), init) or Apply(Apply(Apply(foldl', f), init), list)
        if let Expr::Apply(inner_apply) = &func_expr {
            if let Some(inner_func_expr) = inner_apply.lambda() {
                // Check for direct foldl' calls (not via builtins.foldl')
                if let Expr::Ident(ref ident) = inner_func_expr {
                    if ident.to_string() == "foldl'" {
                        // Structure for 3 args: apply = Apply(Apply(Apply(foldl', f), init), list)
                        // Structure for 2 args: apply = Apply(Apply(foldl', f), init)
                        // func_expr = apply.lambda() = Apply(Apply(foldl', f), init)
                        // inner_apply = Apply(Apply(foldl', f), init) (same as func_expr)
                        // inner_apply.lambda() = Apply(foldl', f)
                        // So:
                        //   f_expr = inner_apply.lambda().argument() = f
                        //   init_expr = inner_apply.argument() = init
                        //   list_expr = apply.argument() = list (if it exists)
                        
                        // For direct foldl' calls: inner_apply = Apply(foldl', f)
                        // So inner_apply.lambda() = foldl' (Ident), and inner_apply.argument() = f
                        let f_expr = inner_apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "foldl': missing first argument".to_string(),
                            })?;
                        let init_expr = inner_apply.argument()
                            .ok_or_else(|| Error::UnsupportedExpression {
                                reason: "foldl': missing second argument".to_string(),
                            })?;
                        
                        let f_value = self.evaluate_expr_with_scope_impl(&f_expr, scope)?;
                        let init_value = self.evaluate_expr_with_scope_impl(&init_expr, scope)?;
                        
                        // Check if we have a third argument (the list)
                        // For direct foldl' calls: apply = Apply(Apply(foldl', f), init)
                        // So apply.argument() = init (the second argument)
                        // We need to check if there's another Apply wrapping this to get the list
                        // Actually, if apply.argument() exists and is a list, it's the third argument
                        // If apply.argument() exists but is not a list, it's the second argument (2-arg case)
                        if let Some(third_arg_expr) = apply.argument() {
                            let third_arg_value = self.evaluate_expr_with_scope_impl(&third_arg_expr, scope)?;
                            let third_arg_forced = third_arg_value.clone().force(self)?;
                            
                            // Check if it's a list (third argument) or something else (second argument)
                            if let NixValue::List(list) = third_arg_forced {
                                // Three arguments: foldl' f init list - execute the fold
                                // Handle builtin functions specially
                                if let NixValue::String(s) = &f_value {
                                    if s.starts_with("__builtin_func:") {
                                        let builtin_name = &s[15..]; // Skip "__builtin_func:"
                                        if let Some(builtin) = self.builtins.get(builtin_name) {
                                            // Strict left fold with builtin: foldl' builtin init [x1, x2, ..., xn]
                                            // For builtins, we call them directly: builtin(acc, x)
                                            let mut accumulator = init_value;
                                            for element in list {
                                                // Force element before applying builtin (strict evaluation)
                                                let element_forced = element.clone().force(self)?;
                                                // Call builtin with accumulator and element
                                                accumulator = builtin.call(&[accumulator, element_forced])?;
                                            }
                                            return Ok(accumulator);
                                        } else {
                                            return Err(Error::UnsupportedExpression {
                                                reason: format!("foldl': unknown builtin function: {}", builtin_name),
                                            });
                                        }
                                    }
                                }
                                
                                // Handle regular functions
                                let func = match f_value {
                                    NixValue::Function(f) => f,
                                    _ => {
                                        return Err(Error::UnsupportedExpression {
                                            reason: format!("foldl': first argument must be a function, got {}", f_value),
                                        });
                                    }
                                };
                                
                                // Strict left fold: foldl' f init [x1, x2, ..., xn] = f (... (f (f init x1) x2) ...) xn
                                // f is curried: f acc x = (f acc) x
                                let mut accumulator = init_value;
                                for element in list {
                                    // Force element before applying function (strict evaluation)
                                    let element_forced = element.clone().force(self)?;
                                    // Apply f to accumulator: f acc (returns a function)
                                    let f_acc = func.apply(self, accumulator)?;
                                    // Apply (f acc) to element: (f acc) x
                                    accumulator = match f_acc {
                                        NixValue::Function(f_acc_func) => f_acc_func.apply(self, element_forced)?,
                                        _ => {
                                            return Err(Error::UnsupportedExpression {
                                                reason: format!("foldl': function must return a function when partially applied, got {}", f_acc),
                                            });
                                        }
                                    };
                                }
                                
                                return Ok(accumulator);
                            } else {
                                // The third argument is not a list, so this is actually the 2-argument case
                                // apply.argument() is the second argument (init), not the third
                                // Two arguments: foldl' f init - return a curried function that takes a list
                                use crate::function::Function;
                                use std::sync::Arc;
                                
                                // Create a function that takes a list argument
                                // This function will apply foldl' f init to the list
                                let curried_func = Function::new_curried_foldl(
                                    f_value,
                                    init_value,
                                    self.current_file_id(),
                                );
                                
                                return Ok(NixValue::Function(Arc::new(curried_func)));
                            }
                        } else {
                            // No third argument - this shouldn't happen for foldl' with 2 args
                            // But handle it as 2-arg case anyway
                            use crate::function::Function;
                            use std::sync::Arc;
                            
                            let curried_func = Function::new_curried_foldl(
                                f_value,
                                init_value,
                                self.current_file_id(),
                            );
                            
                            return Ok(NixValue::Function(Arc::new(curried_func)));
                        }
                    }
                }
                
                // Check if inner_func_expr is a Select (builtins.elem) or an Apply containing builtins.foldl'
                // For builtins.elem x xs: func_expr = Apply(builtins.elem, x), inner_func_expr = builtins.elem (Select)
                if let Expr::Select(ref select) = inner_func_expr {
                    if let Some(base_expr) = select.expr() {
                        if let Expr::Ident(ident) = base_expr {
                            if ident.to_string() == "builtins" {
                                if let Some(attrpath) = select.attrpath() {
                                    if let Some(attr) = attrpath.attrs().next() {
                                        if attr.to_string() == "elem" {
                                            // This is builtins.elem x xs
                                            // Structure: Apply(Apply(builtins.elem, x), xs)
                                            // func_expr = Apply(builtins.elem, x)
                                            // inner_apply = Apply(builtins.elem, x) (same as func_expr)
                                            // inner_func_expr = inner_apply.lambda() = builtins.elem (Select)
                                            // So:
                                            //   x_expr = inner_apply.argument() = x
                                            //   xs_expr = apply.argument() = xs
                                            let x_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "elem: missing first argument".to_string(),
                                                })?;
                                            let xs_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "elem: missing second argument".to_string(),
                                                })?;
                                            
                                            let x_value = self.evaluate_expr_with_scope_impl(&x_expr, scope)?;
                                            let xs_value = self.evaluate_expr_with_scope_impl(&xs_expr, scope)?;
                                            
                                            // Force the list to check elements
                                            let xs_forced = xs_value.clone().force(self)?;
                                            let list = match xs_forced {
                                                NixValue::List(l) => l,
                                                _ => {
                                                    return Err(Error::UnsupportedExpression {
                                                        reason: format!("elem: second argument must be a list, got {}", xs_forced),
                                                    });
                                                }
                                            };
                                            
                                            // Check if x is in the list (force thunks in list elements for comparison)
                                            for item in list {
                                                let item_forced = item.clone().force(self)?;
                                                // Compare using equality
                                                let eq_result = self.evaluate_equal(&x_value, &item_forced)?;
                                                if let NixValue::Boolean(true) = eq_result {
                                                    return Ok(NixValue::Boolean(true));
                                                }
                                            }
                                            
                                            return Ok(NixValue::Boolean(false));
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                
                // Check if inner_func_expr is an Apply containing builtins.foldl'
                if let Expr::Apply(ref inner_inner_apply) = inner_func_expr {
                    if let Some(inner_inner_func_expr) = inner_inner_apply.lambda() {
                        if let Expr::Select(select) = inner_inner_func_expr {
                            if let Some(base_expr) = select.expr() {
                                if let Expr::Ident(ident) = base_expr {
                                    if ident.to_string() == "builtins" {
                                        if let Some(attrpath) = select.attrpath() {
                                            if let Some(attr) = attrpath.attrs().next() {
                                                if attr.to_string() == "foldl'" {
                                                    // This is builtins.foldl' f init list
                                                    // Structure: Apply(Apply(Apply(builtins.foldl', f), init), list)
                                                    // inner_apply = Apply(Apply(builtins.foldl', f), init)
                                                    // inner_inner_apply = Apply(builtins.foldl', f)
                                                    // So:
                                                    //   f_expr = inner_inner_apply.argument() = f
                                                    //   init_expr = inner_apply.argument() = init
                                                    //   list_expr = apply.argument() = list
                                                    let f_expr = inner_inner_apply.argument()
                                                        .ok_or_else(|| Error::UnsupportedExpression {
                                                            reason: "foldl': missing first argument".to_string(),
                                                        })?;
                                                    let init_expr = inner_apply.argument()
                                                        .ok_or_else(|| Error::UnsupportedExpression {
                                                            reason: "foldl': missing second argument".to_string(),
                                                        })?;
                                                    
                                                    let f_value = self.evaluate_expr_with_scope_impl(&f_expr, scope)?;
                                                    let init_value = self.evaluate_expr_with_scope_impl(&init_expr, scope)?;
                                                    
                                                    // Check if we have a third argument (the list)
                                                    if let Some(list_expr) = apply.argument() {
                                                        // Three arguments: foldl' f init list - execute the fold
                                                        let list_value = self.evaluate_expr_with_scope_impl(&list_expr, scope)?;
                                                        
                                                        // Get the list
                                                        let list_forced = list_value.clone().force(self)?;
                                                        let list = match list_forced {
                                                            NixValue::List(l) => l,
                                                            _ => {
                                                                return Err(Error::UnsupportedExpression {
                                                                    reason: format!("foldl': third argument must be a list, got {}", list_forced),
                                                                });
                                                            }
                                                        };
                                                        
                                                        // Handle builtin functions specially
                                                        if let NixValue::String(s) = &f_value {
                                                            if s.starts_with("__builtin_func:") {
                                                                let builtin_name = &s[15..]; // Skip "__builtin_func:"
                                                                if let Some(builtin) = self.builtins.get(builtin_name) {
                                                                    // Strict left fold with builtin: foldl' builtin init [x1, x2, ..., xn]
                                                                    // For builtins, we call them directly: builtin(acc, x)
                                                                    let mut accumulator = init_value;
                                                                    for element in list {
                                                                        // Force element before applying builtin (strict evaluation)
                                                                        let element_forced = element.clone().force(self)?;
                                                                        // Call builtin with accumulator and element
                                                                        accumulator = builtin.call(&[accumulator, element_forced])?;
                                                                    }
                                                                    return Ok(accumulator);
                                                                } else {
                                                                    return Err(Error::UnsupportedExpression {
                                                                        reason: format!("foldl': unknown builtin function: {}", builtin_name),
                                                                    });
                                                                }
                                                            }
                                                        }
                                                        
                                                        // Handle regular functions
                                                        let func = match f_value {
                                                            NixValue::Function(f) => f,
                                                            _ => {
                                                                return Err(Error::UnsupportedExpression {
                                                                    reason: format!("foldl': first argument must be a function, got {}", f_value),
                                                                });
                                                            }
                                                        };
                                                        
                                                        // Strict left fold: foldl' f init [x1, x2, ..., xn] = f (... (f (f init x1) x2) ...) xn
                                                        // f is curried: f acc x = (f acc) x
                                                        let mut accumulator = init_value;
                                                        for element in list {
                                                            // Force element before applying function (strict evaluation)
                                                            let element_forced = element.clone().force(self)?;
                                                            // Apply f to accumulator: f acc (returns a function)
                                                            let f_acc = func.apply(self, accumulator)?;
                                                            // Apply (f acc) to element: (f acc) x
                                                            accumulator = match f_acc {
                                                                NixValue::Function(f_acc_func) => f_acc_func.apply(self, element_forced)?,
                                                                _ => {
                                                                    return Err(Error::UnsupportedExpression {
                                                                        reason: format!("foldl': function must return a function when partially applied, got {}", f_acc),
                                                                    });
                                                                }
                                                            };
                                                        }
                                                        
                                                        return Ok(accumulator);
                                                    } else {
                                                        // Two arguments: foldl' f init - return a curried function that takes a list
                                                        use crate::function::Function;
                                                        use std::sync::Arc;
                                                        
                                                        // Create a function that takes a list argument
                                                        // This function will apply foldl' f init to the list
                                                        let curried_func = Function::new_curried_foldl(
                                                            f_value,
                                                            init_value,
                                                            self.current_file_id(),
                                                        );
                                                        
                                                        return Ok(NixValue::Function(Arc::new(curried_func)));
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
                
                if let Expr::Select(select) = inner_func_expr {
                    // Check if it's builtins.genList or other builtins
                    if let Some(base_expr) = select.expr() {
                        if let Expr::Ident(ident) = base_expr {
                            if ident.to_string() == "builtins" {
                                if let Some(attrpath) = select.attrpath() {
                                    if let Some(attr) = attrpath.attrs().next() {
                                        if attr.to_string() == "deepSeq" {
                                            // Check if this is foldl' f init list (three arguments)
                                            // The parser gives us: Apply(Apply(Apply(builtins.foldl', f), init), list)
                                            // We're at: Apply(Apply(builtins.foldl', f), init)
                                            // So func_expr is Apply(Apply(builtins.foldl', f), init)
                                            // inner_apply is Apply(builtins.foldl', f)
                                            // We need to check if apply (the outer Apply) is itself an Apply to get the list
                                            // Actually, apply is Apply(Apply(Apply(builtins.foldl', f), init), list)
                                            // So apply.argument() is list
                                            // And func_expr is Apply(Apply(builtins.foldl', f), init)
                                            // So inner_apply is Apply(builtins.foldl', f), and inner_apply.argument() is f
                                            // And apply is Apply(inner_apply, init), so... wait, that's not right either
                                            
                                            // Let me think: apply = Apply(Apply(Apply(builtins.foldl', f), init), list)
                                            // func_expr = apply.lambda() = Apply(Apply(builtins.foldl', f), init)
                                            // So if func_expr is Apply, then:
                                            //   mid_apply = Apply(Apply(builtins.foldl', f), init) (same as func_expr)
                                            //   inner_apply = Apply(builtins.foldl', f)
                                            // So:
                                            //   f_expr = inner_apply.argument() = f
                                            //   init_expr = mid_apply.argument() = init
                                            //   list_expr = apply.argument() = list
                                            
                                            // Check if func_expr is itself an Apply (meaning we have Apply(Apply(builtins.foldl', f), init))
                                            if let Expr::Apply(mid_apply) = &func_expr {
                                                // mid_apply is Apply(Apply(builtins.foldl', f), init)
                                                // Check if mid_apply.lambda() is Apply(builtins.foldl', f)
                                                if let Some(mid_func_expr) = mid_apply.lambda() {
                                                    if let Expr::Apply(inner_inner_apply) = mid_func_expr {
                                                        if let Some(inner_inner_func_expr) = inner_inner_apply.lambda() {
                                                            if let Expr::Select(inner_inner_select) = inner_inner_func_expr {
                                                                if let Some(inner_inner_base_expr) = inner_inner_select.expr() {
                                                                    if let Expr::Ident(inner_inner_ident) = inner_inner_base_expr {
                                                                        if inner_inner_ident.to_string() == "builtins" {
                                                                            if let Some(inner_inner_attrpath) = inner_inner_select.attrpath() {
                                                                                if let Some(inner_inner_attr) = inner_inner_attrpath.attrs().next() {
                                                                                    if inner_inner_attr.to_string() == "foldl'" {
                                                                                        // This is builtins.foldl' f init list
                                                                                        // inner_inner_apply is Apply(builtins.foldl', f)
                                                                                        // mid_apply is Apply(inner_inner_apply, init)
                                                                                        // apply is Apply(mid_apply, list)
                                                                                        let f_expr = inner_inner_apply.argument()
                                                                                            .ok_or_else(|| Error::UnsupportedExpression {
                                                                                                reason: "foldl': missing first argument".to_string(),
                                                                                            })?;
                                                                                        let init_expr = mid_apply.argument()
                                                                                            .ok_or_else(|| Error::UnsupportedExpression {
                                                                                                reason: "foldl': missing second argument".to_string(),
                                                                                            })?;
                                                                                        let list_expr = apply.argument()
                                                                                            .ok_or_else(|| Error::UnsupportedExpression {
                                                                                                reason: "foldl': missing third argument".to_string(),
                                                                                            })?;
                                                                                
                                                                                        let f_value = self.evaluate_expr_with_scope_impl(&f_expr, scope)?;
                                                                                        let init_value = self.evaluate_expr_with_scope_impl(&init_expr, scope)?;
                                                                                        let list_value = self.evaluate_expr_with_scope_impl(&list_expr, scope)?;
                                                                                        
                                                                                        // Get the list
                                                                                        let list_forced = list_value.clone().force(self)?;
                                                                                        let list = match list_forced {
                                                                                            NixValue::List(l) => l,
                                                                                            _ => {
                                                                                                return Err(Error::UnsupportedExpression {
                                                                                                    reason: format!("foldl': third argument must be a list, got {}", list_forced),
                                                                                                });
                                                                                            }
                                                                                        };
                                                                                        
                                                                                        // Handle builtin functions specially
                                                                                        if let NixValue::String(s) = &f_value {
                                                                                            if s.starts_with("__builtin_func:") {
                                                                                                let builtin_name = &s[15..]; // Skip "__builtin_func:"
                                                                                                if let Some(builtin) = self.builtins.get(builtin_name) {
                                                                                                    // Strict left fold with builtin: foldl' builtin init [x1, x2, ..., xn]
                                                                                                    // For builtins, we call them directly: builtin(acc, x)
                                                                                                    let mut accumulator = init_value;
                                                                                                    for element in list {
                                                                                                        // Force element before applying builtin (strict evaluation)
                                                                                                        let element_forced = element.clone().force(self)?;
                                                                                                        // Call builtin with accumulator and element
                                                                                                        accumulator = builtin.call(&[accumulator, element_forced])?;
                                                                                                    }
                                                                                                    return Ok(accumulator);
                                                                                                } else {
                                                                                                    return Err(Error::UnsupportedExpression {
                                                                                                        reason: format!("foldl': unknown builtin function: {}", builtin_name),
                                                                                                    });
                                                                                                }
                                                                                            }
                                                                                        }
                                                                                        
                                                                                        // Handle regular functions
                                                                                        let func = match f_value {
                                                                                            NixValue::Function(f) => f,
                                                                                            _ => {
                                                                                                return Err(Error::UnsupportedExpression {
                                                                                                    reason: format!("foldl': first argument must be a function, got {}", f_value),
                                                                                                });
                                                                                            }
                                                                                        };
                                                                                        
                                                                                        // Strict left fold: foldl' f init [x1, x2, ..., xn] = f (... (f (f init x1) x2) ...) xn
                                                                                        // f is curried: f acc x = (f acc) x
                                                                                        let mut accumulator = init_value;
                                                                                        for element in list {
                                                                                            // Force element before applying function (strict evaluation)
                                                                                            let element_forced = element.clone().force(self)?;
                                                                                            // Apply f to accumulator: f acc (returns a function)
                                                                                            let f_acc = func.apply(self, accumulator)?;
                                                                                            // Apply (f acc) to element: (f acc) x
                                                                                            accumulator = match f_acc {
                                                                                                NixValue::Function(f_acc_func) => f_acc_func.apply(self, element_forced)?,
                                                                                                _ => {
                                                                                                    return Err(Error::UnsupportedExpression {
                                                                                                        reason: format!("foldl': function must return a function when partially applied, got {}", f_acc),
                                                                                                    });
                                                                                                }
                                                                                            };
                                                                                        }
                                                                                        
                                                                                        return Ok(accumulator);
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
                                            }
                                        } else if attr.to_string() == "deepSeq" {
                                            // This is builtins.deepSeq a b - force a deeply, return b
                                            let a_expr = inner_apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "deepSeq: missing first argument".to_string(),
                                                })?;
                                            let b_expr = apply.argument()
                                                .ok_or_else(|| Error::UnsupportedExpression {
                                                    reason: "deepSeq: missing second argument".to_string(),
                                                })?;
                                            
                                            let a_value = self.evaluate_expr_with_scope_impl(&a_expr, scope)?;
                                            let b_value = self.evaluate_expr_with_scope_impl(&b_expr, scope)?;
                                            
                                            // Deep force a (evaluate all thunks recursively)
                                            let _ = a_value.clone().deep_force(self)?;
                                            
                                            // Return b
                                            return Ok(b_value);
                                        } else if attr.to_string() == "foldl'" {
                                            // This is builtins.foldl' f init list - strict left fold
                                            // The parser gives us: Apply(Apply(Apply(builtins.foldl', f), init), list)
                                            // We're currently at: Apply(builtins.foldl', f)
                                            // So func_expr is builtins.foldl', and inner_apply.argument() is f
                                            // We need to check if func_expr (which is the result of applying foldl' to f) is itself applied
                                            // Actually, let's check if func_expr matches inner_apply
                                            // If func_expr == inner_apply, then apply is Apply(inner_apply, init)
                                            // And we need to check if there's another level
                                            
                                            // Check if func_expr is itself an Apply (meaning we have Apply(Apply(builtins.foldl', f), init))
                                            if let Expr::Apply(mid_apply) = &func_expr {
                                                // Check if mid_apply matches inner_apply (they should be the same Apply node)
                                                // If so, then apply is Apply(mid_apply, init), and we need the third argument
                                                let init_expr = apply.argument()
                                                    .ok_or_else(|| Error::UnsupportedExpression {
                                                        reason: "foldl': missing second argument".to_string(),
                                                    })?;
                                                
                                                // Now check if the result is applied again to get the list
                                                // This would be in a nested Apply, but we're already handling that at a different level
                                                // For now, let's assume we need to handle this at the outer level
                                                // Actually, the structure is: Apply(Apply(Apply(builtins.foldl', f), init), list)
                                                // So we need to check one more level up
                                                return Err(Error::UnsupportedExpression {
                                                    reason: "foldl': requires three arguments (foldl' f init list) - needs nested Apply handling".to_string(),
                                                });
                                            }
                                        } else if attr.to_string() == "genList" {
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
        // Keep forcing until we get a non-thunk value (handle thunk-thunk cases)
        let mut func_value_forced = func_value.clone().force(self)?;
        while let NixValue::Thunk(thunk) = &func_value_forced {
            func_value_forced = thunk.force(self)?;
        }

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
                reason: format!("cannot apply non-function value: {:?}", func_value_forced),
            }),
        }
    }
}
