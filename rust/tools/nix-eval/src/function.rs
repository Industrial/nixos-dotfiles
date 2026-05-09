//! Function/closure implementation for Nix functions
//!
//! Functions in Nix are closures that capture their lexical environment (scope)
//! and can be applied to arguments. This module provides the data structure
//! to represent Nix functions.

use crate::{Error, Evaluator, NixValue, Result, VariableScope};
use codespan::FileId;
use rnix::ast::{Expr, Root};
use rnix::parser::parse;
use rnix::tokenizer::tokenize;
use rnix::SyntaxNode;
use rowan::ast::AstNode;
use std::sync::Arc;

/// A Nix function (closure)
///
/// Functions in Nix are closures that:
/// - Capture their lexical environment (scope) at definition time
/// - Have a parameter name (or pattern) that will be bound when applied
/// - Have a body expression that will be evaluated when the function is called
/// - Capture the file_id context at definition time (for relative imports)
///
/// # Example
///
/// ```no_run
/// use nix_eval::function::Function;
/// use nix_eval::{Evaluator, NixValue};
/// use std::collections::HashMap;
///
/// // A function like `x: x + 1` would be represented as:
/// // - parameter: "x"
/// // - body: "x + 1"
/// // - closure: the scope at function definition time
/// ```
#[derive(Debug, Clone)]
pub struct Function {
    /// The parameter name (or pattern) that will be bound when the function is applied
    ///
    /// For simple functions like `x: x + 1`, this is just "x".
    /// For more complex patterns, this could be an attribute set pattern or list pattern.
    parameter: String,
    /// The body expression (stored as text representation)
    ///
    /// Similar to thunks, we store the expression as text for now.
    /// In a full implementation, we'd want to store the actual AST node.
    pub(crate) body_text: String,
    /// The lexical closure (variable scope) captured at function definition time
    ///
    /// This allows the function to access variables from its surrounding scope
    /// even when called in a different context (lexical scoping).
    pub(crate) closure: VariableScope,
    /// The file_id context at function definition time (for resolving relative imports)
    ///
    /// This is critical for lazy evaluation: when a function is called and creates thunks,
    /// those thunks need to know what file the function was defined in so that relative
    /// imports work correctly.
    pub(crate) file_id: Option<FileId>,
}

impl Function {
    /// Create a new function closure
    ///
    /// # Arguments
    ///
    /// * `parameter` - The parameter name (or pattern) for this function
    /// * `body_expr` - The body expression (from rnix AST)
    /// * `closure` - The lexical closure (variable scope) at function definition time
    /// * `file_id` - The file ID at function definition time (for relative imports)
    ///
    /// # Returns
    ///
    /// A new function closure
    pub fn new(
        parameter: String,
        body_expr: &Expr,
        closure: VariableScope,
        file_id: Option<FileId>,
    ) -> Self {
        // Store the body expression as text representation for now
        // In a full implementation, we'd want to store the actual AST node
        // but that requires handling lifetimes carefully
        let body_text = body_expr.syntax().text().to_string();

        Self {
            parameter,
            body_text,
            closure,
            file_id,
        }
    }

    /// Create a curried builtin function (internal constructor)
    pub(crate) fn new_curried_builtin_internal(
        parameter: String,
        body_text: String,
        closure: VariableScope,
        file_id: Option<FileId>,
    ) -> Self {
        Self {
            parameter,
            body_text,
            closure,
            file_id,
        }
    }

    /// Get the parameter name
    pub fn parameter(&self) -> &str {
        &self.parameter
    }

    /// Get the body expression text
    pub fn body_text(&self) -> &str {
        &self.body_text
    }

    /// Create a curried builtin function
    ///
    /// This creates a function that wraps a builtin with a partially applied argument.
    /// When the function is called, it will call the builtin with both the captured
    /// argument and the new argument.
    ///
    /// # Arguments
    ///
    /// * `builtin_name` - The name of the builtin (for debugging)
    /// * `builtin` - The builtin to wrap
    /// * `first_arg` - The first argument (already applied)
    /// * `file_id` - The file ID context
    ///
    /// # Returns
    ///
    /// A new function that, when called, will apply the builtin to (first_arg, new_arg)
    pub fn new_curried_builtin(
        builtin_name: String,
        _builtin: Box<dyn crate::Builtin>,
        first_arg: NixValue,
        file_id: Option<FileId>,
    ) -> Self {
        // Create a function that captures the first argument
        // When applied, it will call the builtin with (first_arg, new_arg)
        // We'll use a special parameter name to indicate this is a curried builtin
        let parameter = format!("__curried_{}_arg2", builtin_name);
        let body_text = format!("__curried_builtin_call:{}", builtin_name);

        // Store the builtin and first arg in the closure
        let mut closure = VariableScope::new();
        closure.insert(
            format!("__builtin_{}", builtin_name),
            NixValue::String(format!("__builtin_func:{}", builtin_name)),
        );
        closure.insert("__curried_first_arg".to_string(), first_arg);

        Self {
            parameter,
            body_text,
            closure,
            file_id,
        }
    }

