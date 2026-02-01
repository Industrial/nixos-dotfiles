//! Display and equality implementations for NixValue

use crate::value::NixValue;
use std::fmt;
use std::sync::Arc;

/// Format a Nix value as a string
impl fmt::Display for NixValue {
    fn fmt(&self, f: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            NixValue::String(s) => write!(f, "\"{}\"", s),
            NixValue::Integer(i) => write!(f, "{}", i),
            NixValue::Float(fl) => {
                // Nix displays floats with a maximum of 5 significant digits
                // Format with 5 digits precision, removing trailing zeros
                let formatted = format!("{:.5}", fl);
                let trimmed = formatted.trim_end_matches('0').trim_end_matches('.');
                write!(f, "{}", trimmed)
            }
            NixValue::Boolean(b) => write!(f, "{}", b),
            NixValue::Null => write!(f, "null"),
            NixValue::AttributeSet(attrs) => {
                // Sort keys for deterministic output (Nix attribute sets are ordered)
                let mut sorted_keys: Vec<&String> = attrs.keys().collect();
                sorted_keys.sort();
                let entries: Vec<String> = sorted_keys
                    .iter()
                    .map(|k| format!("{} = {};", k, attrs[*k]))
                    .collect();
                write!(f, "{{ {} }}", entries.join(" "))
            }
            NixValue::List(items) => {
                if items.is_empty() {
                    write!(f, "[ ]")
                } else {
                    let items_str: Vec<String> = items.iter().map(|v| format!("{}", v)).collect();
                    write!(f, "[ {} ]", items_str.join(" "))
                }
            }
            NixValue::Thunk(_) => {
                write!(f, "<thunk>")
            }
            NixValue::Function(func) => {
                write!(f, "<function {}: {}>", func.parameter(), func.body_text())
            }
            NixValue::Path(path) => {
                write!(f, "{}", path.display())
            }
            NixValue::StorePath(path) => {
                write!(f, "{}", path)
            }
            NixValue::Derivation(drv) => {
                write!(f, "<derivation {}>", drv.name)
            }
        }
    }
}

impl PartialEq for NixValue {
    fn eq(&self, other: &Self) -> bool {
        // For thunks and functions, we compare by pointer identity since forcing/applying requires an evaluator
        // In practice, thunks should be forced before comparison, and functions are compared by identity
        match (self, other) {
            (NixValue::Thunk(a), NixValue::Thunk(b)) => Arc::ptr_eq(a, b),
            (NixValue::Function(a), NixValue::Function(b)) => Arc::ptr_eq(a, b),
            (NixValue::String(a), NixValue::String(b)) => a == b,
            (NixValue::Integer(a), NixValue::Integer(b)) => a == b,
            (NixValue::Float(a), NixValue::Float(b)) => a == b,
            (NixValue::Boolean(a), NixValue::Boolean(b)) => a == b,
            (NixValue::Null, NixValue::Null) => true,
            (NixValue::List(a), NixValue::List(b)) => a == b,
            (NixValue::AttributeSet(a), NixValue::AttributeSet(b)) => a == b,
            (NixValue::Path(a), NixValue::Path(b)) => a == b,
            (NixValue::StorePath(a), NixValue::StorePath(b)) => a == b,
            (NixValue::Derivation(a), NixValue::Derivation(b)) => Arc::ptr_eq(a, b),
            _ => false,
        }
    }
}
