//! Operator expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::value::NixValue;
use rnix::ast::{BinOp, BinOpKind, UnaryOp, UnaryOpKind};
use rowan::ast::AstNode;

impl Evaluator {
        pub(crate) fn evaluate_binop(&self, binop: &BinOp, scope: &VariableScope) -> Result<NixValue> {
        // Get the left and right operands
        let lhs_expr = binop.lhs().ok_or_else(|| Error::UnsupportedExpression {
            reason: "binary operation missing left operand".to_string(),
        })?;

        let rhs_expr = binop.rhs().ok_or_else(|| Error::UnsupportedExpression {
            reason: "binary operation missing right operand".to_string(),
        })?;

        // Evaluate both operands
        let lhs_raw = self.evaluate_expr_with_scope(&lhs_expr, scope)?;
        let rhs_raw = self.evaluate_expr_with_scope(&rhs_expr, scope)?;
        
        // Force thunks before arithmetic operations
        let lhs = lhs_raw.clone().force(self)?;
        let rhs = rhs_raw.clone().force(self)?;

        // Get the operator
        let op = binop
            .operator()
            .ok_or_else(|| Error::UnsupportedExpression {
                reason: "binary operation missing operator".to_string(),
            })?;

        // Handle arithmetic operators based on BinOpKind
        // Note: In Nix, `//` is used for both integer division and attribute set updates.
        // We'll handle it as integer division here for arithmetic operations.
        // Attribute set updates will be handled separately when we implement that feature.
        match op {
            BinOpKind::Add => self.evaluate_add(&lhs, &rhs),
            BinOpKind::Sub => self.evaluate_subtract(&lhs, &rhs),
            BinOpKind::Mul => self.evaluate_multiply(&lhs, &rhs),
            BinOpKind::Div => self.evaluate_divide(&lhs, &rhs),
            BinOpKind::Update => {
                // `//` operator: Check if operands are integers (integer division) or attribute sets (update)
                match (&lhs, &rhs) {
                    (NixValue::Integer(_), NixValue::Integer(_)) => {
                        self.evaluate_integer_divide(&lhs, &rhs)
                    }
                    (NixValue::AttributeSet(lhs_attrs), NixValue::AttributeSet(rhs_attrs)) => {
                        // Attribute set update: merge rhs into lhs, with rhs values taking precedence
                        let mut result = lhs_attrs.clone();
                        // Add/override attributes from rhs
                        for (key, value) in rhs_attrs {
                            result.insert(key.clone(), value.clone());
                        }
                        Ok(NixValue::AttributeSet(result))
                    }
                    _ => Err(Error::UnsupportedExpression {
                        reason: format!("cannot apply // operator to {} and {}", lhs, rhs),
                    }),
                }
            }
            // Comparison operators
            BinOpKind::Equal => self.evaluate_equal(&lhs, &rhs),
            BinOpKind::NotEqual => self.evaluate_not_equal(&lhs, &rhs),
            BinOpKind::Less => self.evaluate_less(&lhs, &rhs),
            BinOpKind::More => self.evaluate_greater(&lhs, &rhs),
            // Note: <= and >= operators may be represented differently in rnix
            // For now, we handle ==, !=, <, >. <= and >= can be added when we determine the correct variant names.
            // Logical operators
            BinOpKind::And => self.evaluate_and(&lhs, &rhs),
            BinOpKind::Or => self.evaluate_or(&lhs, &rhs),
            // List concatenation operator
            BinOpKind::Concat => self.evaluate_concat(&lhs, &rhs),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("unsupported binary operator: {:?}", op),
            }),
        }
    }

    /// Evaluate addition operation
    ///
    /// In Nix, `+` can be used for:
    /// - Integer addition: `1 + 2` → `3`
    /// - Float addition: `1.5 + 2.5` → `4.0`
    /// - String concatenation: `"hello" + "world"` → `"helloworld"`


        pub(crate) fn evaluate_unary_op(&self, unary_op: &UnaryOp, scope: &VariableScope) -> Result<NixValue> {
        // Get the operator text from the syntax node
        // The operator token is part of the syntax tree
        let op_text = unary_op.syntax().text().to_string();
        
        // Get the operand expression
        let operand_expr = unary_op.expr().ok_or_else(|| Error::UnsupportedExpression {
            reason: "unary operation missing operand".to_string(),
        })?;
        
        // Evaluate the operand
        let operand_value = self.evaluate_expr_with_scope(&operand_expr, scope)?;
        
        // Force thunks before applying unary operators
        let operand = operand_value.clone().force(self)?;
        
        // Apply the unary operator based on the text
        // The operator text will be "-" for unary minus
        if op_text.starts_with('-') {
            // Unary minus: negate the value
            match operand {
                NixValue::Integer(n) => Ok(NixValue::Integer(-n)),
                NixValue::Float(f) => Ok(NixValue::Float(-f)),
                _ => Err(Error::UnsupportedExpression {
                    reason: format!("cannot apply unary minus to {}", operand),
                }),
            }
        } else if op_text.starts_with('+') {
            // Unary plus: no-op (just return the value)
            Ok(operand)
        } else {
            Err(Error::UnsupportedExpression {
                reason: format!("unsupported unary operator: {}", op_text),
            })
        }
    }

    /// Evaluate integer division operation
    ///


        pub(crate) fn evaluate_add(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        // Force thunks before addition
        let lhs_forced = lhs.clone().force(self)?;
        let rhs_forced = rhs.clone().force(self)?;
        
        match (&lhs_forced, &rhs_forced) {
            (NixValue::Integer(a), NixValue::Integer(b)) => Ok(NixValue::Integer(a + b)),
            (NixValue::Float(a), NixValue::Float(b)) => Ok(NixValue::Float(a + b)),
            (NixValue::Integer(a), NixValue::Float(b)) => Ok(NixValue::Float(*a as f64 + b)),
            (NixValue::Float(a), NixValue::Integer(b)) => Ok(NixValue::Float(a + *b as f64)),
            (NixValue::String(a), NixValue::String(b)) => {
                Ok(NixValue::String(format!("{}{}", a, b)))
            }
            (NixValue::List(a), NixValue::List(b)) => {
                let mut result = a.clone();
                result.extend(b.clone());
                Ok(NixValue::List(result))
            }
            // Path + String: concatenate path with string
            // In Nix, path + string concatenates the string as a path component
            // Special case: if string is "/", it's treated as empty (no-op)
            (NixValue::Path(lhs_path), NixValue::String(rhs_str)) => {
                use std::path::PathBuf;
                if rhs_str == "/" {
                    // Special case: /bin + "/" = /bin
                    Ok(NixValue::Path(lhs_path.clone()))
                } else if rhs_str.starts_with('/') {
                    // If string starts with "/", treat it as a path component
                    // e.g., /bin + "/bar" = /bin/bar
                    let mut result = lhs_path.clone();
                    let component = &rhs_str[1..]; // Remove leading "/"
                    if !component.is_empty() {
                        result.push(component);
                    }
                    Ok(NixValue::Path(result))
                } else {
                    // Direct string concatenation: /bin + "bar" = /binbar
                    // Convert path to string, append, then convert back
                    let lhs_str = lhs_path.to_string_lossy();
                    let combined = format!("{}{}", lhs_str, rhs_str);
                    Ok(NixValue::Path(PathBuf::from(combined)))
                }
            }
            // Path + Path: concatenate two paths
            // In Nix, path + path concatenates the second path as components of the first
            // e.g., /bin + /bin = /bin/bin
            (NixValue::Path(lhs_path), NixValue::Path(rhs_path)) => {
                use std::path::PathBuf;
                let mut result = lhs_path.clone();
                // Append all components from rhs_path to lhs_path
                for component in rhs_path.components() {
                    if let std::path::Component::Normal(comp) = component {
                        result.push(comp);
                    } else if let std::path::Component::RootDir = component {
                        // Root dir in rhs is ignored when appending
                        continue;
                    } else {
                        result.push(component.as_os_str());
                    }
                }
                Ok(NixValue::Path(result))
            }
            // String + Path: convert path to string and concatenate
            (NixValue::String(lhs_str), NixValue::Path(rhs_path)) => {
                let rhs_str = rhs_path.to_string_lossy();
                Ok(NixValue::String(format!("{}{}", lhs_str, rhs_str)))
            }
            // Path + Path: concatenate two paths
            // In Nix, path + path appends the components of the second path to the first
            // e.g., /bin + /bin = /bin/bin (not /bin)
            (NixValue::Path(lhs_path), NixValue::Path(rhs_path)) => {
                use std::path::PathBuf;
                let mut result = lhs_path.clone();
                // Append all components from rhs_path to lhs_path
                // Skip the root component if present
                for component in rhs_path.components() {
                    match component {
                        std::path::Component::RootDir => {
                            // Skip root dir - we want to append components, not replace
                            continue;
                        }
                        std::path::Component::Normal(comp) => {
                            result.push(comp);
                        }
                        _ => {
                            // Handle other component types
                            result.push(component.as_os_str());
                        }
                    }
                }
                Ok(NixValue::Path(result))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot add {} and {}", lhs, rhs),
            }),
        }
    }

    /// Evaluate subtraction operation
    ///
    /// In Nix, `-` is used for:
    /// - Integer subtraction: `5 - 2` → `3`


        pub(crate) fn evaluate_subtract(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => Ok(NixValue::Integer(a - b)),
            (NixValue::Float(a), NixValue::Float(b)) => Ok(NixValue::Float(a - b)),
            (NixValue::Integer(a), NixValue::Float(b)) => Ok(NixValue::Float(*a as f64 - b)),
            (NixValue::Float(a), NixValue::Integer(b)) => Ok(NixValue::Float(a - *b as f64)),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot subtract {} from {}", rhs, lhs),
            }),
        }
    }

    /// Evaluate multiplication operation
    ///
    /// In Nix, `*` is used for:
    /// - Integer multiplication: `2 * 3` → `6`


        pub(crate) fn evaluate_multiply(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => Ok(NixValue::Integer(a * b)),
            (NixValue::Float(a), NixValue::Float(b)) => Ok(NixValue::Float(a * b)),
            (NixValue::Integer(a), NixValue::Float(b)) => Ok(NixValue::Float(*a as f64 * b)),
            (NixValue::Float(a), NixValue::Integer(b)) => Ok(NixValue::Float(a * *b as f64)),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot multiply {} and {}", lhs, rhs),
            }),
        }
    }

    /// Evaluate division operation
    ///
    /// In Nix, `/` is used for:


        pub(crate) fn evaluate_divide(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                if *b == 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(*a as f64 / *b as f64))
            }
            (NixValue::Float(a), NixValue::Float(b)) => {
                if *b == 0.0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(a / b))
            }
            (NixValue::Integer(a), NixValue::Float(b)) => {
                if *b == 0.0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(*a as f64 / b))
            }
            (NixValue::Float(a), NixValue::Integer(b)) => {
                if *b == 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                Ok(NixValue::Float(a / *b as f64))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot divide {} by {}", lhs, rhs),
            }),
        }
    }

    /// Evaluate a parenthesized expression
    ///


        pub(crate) fn evaluate_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        // Deep force both sides to ensure all nested thunks are evaluated
        let lhs_deep = lhs.clone().deep_force(self)?;
        let rhs_deep = rhs.clone().deep_force(self)?;
        
        let result = match (&lhs_deep, &rhs_deep) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a == b,
            (NixValue::Float(a), NixValue::Float(b)) => a == b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) == *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a == (*b as f64),
            (NixValue::String(a), NixValue::String(b)) => a == b,
            (NixValue::Boolean(a), NixValue::Boolean(b)) => a == b,
            (NixValue::Null, NixValue::Null) => true,
            (NixValue::List(a), NixValue::List(b)) => {
                // Compare lists element by element, forcing thunks
                if a.len() != b.len() {
                    false
                } else {
                    a.iter().zip(b.iter()).all(|(a_elem, b_elem)| {
                        // Force thunks in list elements before comparison
                        match (a_elem.clone().force(self), b_elem.clone().force(self)) {
                            (Ok(a_val), Ok(b_val)) => a_val == b_val,
                            _ => false,
                        }
                    })
                }
            },
            (NixValue::AttributeSet(a), NixValue::AttributeSet(b)) => {
                // Compare attribute sets - they're already deeply forced at the top level
                // But we need to recursively compare nested attribute sets
                if a.len() != b.len() {
                    false
                } else {
                    a.iter().all(|(key, a_val)| {
                        if let Some(b_val) = b.get(key) {
                            // Recursively compare values, handling nested attribute sets
                            match (a_val, b_val) {
                                (NixValue::AttributeSet(_), NixValue::AttributeSet(_)) => {
                                    // Recursively compare nested attribute sets
                                    match self.evaluate_equal(a_val, b_val) {
                                        Ok(NixValue::Boolean(true)) => true,
                                        _ => false,
                                    }
                                }
                                _ => a_val == b_val,
                            }
                        } else {
                            false
                        }
                    })
                }
            },
            (NixValue::Path(a), NixValue::Path(b)) => a == b,
            _ => false, // Different types are never equal
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate inequality comparison (`!=`)
    ///


        pub(crate) fn evaluate_not_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let equal = self.evaluate_equal(lhs, rhs)?;
        match equal {
            NixValue::Boolean(b) => Ok(NixValue::Boolean(!b)),
            _ => unreachable!("evaluate_equal should always return Boolean"),
        }
    }

    /// Evaluate less-than comparison (`<`)
    ///


        pub(crate) fn evaluate_less(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a < b,
            (NixValue::Float(a), NixValue::Float(b)) => a < b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) < *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a < (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with <", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate less-than-or-equal comparison (`<=`)
    ///


        pub(crate) fn evaluate_greater(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a > b,
            (NixValue::Float(a), NixValue::Float(b)) => a > b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) > *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a > (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with >", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate greater-than-or-equal comparison (`>=`)
    ///


        pub(crate) fn evaluate_less_or_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a <= b,
            (NixValue::Float(a), NixValue::Float(b)) => a <= b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) <= *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a <= (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with <=", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate greater-than comparison (`>`)
    ///


        pub(crate) fn evaluate_greater_or_equal(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        let result = match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => a >= b,
            (NixValue::Float(a), NixValue::Float(b)) => a >= b,
            (NixValue::Integer(a), NixValue::Float(b)) => (*a as f64) >= *b,
            (NixValue::Float(a), NixValue::Integer(b)) => *a >= (*b as f64),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("cannot compare {} and {} with >=", lhs, rhs),
                });
            }
        };
        Ok(NixValue::Boolean(result))
    }

    /// Evaluate logical AND operation (`&&`)
    ///
    /// In Nix, `&&` performs short-circuit evaluation:
    /// - If the left operand is falsy (false or null), return it without evaluating the right operand


        pub(crate) fn evaluate_and(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        // Check if lhs is falsy (false or null)
        let lhs_falsy = matches!(lhs, NixValue::Boolean(false) | NixValue::Null);

        if lhs_falsy {
            // Short-circuit: return lhs without evaluating rhs
            Ok(lhs.clone())
        } else {
            // Return rhs (already evaluated)
            Ok(rhs.clone())
        }
    }

    /// Evaluate logical OR operation (`||`)
    ///
    /// In Nix, `||` performs short-circuit evaluation:
    /// - If the left operand is truthy (not false and not null), return it without evaluating the right operand


        pub(crate) fn evaluate_or(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        // Check if lhs is falsy (false or null)
        let lhs_falsy = matches!(lhs, NixValue::Boolean(false) | NixValue::Null);

        if lhs_falsy {
            // Return rhs (already evaluated)
            Ok(rhs.clone())
        } else {
            // Short-circuit: return lhs without evaluating rhs
            Ok(lhs.clone())
        }
    }

    /// Evaluate list concatenation operation (`++`)
    ///


        pub(crate) fn evaluate_concat(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::List(a), NixValue::List(b)) => {
                let mut result = a.clone();
                result.extend(b.clone());
                Ok(NixValue::List(result))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot concatenate {} and {} with ++", lhs, rhs),
            }),
        }
    }

    /// Import and evaluate a Nix file
    ///
    /// This method loads a .nix file, parses it, and evaluates it.
    /// Results are cached to avoid re-evaluating the same file multiple times.
    ///
    /// In Nix, importing a directory automatically looks for `default.nix` in that directory.


        pub(crate) fn evaluate_integer_divide(&self, lhs: &NixValue, rhs: &NixValue) -> Result<NixValue> {
        match (lhs, rhs) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                if *b == 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "integer division by zero".to_string(),
                    });
                }
                Ok(NixValue::Integer(a / b))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("cannot perform integer division on {} and {}", lhs, rhs),
            }),
        }
    }

}
