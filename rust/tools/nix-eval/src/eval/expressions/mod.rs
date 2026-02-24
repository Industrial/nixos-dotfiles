//! Expression evaluation modules
//!
//! These modules contain the implementation of expression evaluation methods
//! for the Evaluator. They are organized by expression type for better
//! maintainability and clarity.

mod attrsets;
mod functions;
mod import;
mod lists;
mod literals;
mod operators;
mod special;

// Re-export all expression evaluation methods
pub use attrsets::*;
pub use functions::*;
pub use import::*;
pub use lists::*;
pub use literals::*;
pub use operators::*;
pub use special::*;
