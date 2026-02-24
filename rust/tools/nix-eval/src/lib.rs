//! # nix-eval
//!
//! A pure Rust library for evaluating Nix expressions.

mod builtin;
mod builtins;
mod error;
mod eval;
mod function;
mod prelude;
mod thunk;
mod value;

// Re-export public API
pub use builtin::Builtin;
pub use error::{Error, Result};
pub use eval::{EvaluationContext, Evaluator, VariableScope};
pub use function::Function;
pub use thunk::Thunk;
pub use value::{Derivation, NixValue};
