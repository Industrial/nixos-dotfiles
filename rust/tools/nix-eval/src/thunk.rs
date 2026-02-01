//! Thunk implementation for lazy evaluation
//!
//! A thunk represents a delayed computation in Nix. It stores the expression
//! to evaluate and its lexical closure (scope), allowing lazy evaluation
//! where expressions are only evaluated when their values are needed.

use crate::{Error, Evaluator, NixValue, Result, VariableScope};
use rnix::SyntaxNode;
use rnix::ast::{Expr, Root};
use rnix::parser::parse;
use rnix::tokenizer::tokenize;
use rowan::ast::AstNode;
use std::sync::{Arc, Mutex};

/// Represents the state of a thunk during evaluation
#[derive(Debug, Clone, PartialEq)]
enum ThunkState {
    /// Thunk has not been evaluated yet
    Suspended,
    /// Thunk is currently being evaluated (blackhole marker for infinite recursion detection)
    Evaluating,
    /// Thunk has been evaluated and the result is cached
    Evaluated,
}

/// A thunk represents a delayed computation in Nix
///
/// Thunks are the foundation of lazy evaluation. They store:
/// - The expression to evaluate (from the rnix AST)
/// - The lexical closure (variable scope) at the time of thunk creation
/// - The evaluation state (suspended, evaluating, or evaluated with cached result)
///
/// # Example
///
/// ```no_run
/// use nix_eval::thunk::Thunk;
/// use nix_eval::{Expr, VariableScope};
/// use std::collections::HashMap;
///
/// // Create a thunk for a simple expression
/// let scope: VariableScope = HashMap::new();
/// // Note: In practice, you'd create this from an actual Expr node
/// ```
#[derive(Debug, Clone)]
pub struct Thunk {
    /// The expression to evaluate (stored as the syntax node)
    /// We store the syntax node text representation for now, as Expr has lifetime constraints
    expression_text: String,
    /// The lexical closure (variable scope) at thunk creation time
    closure: VariableScope,
    /// The current state of the thunk
    state: Arc<Mutex<ThunkState>>,
    /// Cached result after evaluation (None if not yet evaluated)
    cached_value: Arc<Mutex<Option<NixValue>>>,
}

impl Thunk {
    /// Create a new suspended thunk
    ///
    /// # Arguments
    ///
    /// * `expr` - The expression to evaluate (from rnix AST)
    /// * `closure` - The lexical closure (variable scope) at thunk creation
    ///
    /// # Returns
    ///
    /// A new thunk in the Suspended state
    pub fn new(expr: &Expr, closure: VariableScope) -> Self {
        // Store the expression as text representation for now
        // In a full implementation, we'd want to store the actual AST node
        // but that requires handling lifetimes carefully
        let expression_text = expr.syntax().text().to_string();

        Self {
            expression_text,
            closure,
            state: Arc::new(Mutex::new(ThunkState::Suspended)),
            cached_value: Arc::new(Mutex::new(None)),
        }
    }

    /// Get the expression text stored in this thunk
    ///
    /// This is a temporary solution. In a full implementation, we'd return
    /// the actual Expr AST node for evaluation.
    pub fn expression_text(&self) -> &str {
        &self.expression_text
    }

    /// Get a reference to the lexical closure
    pub fn closure(&self) -> &VariableScope {
        &self.closure
    }

    /// Get the current state of the thunk
    pub fn state(&self) -> ThunkState {
        self.state.lock().unwrap().clone()
    }

    /// Check if the thunk is suspended (not yet evaluated)
    pub fn is_suspended(&self) -> bool {
        matches!(self.state(), ThunkState::Suspended)
    }

    /// Check if the thunk is currently being evaluated
    pub fn is_evaluating(&self) -> bool {
        matches!(self.state(), ThunkState::Evaluating)
    }

    /// Check if the thunk has been evaluated
    pub fn is_evaluated(&self) -> bool {
        matches!(self.state(), ThunkState::Evaluated)
    }

