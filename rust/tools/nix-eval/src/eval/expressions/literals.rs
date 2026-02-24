//! Literal expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::value::NixValue;
use rnix::ast::{InterpolPart, Literal, Str};
use rowan::ast::AstNode;

impl Evaluator {
    pub(crate) fn evaluate_literal(&self, literal: &Literal) -> Result<NixValue> {
        let text = literal.to_string();

        // Remove quotes from string literals
        if text.starts_with('"') && text.ends_with('"') {
            // Basic string unescaping
            // Handle backslash-newline line continuation first (backslash followed by actual newline)
            // Then handle other escape sequences
            let mut unescaped = text[1..text.len() - 1].to_string();
            // Replace backslash followed by newline with just newline (line continuation)
            unescaped = unescaped.replace("\\\n", "\n");
            // Handle other escape sequences
            unescaped = unescaped
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

    pub(crate) fn evaluate_string(
        &self,
        str_expr: &Str,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        // Check if this is an indented string (multiline string using '')
        // In rnix, indented strings are represented differently - check the syntax
        let syntax_text = str_expr.syntax().text().to_string();
        let is_indented = syntax_text.trim_start().starts_with("''");

        let mut result = String::new();

        // Iterate over the parts of the string
        // In rnix, strings are composed of InterpolPart which can be either
        // a string literal or an interpolated expression
        for part in str_expr.parts() {
            match part {
                InterpolPart::Literal(literal) => {
                    // This is a literal string part
                    let part_text = literal.to_string();

                    if is_indented {
                        // For indented strings, handle special escaping
                        // '' becomes ', ''${ becomes ${, ''\n becomes \n, etc.
                        let mut unescaped = part_text
                            .replace("''", "'") // '' becomes '
                            .replace("''${", "${") // ''${ becomes ${
                            .replace("''\\n", "\\n") // ''\n becomes \n
                            .replace("''\\r", "\\r") // ''\r becomes \r
                            .replace("''\\t", "\\t"); // ''\t becomes \t

                        // Now handle regular escape sequences
                        unescaped = unescaped
                            .replace("\\n", "\n")
                            .replace("\\r", "\r")
                            .replace("\\t", "\t")
                            .replace("\\\"", "\"")
                            .replace("\\\\", "\\");

                        result.push_str(&unescaped);
                    } else {
                        // Regular string - unescape normally
                        // Handle backslash-newline line continuation first (backslash followed by actual newline)
                        let mut unescaped = part_text.replace("\\\n", "\n");
                        // Handle other escape sequences
                        unescaped = unescaped
                            .replace("\\n", "\n")
                            .replace("\\t", "\t")
                            .replace("\\\"", "\"")
                            .replace("\\\\", "\\")
                            .replace("\\${", "${"); // Unescape ${ in strings
                        result.push_str(&unescaped);
                    }
                }
                InterpolPart::Interpolation(interp) => {
                    // This is an interpolated expression - get the expression
                    if let Some(expr) = interp.expr() {
                        // Evaluate the interpolated expression and force thunks
                        let value = self.evaluate_expr_with_scope(&expr, scope)?;
                        let value_forced = value.force(self)?;

                        // Convert the value to a string
                        let value_str = match value_forced {
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
                                format!("{}", value_forced)
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

        // For indented strings, strip common indentation from all lines
        if is_indented {
            // Split into lines and find minimum indentation
            let lines: Vec<&str> = result.lines().collect();
            if !lines.is_empty() {
                // Find minimum indentation (excluding empty lines)
                let mut min_indent = usize::MAX;
                for line in &lines {
                    if !line.trim().is_empty() {
                        let indent = line.len() - line.trim_start().len();
                        min_indent = min_indent.min(indent);
                    }
                }

                // Strip the minimum indentation from each line
                let mut stripped_lines = Vec::new();
                for line in &lines {
                    if line.trim().is_empty() {
                        stripped_lines.push("");
                    } else {
                        let indent = line.len() - line.trim_start().len();
                        if indent >= min_indent {
                            stripped_lines.push(&line[min_indent..]);
                        } else {
                            stripped_lines.push(line);
                        }
                    }
                }

                // Join lines with \n
                result = stripped_lines.join("\n");
            }
        }

        Ok(NixValue::String(result))
    }
}
