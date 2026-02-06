//! Value representation for Nix expressions
//!
//! This module contains the core value types used to represent evaluated Nix expressions.

mod nix_value;
mod derivation;
mod display;

pub use nix_value::NixValue;
pub use derivation::Derivation;
pub use display::*;