    /// Create a curried builtin function with multiple arguments already applied
    ///
    /// This creates a function that captures multiple arguments and waits for more.
    pub fn new_curried_builtin_multi(
        builtin_name: String,
        _builtin: Box<dyn crate::Builtin>,
        args: Vec<NixValue>,
        file_id: Option<FileId>,
    ) -> Self {
        let parameter = format!("__curried_{}_arg{}", builtin_name, args.len() + 1);
        let _body_text = format!("__curried_builtin_call:{}", builtin_name);

        let mut closure = VariableScope::new();
        closure.insert(
            format!("__builtin_{}", builtin_name),
            NixValue::String(format!("__builtin_func:{}", builtin_name)),
        );
        for (i, arg) in args.iter().enumerate() {
            closure.insert(format!("__curried_arg{}", i + 1), arg.clone());
        }
        closure.insert(
            "__curried_arg_count".to_string(),
            NixValue::Integer(args.len() as i64),
        );

        // Create a dummy Expr for the body (we won't actually use it for curried builtins)
        // We'll use an empty expression since the body_text is just a marker
        use rnix::parser::parse;
        use rnix::tokenizer::tokenize;
        let tokens = tokenize("null");
        let (green_node, _) = parse(tokens.into_iter());
        let syntax_node = SyntaxNode::new_root(green_node);
        let root = Root::cast(syntax_node).unwrap();
        let dummy_expr = root.expr().unwrap();

        Self::new(parameter, &dummy_expr, closure, file_id)
    }

    /// Create a curried foldl' function (2 args applied, needs list)
    ///
    /// This creates a function that captures op and nul, and when called with a list,
    /// will call foldl' with all three arguments.
    ///
    /// # Arguments
    ///
    /// * `op` - The operator function (first argument to foldl')
    /// * `nul` - The initial accumulator (second argument to foldl')
    /// * `file_id` - The file ID context
    ///
    /// # Returns
    ///
    /// A new function that, when called with a list, will call foldl' with (op, nul, list)
    pub fn new_curried_foldl(op: NixValue, nul: NixValue, file_id: Option<FileId>) -> Self {
        // Create a function that captures op and nul
        // When applied with a list, it will call foldl' with (op, nul, list)
        let parameter = "__foldl_list_arg".to_string();
        let body_text = "__curried_foldl_call".to_string();

        // Store op and nul in the closure
        let mut closure = VariableScope::new();
        closure.insert("__foldl_op".to_string(), op);
        closure.insert("__foldl_nul".to_string(), nul);

        Self {
            parameter,
            body_text,
            closure,
            file_id,
        }
    }

    /// Get a reference to the lexical closure
    pub fn closure(&self) -> &VariableScope {
        &self.closure
    }

