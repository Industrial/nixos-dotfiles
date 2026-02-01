//! Literal expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::value::NixValue;
use rnix::ast::{Literal, Str, InterpolPart};

impl Evaluator {
    pub(crate) fn evaluate_literal(&self, literal: &Literal) -> Result<NixValue> {
        let text = literal.to_string();

        // Remove quotes from string literals
        if text.starts_with('"') && text.ends_with('"') {
            // Basic string unescaping (simplified - doesn't handle all escape sequences)
            let unescaped = text[1..text.len() - 1]
                .replace("\\n", "\n")
                .replace("\\t", "\t")
                .replace("\\\"", "\"")
                .replace("\\\\", "\\");
            return Ok(NixValue::String(unescaped));
        }

        // Check for boolean literals
        if text == "true" {
            return Ok(NixValue::Boolean(true));
        }
        if text == "false" {
            return Ok(NixValue::Boolean(false));
        }
        if text == "null" {
            return Ok(NixValue::Null);
        }

        // Try to parse as integer
        if let Ok(int_val) = text.parse::<i64>() {
            return Ok(NixValue::Integer(int_val));
        }

        // Try to parse as float
        if let Ok(float_val) = text.parse::<f64>() {
            return Ok(NixValue::Float(float_val));
        }

        Err(Error::UnsupportedLiteral { literal: text })
    }

    pub(crate) fn evaluate_string(&self, str_expr: &Str, scope: &VariableScope) -> Result<NixValue> {
        let mut result = String::new();

        // Iterate over the parts of the string
        // In rnix, strings are composed of InterpolPart which can be either
        // a string literal or an interpolated expression
        for part in str_expr.parts() {
            match part {
                InterpolPart::Literal(literal) => {
                    // This is a literal string part
                    let part_text = literal.to_string();
                    // Unescape the string
                    let unescaped = part_text
                        .replace("\\n", "\n")
                        .replace("\\t", "\t")
                        .replace("\\\"", "\"")
                        .replace("\\\\", "\\")
                        .replace("\\${", "${"); // Unescape ${ in strings
                    result.push_str(&unescaped);
                }
                InterpolPart::Interpolation(interp) => {
                    // This is an interpolated expression - get the expression
                    if let Some(expr) = interp.expr() {
                        // Evaluate the interpolated expression
                        let value = self.evaluate_expr_with_scope(&expr, scope)?;

                        // Convert the value to a string
                        let value_str = match value {
                            NixValue::String(s) => s,
                            NixValue::Integer(i) => i.to_string(),
                            NixValue::Float(f) => f.to_string(),
                            NixValue::Boolean(b) => b.to_string(),
                            NixValue::Null => "".to_string(),
                            NixValue::Path(p) => p.display().to_string(),
                            NixValue::StorePath(p) => p.clone(),
                            NixValue::Derivation(drv) => format!("<derivation {}>", drv.name),
                            NixValue::List(_)
                            | NixValue::AttributeSet(_)
                            | NixValue::Thunk(_)
                            | NixValue::Function(_) => {
                                // For complex types, use their Display implementation
                                format!("{}", value)
                            }
                        };

                        result.push_str(&value_str);
                    } else {
                        return Err(Error::UnsupportedExpression {
                            reason: "interpolation missing expression".to_string(),
                        });
                    }
                }
            }
        }

        Ok(NixValue::String(result))
    }



}
