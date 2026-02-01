//! Function/closure implementation for Nix functions
//!
//! Functions in Nix are closures that capture their lexical environment (scope)
//! and can be applied to arguments. This module provides the data structure
//! to represent Nix functions.

use crate::{Error, Evaluator, NixValue, Result, VariableScope};
use rnix::SyntaxNode;
use rnix::ast::{Expr, Root};
use rnix::parser::parse;
use rnix::tokenizer::tokenize;
use rowan::ast::AstNode;

/// A Nix function (closure)
///
/// Functions in Nix are closures that:
/// - Capture their lexical environment (scope) at definition time
/// - Have a parameter name (or pattern) that will be bound when applied
/// - Have a body expression that will be evaluated when the function is called
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
    body_text: String,
    /// The lexical closure (variable scope) captured at function definition time
    ///
    /// This allows the function to access variables from its surrounding scope
    /// even when called in a different context (lexical scoping).
    closure: VariableScope,
}

impl Function {
    /// Create a new function closure
    ///
    /// # Arguments
    ///
    /// * `parameter` - The parameter name (or pattern) for this function
    /// * `body_expr` - The body expression (from rnix AST)
    /// * `closure` - The lexical closure (variable scope) at function definition time
    ///
    /// # Returns
    ///
    /// A new function closure
    pub fn new(parameter: String, body_expr: &Expr, closure: VariableScope) -> Self {
        // Store the body expression as text representation for now
        // In a full implementation, we'd want to store the actual AST node
        // but that requires handling lifetimes carefully
        let body_text = body_expr.syntax().text().to_string();

        Self {
            parameter,
            body_text,
            closure,
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

        // Evaluate the body expression using the merged scope
        evaluator.evaluate_expr_with_scope(&body_expr, &scope)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::NixValue;

    #[test]
    fn test_function_creation() {
        // This test is a placeholder - we'll need actual Expr nodes from rnix
        // For now, we'll test the structure
        use std::collections::HashMap;
        let scope: VariableScope = HashMap::new();
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
