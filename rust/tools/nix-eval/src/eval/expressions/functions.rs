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
        if let Expr::Ident(ident) = &func_expr {
            let builtin_name = ident.to_string();

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
                                        }
                                    }
                                }
                            }
                        }
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
                    let arg_value = self.evaluate_expr_with_scope_impl(&arg_expr, scope)?;
                    
                    // Call the builtin with the argument
                    return builtin.call(&[arg_value]);
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

        // Apply the function to the argument
        // Note: The result of apply() may be another function, enabling currying.
        // Chained applications like `f 1 2` are handled by the parser as nested Apply nodes.
        match func_value {
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
