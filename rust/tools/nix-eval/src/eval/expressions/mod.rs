//! Expression evaluation modules
//!
//! These modules contain the implementation of expression evaluation methods
//! for the Evaluator. They are organized by expression type for better
//! maintainability and clarity.

mod literals;
mod lists;
mod attrsets;
mod functions;
mod operators;
mod special;
mod import;

// Re-export all expression evaluation methods
pub use literals::*;
pub use lists::*;
pub use attrsets::*;
pub use functions::*;
pub use operators::*;
pub use special::*;
pub use import::*;