    /// Force evaluation of the thunk
    ///
    /// This method evaluates the thunk's expression using the stored lexical closure.
    /// If the thunk has already been evaluated, it returns the cached result.
    /// If the thunk is currently being evaluated (blackhole), it returns an error.
    ///
    /// # Arguments
    ///
    /// * `evaluator` - The evaluator to use for evaluating the expression
    ///
    /// # Returns
    ///
    /// * `Ok(NixValue)` - The evaluated value
    /// * `Err(Error)` - An error if evaluation fails or if infinite recursion is detected
    ///
    /// # Example
    ///
    /// ```no_run
    /// use nix_eval::{Evaluator, Thunk};
    /// use rnix::ast::Expr;
    /// use std::collections::HashMap;
    ///
    /// let evaluator = Evaluator::new();
    /// // Create a thunk and force it
    /// // let thunk = Thunk::new(&expr, HashMap::new());
    /// // let value = thunk.force(&evaluator)?;
    /// ```
    pub fn force(&self, evaluator: &Evaluator) -> Result<NixValue> {
        // Check current state
        let mut state_guard = self.state.lock().unwrap();

        match *state_guard {
            ThunkState::Evaluated => {
                // Already evaluated - return cached value (memoization)
                // This is the fast path: if the thunk has been evaluated before,
                // we return the cached result without re-evaluating.
                drop(state_guard);
                let value_guard = self.cached_value.lock().unwrap();
                value_guard
                    .clone()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "thunk marked as evaluated but no cached value found".to_string(),
                    })
            }
            ThunkState::Evaluating => {
                // Blackhole detected - infinite recursion
                // This occurs when a thunk tries to evaluate itself while already
                // being evaluated. The Evaluating state acts as a "blackhole" marker
                // that prevents stack overflow by detecting this condition early.
                drop(state_guard);
                Err(Error::InfiniteRecursion)
            }
            ThunkState::Suspended => {
                // Set blackhole marker before evaluation
                // This prevents infinite recursion: if this thunk tries to evaluate
                // itself (directly or indirectly) while we're evaluating it, we'll
                // detect the Evaluating state and return an error instead of
                // causing a stack overflow.
                *state_guard = ThunkState::Evaluating;
                drop(state_guard);

                // Parse the expression text back into an AST node
                let tokens = tokenize(&self.expression_text);
                let (green_node, errors) = parse(tokens.into_iter());

                if !errors.is_empty() {
                    let error_msgs: Vec<String> =
                        errors.iter().map(|e| format!("{:?}", e)).collect();
                    // Reset state on error
                    *self.state.lock().unwrap() = ThunkState::Suspended;
                    return Err(Error::ParseError {
                        reason: error_msgs.join(", "),
                    });
                }

                let syntax_node = SyntaxNode::new_root(green_node);
                let root = Root::cast(syntax_node).ok_or_else(|| {
                    // Reset state on error
                    *self.state.lock().unwrap() = ThunkState::Suspended;
                    Error::AstConversionError
                })?;

                let expr = root.expr().ok_or_else(|| {
                    // Reset state on error
                    *self.state.lock().unwrap() = ThunkState::Suspended;
                    Error::NoExpression
                })?;

                // Evaluate the expression using the thunk's closure as the scope
                let result = evaluator.evaluate_expr_with_scope(&expr, &self.closure);

                // Update state and cache result (memoization)
                // Once evaluated, the result is cached so subsequent calls to force()
                // will return the cached value without re-evaluation.
                match result {
                    Ok(value) => {
                        let mut state_guard = self.state.lock().unwrap();
                        let mut value_guard = self.cached_value.lock().unwrap();
                        *state_guard = ThunkState::Evaluated;
                        *value_guard = Some(value.clone());
                        Ok(value)
                    }
                    Err(e) => {
                        // Reset state on error so the thunk can be retried
                        *self.state.lock().unwrap() = ThunkState::Suspended;
                        Err(e)
                    }
                }
            }
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::NixValue;
    use std::collections::HashMap;

    #[test]
    fn test_thunk_creation() {
        // This test is a placeholder - we'll need actual Expr nodes from rnix
        // For now, we'll test the structure
        let scope: VariableScope = HashMap::new();
        // In a real test, we'd parse an expression and create a thunk
        // let expr = parse("42").unwrap();
        // let thunk = Thunk::new(&expr, scope);
        // assert!(thunk.is_suspended());
    }

    #[test]
    fn test_thunk_state() {
        let scope: VariableScope = HashMap::new();
        // Placeholder test - will be expanded when we have actual Expr nodes
    }
}
