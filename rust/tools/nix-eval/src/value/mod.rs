//! Value representation for Nix expressions
//!
//! This module contains the core value types used to represent evaluated Nix expressions.

mod derivation;
mod display;
mod nix_value;

pub use derivation::Derivation;
pub use display::*;
pub use nix_value::NixValue;
