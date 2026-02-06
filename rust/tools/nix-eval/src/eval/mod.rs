//! Evaluation logic for Nix expressions

mod context;
mod evaluator;
pub mod expressions;

pub use context::{EvaluationContext, VariableScope};
pub use evaluator::Evaluator;