    /// Apply this function to an argument
    ///
    /// This method evaluates the function body with the argument bound to the parameter.
    /// The function's closure is merged with the argument binding, allowing the body
    /// to access both the captured closure variables and the function parameter.
    ///
    /// **Currying Support**: If the function body evaluates to another function,
    /// that function is returned (partial application). This enables currying:
    /// `(x: y: x + y) 1` returns `y: 1 + y`, and `(x: y: x + y) 1 2` evaluates to `3`.
    ///
    /// # Arguments
    ///
    /// * `evaluator` - The evaluator to use for evaluating the function body
    /// * `argument` - The argument value to bind to the function parameter
    ///
    /// # Returns
    ///
    /// * `Ok(NixValue)` - The result of evaluating the function body (may be a function for currying)
    /// * `Err(Error)` - An error if evaluation fails
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, Function, NixValue};
    /// use rnix::ast::Expr;
    /// use std::collections::HashMap;
    ///
    /// let evaluator = Evaluator::new();
    /// // Create a curried function: x: y: x + y
    /// // let func = Function::new("x", &body_expr, HashMap::new());
    /// // let partial = func.apply(&evaluator, NixValue::Integer(1))?; // Returns y: 1 + y
    /// // let result = partial.apply(&evaluator, NixValue::Integer(2))?; // Returns 3
    /// ```
    pub fn apply(&self, evaluator: &Evaluator, argument: NixValue) -> Result<NixValue> {
        // Check if this is a curried foldl' function (2 args applied, needs list)
        if self.body_text == "__curried_foldl_call" {
            if let (Some(op), Some(nul)) = (
                self.closure.get("__foldl_op"),
                self.closure.get("__foldl_nul"),
            ) {
                // This is a curried foldl' - call it with (op, nul, list)
                // Force the list argument
                let list_value = argument.clone().force(evaluator)?;
                let list = match list_value {
                    NixValue::List(l) => l,
                    _ => {
                        return Err(Error::UnsupportedExpression {
                            reason: format!(
                                "foldl': third argument must be a list, got {}",
                                list_value
                            ),
                        });
                    }
                };

                // Get the operator function or builtin name
                let op_value = op.clone().force(evaluator)?;
                let (op_func_opt, builtin_name_opt) = match op_value {
                    NixValue::Function(f) => (Some(f), None),
                    NixValue::String(ref s) if s.starts_with("__builtin_func:") => {
                        let builtin_name = &s[15..];
                        if evaluator.get_builtin(builtin_name).is_some() {
                            (None, Some(builtin_name.to_string()))
                        } else {
                            return Err(Error::UnsupportedExpression {
                                reason: format!(
                                    "foldl': unknown builtin function: {}",
                                    builtin_name
                                ),
                            });
                        }
                    }
                    _ => {
                        return Err(Error::UnsupportedExpression {
                            reason: format!(
                                "foldl': first argument must be a function, got {}",
                                op_value
                            ),
                        });
                    }
                };

                // Fold left: start with nul, apply op to accumulator and each element
                let mut accumulator = nul.clone();
                for element in list {
                    if let Some(ref builtin_name) = builtin_name_opt {
                        // Handle builtin directly
                        if let Some(builtin) = evaluator.get_builtin(builtin_name) {
                            let accumulator_forced = accumulator.clone().force(evaluator)?;
                            let element_forced = element.clone().force(evaluator)?;
                            accumulator = builtin.call(&[accumulator_forced, element_forced])?;
                        } else {
                            return Err(Error::UnsupportedExpression {
                                reason: format!("foldl': builtin '{}' not found", builtin_name),
                            });
                        }
                    } else if let Some(ref op_func) = op_func_opt {
                        // Handle Nix function - foldl' calls op(acc, elem)
                        let accumulator_forced = accumulator.clone().force(evaluator)?;
                        let element_forced = element.clone().force(evaluator)?;
                        let partial = op_func.apply(evaluator, accumulator_forced)?;
                        accumulator = match partial {
                            NixValue::Function(next_func) => {
                                next_func.apply(evaluator, element_forced)?
                            }
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: format!(
                                        "foldl': operator function must be curried (take 2 args), got {}",
                                        partial
                                    ),
                                });
                            }
                        };
                    }
                }

                return Ok(accumulator);
            }
        }

        // Check if this is a curried builtin function
        if self.body_text.starts_with("__curried_builtin_call:") {
            let builtin_name = &self.body_text[23..]; // Skip "__curried_builtin_call:"

            // Get the builtin and collected arguments from closure
            if let Some(builtin_marker) = self.closure.get(&format!("__builtin_{}", builtin_name)) {
                if let NixValue::String(ref marker) = builtin_marker {
                    if marker.starts_with("__builtin_func:") {
                        if let Some(builtin) = evaluator.get_builtin(builtin_name) {
                            // Collect all arguments from closure
                            let mut args = Vec::new();

                            // Check if we have __curried_first_arg (old style) or __curried_arg1, __curried_arg2, etc. (new style)
                            if let Some(first_arg) = self.closure.get("__curried_first_arg") {
                                // Old style: single argument - force thunks before collecting
                                let first_arg_forced = first_arg.clone().force(evaluator)?;
                                args.push(first_arg_forced);
                                let arg_forced = argument.clone().force(evaluator)?;
                                args.push(arg_forced);
                            } else {
                                // New style: multiple arguments - force thunks before collecting
                                let arg_count = self
                                    .closure
                                    .get("__curried_arg_count")
                                    .and_then(|v| match v {
                                        NixValue::Integer(n) => Some(*n as usize),
                                        _ => None,
                                    })
                                    .unwrap_or(0);

                                for i in 1..=arg_count {
                                    if let Some(arg) =
                                        self.closure.get(&format!("__curried_arg{}", i))
                                    {
                                        let arg_forced = arg.clone().force(evaluator)?;
                                        args.push(arg_forced);
                                    }
                                }
                                let arg_forced = argument.clone().force(evaluator)?;
                                args.push(arg_forced);
                            }

                            // Try calling the builtin with all collected arguments
                            match builtin.call(&args) {
                                Ok(result) => return Ok(result),
                                Err(Error::UnsupportedExpression { reason })
                                    if reason.contains("takes") && reason.contains("arguments") =>
                                {
                                    // Still needs more arguments - create another curried function
                                    let file_id = evaluator.current_file_id();
                                    let mut closure = VariableScope::new();
                                    closure.insert(
                                        format!("__builtin_{}", builtin_name),
                                        NixValue::String(format!(
                                            "__builtin_func:{}",
                                            builtin_name
                                        )),
                                    );
                                    for (i, arg) in args.iter().enumerate() {
                                        closure
                                            .insert(format!("__curried_arg{}", i + 1), arg.clone());
                                    }
                                    closure.insert(
                                        "__curried_arg_count".to_string(),
                                        NixValue::Integer(args.len() as i64),
                                    );

                                    let next_curried = Function::new_curried_builtin_internal(
                                        format!("__curried_{}_arg{}", builtin_name, args.len() + 1),
                                        format!("__curried_builtin_call:{}", builtin_name),
                                        closure,
                                        file_id,
                                    );
                                    return Ok(NixValue::Function(Arc::new(next_curried)));
                                }
                                Err(e) => return Err(e),
                            }
                        }
                    }
                }
            }
            let builtin_name = &self.body_text[23..]; // Skip "__curried_builtin_call:"
            if let Some(first_arg) = self.closure.get("__curried_first_arg") {
                // This is a curried builtin - call it with both arguments
                // Force both arguments before calling the builtin
                let first_arg_forced = first_arg.clone().force(evaluator)?;
                let argument_forced = argument.clone().force(evaluator)?;

                // Get the builtin from the evaluator
                if let Some(builtin) = evaluator.get_builtin(builtin_name) {
                    // get_builtin returns &dyn Builtin, but call takes &[NixValue]
                    // We need to call it directly
                    return builtin.call(&[first_arg_forced, argument_forced]);
                } else {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("builtin '{}' not found", builtin_name),
                    });
                }
            }
        }

        // Create a new scope that merges the closure with the argument binding
        // The parameter shadows any variable with the same name in the closure
        let mut scope = self.closure.clone();
        scope.insert(self.parameter.clone(), argument);

        // Parse the body expression text back into an AST node
        let tokens = tokenize(&self.body_text);
        let (green_node, errors) = parse(tokens.into_iter());

        if !errors.is_empty() {
            let error_msgs: Vec<String> = errors.iter().map(|e| format!("{:?}", e)).collect();
            return Err(Error::ParseError {
                reason: error_msgs.join(", "),
            });
        }

        let syntax_node = SyntaxNode::new_root(green_node);
        let root = Root::cast(syntax_node).ok_or(Error::AstConversionError)?;

        let body_expr = root.expr().ok_or(Error::NoExpression)?;

        // Restore the file_id context when calling the function
        // This is critical for relative imports within function bodies to work correctly
        // Push context with the function's file_id
        evaluator.push_context(self.file_id, scope.clone());

        // Evaluate the body expression using the merged scope
        let result = evaluator.evaluate_expr_with_scope(&body_expr, &scope);

        // Pop context (restore previous context)
        evaluator.pop_context();

        result
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_function_creation() {
        // This test is a placeholder - we'll need actual Expr nodes from rnix
        // For now, we'll test the structure
        use std::collections::HashMap;
        let _scope: VariableScope = HashMap::new();
        // In a real test, we'd parse an expression and create a function
        // let body_expr = parse("x + 1").unwrap();
        // let func = Function::new("x", &body_expr, scope);
        // assert_eq!(func.parameter(), "x");
    }

    #[test]
    fn test_function_apply() {
        // Placeholder test - will be expanded when we have actual Expr nodes
    }
}
