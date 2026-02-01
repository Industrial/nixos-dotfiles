//! Builtin functions for the Nix evaluator
//!
//! This module provides implementations of Nix builtin functions that can be
//! registered with the evaluator.

use crate::{Builtin, Error, NixValue, Result};
use std::collections::HashMap;
use std::sync::Arc;

/// Import builtin function
///
/// Imports and evaluates a Nix file. The argument must be a path value.
pub struct ImportBuiltin;

impl Builtin for ImportBuiltin {
    fn name(&self) -> &str {
        "import"
    }

    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("import takes 1 argument, got {}", args.len()),
            });
        }

        match &args[0] {
            NixValue::Path(path) => {
                // Import the file - this will be handled by the evaluator's import_file method
                // For now, return an error indicating this needs evaluator context
                Err(Error::UnsupportedExpression {
                    reason: "import builtin requires evaluator context".to_string(),
                })
            }
            NixValue::StorePath(path) => {
                // Same for store paths
                Err(Error::UnsupportedExpression {
                    reason: "import builtin requires evaluator context".to_string(),
                })
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("import expects a path, got {}", args[0]),
            }),
        }
    }
}

/// Type checking builtins
pub struct IsNullBuiltin;
impl Builtin for IsNullBuiltin {
    fn name(&self) -> &str {
        "isNull"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isNull takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(args[0], NixValue::Null)))
    }
}

pub struct IsBoolBuiltin;
impl Builtin for IsBoolBuiltin {
    fn name(&self) -> &str {
        "isBool"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isBool takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(args[0], NixValue::Boolean(_))))
    }
}

pub struct IsIntBuiltin;
impl Builtin for IsIntBuiltin {
    fn name(&self) -> &str {
        "isInt"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isInt takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(args[0], NixValue::Integer(_))))
    }
}

pub struct IsFloatBuiltin;
impl Builtin for IsFloatBuiltin {
    fn name(&self) -> &str {
        "isFloat"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isFloat takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(args[0], NixValue::Float(_))))
    }
}

pub struct IsStringBuiltin;
impl Builtin for IsStringBuiltin {
    fn name(&self) -> &str {
        "isString"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isString takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(args[0], NixValue::String(_))))
    }
}

pub struct IsPathBuiltin;
impl Builtin for IsPathBuiltin {
    fn name(&self) -> &str {
        "isPath"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isPath takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(
            args[0],
            NixValue::Path(_) | NixValue::StorePath(_)
        )))
    }
}

pub struct IsListBuiltin;
impl Builtin for IsListBuiltin {
    fn name(&self) -> &str {
        "isList"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isList takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(args[0], NixValue::List(_))))
    }
}

pub struct IsAttrsBuiltin;
impl Builtin for IsAttrsBuiltin {
    fn name(&self) -> &str {
        "isAttrs"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isAttrs takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(
            args[0],
            NixValue::AttributeSet(_)
        )))
    }
}

/// TypeOf builtin - returns the type of a value as a string
pub struct TypeOfBuiltin;
impl Builtin for TypeOfBuiltin {
    fn name(&self) -> &str {
        "typeOf"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("typeOf takes 1 argument, got {}", args.len()),
            });
        }
        let type_name = match args[0] {
            NixValue::Integer(_) => "int",
            NixValue::Float(_) => "float",
            NixValue::Boolean(_) => "bool",
            NixValue::String(_) => "string",
            NixValue::Null => "null",
            NixValue::List(_) => "list",
            NixValue::AttributeSet(_) => "set",
            NixValue::Path(_) => "path",
            NixValue::StorePath(_) => "path",
            NixValue::Derivation(_) => "lambda", // Derivations are callable in Nix
            NixValue::Thunk(_) => "thunk",
            NixValue::Function(_) => "lambda",
        };
        Ok(NixValue::String(type_name.to_string()))
    }
}

/// ToString builtin - converts a value to a string
pub struct ToStringBuiltin;
impl Builtin for ToStringBuiltin {
    fn name(&self) -> &str {
        "toString"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("toString takes 1 argument, got {}", args.len()),
            });
        }
        let str_value = match &args[0] {
            NixValue::String(s) => s.clone(),
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
                format!("{}", args[0])
            }
        };
        Ok(NixValue::String(str_value))
    }
}

/// Length builtin - returns the length of a list or string
pub struct LengthBuiltin;
impl Builtin for LengthBuiltin {
    fn name(&self) -> &str {
        "length"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("length takes 1 argument, got {}", args.len()),
            });
        }
        let len = match &args[0] {
            NixValue::List(l) => l.len(),
            NixValue::String(s) => s.len(),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("length expects a list or string, got {}", args[0]),
                });
            }
        };
        Ok(NixValue::Integer(len as i64))
    }
}

/// Head builtin - returns the first element of a list
pub struct HeadBuiltin;
impl Builtin for HeadBuiltin {
    fn name(&self) -> &str {
        "head"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("head takes 1 argument, got {}", args.len()),
            });
        }
        match &args[0] {
            NixValue::List(l) => l
                .first()
                .ok_or_else(|| Error::UnsupportedExpression {
                    reason: "head: list is empty".to_string(),
                })
                .cloned(),
            _ => Err(Error::UnsupportedExpression {
                reason: format!("head expects a list, got {}", args[0]),
            }),
        }
    }
}

/// Tail builtin - returns all but the first element of a list
pub struct TailBuiltin;
impl Builtin for TailBuiltin {
    fn name(&self) -> &str {
        "tail"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("tail takes 1 argument, got {}", args.len()),
            });
        }
        match &args[0] {
            NixValue::List(l) => {
                if l.is_empty() {
                    return Err(Error::UnsupportedExpression {
                        reason: "tail: list is empty".to_string(),
                    });
                }
                Ok(NixValue::List(l[1..].to_vec()))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("tail expects a list, got {}", args[0]),
            }),
        }
    }
}

/// AttrNames builtin - returns the attribute names of an attribute set as a list
pub struct AttrNamesBuiltin;
impl Builtin for AttrNamesBuiltin {
    fn name(&self) -> &str {
        "attrNames"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("attrNames takes 1 argument, got {}", args.len()),
            });
        }
        match &args[0] {
            NixValue::AttributeSet(attrs) => {
                let names: Vec<NixValue> =
                    attrs.keys().map(|k| NixValue::String(k.clone())).collect();
                Ok(NixValue::List(names))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("attrNames expects an attribute set, got {}", args[0]),
            }),
        }
    }
}

/// HasAttr builtin - checks if an attribute set has a specific attribute
pub struct HasAttrBuiltin;
impl Builtin for HasAttrBuiltin {
    fn name(&self) -> &str {
        "hasAttr"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("hasAttr takes 2 arguments, got {}", args.len()),
            });
        }
        let attr_name = match &args[0] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("hasAttr: first argument must be a string, got {}", args[0]),
                });
            }
        };
        match &args[1] {
            NixValue::AttributeSet(attrs) => Ok(NixValue::Boolean(attrs.contains_key(attr_name))),
            _ => Err(Error::UnsupportedExpression {
                reason: format!(
                    "hasAttr: second argument must be an attribute set, got {}",
                    args[1]
                ),
            }),
        }
    }
}

/// GetAttr builtin - gets an attribute from an attribute set, with optional default
pub struct GetAttrBuiltin;
impl Builtin for GetAttrBuiltin {
    fn name(&self) -> &str {
        "getAttr"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() < 2 || args.len() > 3 {
            return Err(Error::UnsupportedExpression {
                reason: format!("getAttr takes 2 or 3 arguments, got {}", args.len()),
            });
        }
        let attr_name = match &args[0] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("getAttr: first argument must be a string, got {}", args[0]),
                });
            }
        };
        match &args[1] {
            NixValue::AttributeSet(attrs) => {
                if let Some(value) = attrs.get(attr_name) {
                    Ok(value.clone())
                } else if args.len() == 3 {
                    // Return default value
                    Ok(args[2].clone())
                } else {
                    Err(Error::UnsupportedExpression {
                        reason: format!("getAttr: attribute '{}' not found", attr_name),
                    })
                }
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!(
                    "getAttr: second argument must be an attribute set, got {}",
                    args[1]
                ),
            }),
        }
    }
}

/// ConcatLists builtin - concatenates a list of lists
pub struct ConcatListsBuiltin;
impl Builtin for ConcatListsBuiltin {
    fn name(&self) -> &str {
        "concatLists"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("concatLists takes 1 argument, got {}", args.len()),
            });
        }
        match &args[0] {
            NixValue::List(lists) => {
                let mut result = Vec::new();
                for item in lists {
                    match item {
                        NixValue::List(l) => result.extend(l.clone()),
                        _ => {
                            return Err(Error::UnsupportedExpression {
                                reason: format!(
                                    "concatLists: all elements must be lists, got {}",
                                    item
                                ),
                            });
                        }
                    }
                }
                Ok(NixValue::List(result))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("concatLists expects a list, got {}", args[0]),
            }),
        }
    }
}

/// ConcatStringsSep builtin - concatenates strings with a separator
pub struct ConcatStringsSepBuiltin;
impl Builtin for ConcatStringsSepBuiltin {
    fn name(&self) -> &str {
        "concatStringsSep"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("concatStringsSep takes 2 arguments, got {}", args.len()),
            });
        }
        let separator = match &args[0] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!(
                        "concatStringsSep: first argument must be a string, got {}",
                        args[0]
                    ),
                });
            }
        };
        match &args[1] {
            NixValue::List(strings) => {
                let str_values: Result<Vec<String>> = strings
                    .iter()
                    .map(|v| match v {
                        NixValue::String(s) => Ok(s.clone()),
                        _ => Err(Error::UnsupportedExpression {
                            reason: format!(
                                "concatStringsSep: all elements must be strings, got {}",
                                v
                            ),
                        }),
                    })
                    .collect();
                let joined = str_values?.join(separator);
                Ok(NixValue::String(joined))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!(
                    "concatStringsSep: second argument must be a list, got {}",
                    args[1]
                ),
            }),
        }
    }
}

/// Abort builtin - aborts evaluation with an error message
pub struct AbortBuiltin;
impl Builtin for AbortBuiltin {
    fn name(&self) -> &str {
        "abort"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("abort takes 1 argument, got {}", args.len()),
            });
        }
        let message = match &args[0] {
            NixValue::String(s) => s.clone(),
            _ => format!("{}", args[0]),
        };
        Err(Error::UnsupportedExpression {
            reason: format!("abort: {}", message),
        })
    }
}

/// Trace builtin - prints a message and returns the second argument
pub struct TraceBuiltin;
impl Builtin for TraceBuiltin {
    fn name(&self) -> &str {
        "trace"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("trace takes 2 arguments, got {}", args.len()),
            });
        }
        let message = match &args[0] {
            NixValue::String(s) => s.clone(),
            _ => format!("{}", args[0]),
        };
        // In a real implementation, this would print to stderr
        // For now, we'll just return the value
        eprintln!("trace: {}", message);
        Ok(args[1].clone())
    }
}

/// Derivation builtin - creates a derivation (build plan)
///
/// Note: This requires evaluator context to properly handle paths and store paths.
/// For now, this is a placeholder that will need evaluator integration.
pub struct DerivationBuiltin;
impl Builtin for DerivationBuiltin {
    fn name(&self) -> &str {
        "derivation"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("derivation takes 1 argument, got {}", args.len()),
            });
        }

        // The argument should be an attribute set with derivation attributes
        match &args[0] {
            NixValue::AttributeSet(attrs) => {
                // Extract required attributes
                let name = attrs
                    .get("name")
                    .and_then(|v| match v {
                        NixValue::String(s) => Some(s.clone()),
                        _ => None,
                    })
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "derivation: missing or invalid 'name' attribute".to_string(),
                    })?;

                let system = attrs
                    .get("system")
                    .and_then(|v| match v {
                        NixValue::String(s) => Some(s.clone()),
                        _ => None,
                    })
                    .unwrap_or_else(|| "unknown".to_string());

                let builder = attrs
                    .get("builder")
                    .and_then(|v| match v {
                        NixValue::String(s) => Some(s.clone()),
                        NixValue::Path(p) => Some(p.display().to_string()),
                        NixValue::StorePath(p) => Some(p.clone()),
                        _ => None,
                    })
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "derivation: missing or invalid 'builder' attribute".to_string(),
                    })?;

                // Extract optional attributes
                let args = attrs
                    .get("args")
                    .and_then(|v| match v {
                        NixValue::List(l) => {
                            let str_args: Result<Vec<String>> = l
                                .iter()
                                .map(|item| match item {
                                    NixValue::String(s) => Ok(s.clone()),
                                    _ => Err(Error::UnsupportedExpression {
                                        reason: format!(
                                            "derivation args must be strings, got {}",
                                            item
                                        ),
                                    }),
                                })
                                .collect();
                            Some(str_args.ok()?)
                        }
                        _ => None,
                    })
                    .unwrap_or_default();

                // Extract environment variables
                let mut env = HashMap::new();
                let mut outputs = HashMap::new();

                // Check for explicit outputs attribute
                if let Some(NixValue::List(output_list)) = attrs.get("outputs") {
                    // Parse outputs list
                    for output in output_list {
                        if let NixValue::String(output_name) = output {
                            // Output paths will be computed after derivation creation
                            outputs.insert(output_name.clone(), String::new());
                        }
                    }
                }

                // If no outputs specified, default to "out"
                if outputs.is_empty() {
                    outputs.insert("out".to_string(), String::new());
                }

                for (key, value) in attrs {
                    if key != "name"
                        && key != "system"
                        && key != "builder"
                        && key != "args"
                        && key != "outputs"
                    {
                        // All other attributes become environment variables
                        let env_value = match value {
                            NixValue::String(s) => s.clone(),
                            _ => format!("{}", value),
                        };
                        env.insert(key.clone(), env_value);
                    }
                }

                // Create derivation structure
                let mut derivation = crate::Derivation {
                    name: name.clone(),
                    system,
                    builder,
                    args,
                    env,
                    input_derivations: HashMap::new(),
                    input_sources: Vec::new(),
                    outputs: HashMap::new(), // Will be populated after computing store path
                };

                // Compute store path and write .drv file
                // Note: In a full implementation, we'd also need to:
                // - Compute output paths based on the derivation hash
                // - Handle input derivations and sources properly
                // - Set up the $out environment variable
                let _store_path = derivation.write_to_store()?;

                // Compute output paths (simplified - in reality these depend on the derivation hash)
                // For now, we'll use placeholder paths that would be computed properly
                // in a full implementation
                for output_name in outputs.keys() {
                    // In a real implementation, output paths would be computed as:
                    // /nix/store/<hash>-<name>-<output-name>
                    // For now, we'll leave them empty as they require proper store path computation
                    derivation
                        .outputs
                        .insert(output_name.clone(), String::new());
                }

                // Set $out environment variable to the default output path
                if let Some(out_path) = derivation.outputs.get("out") {
                    if !out_path.is_empty() {
                        derivation.env.insert("out".to_string(), out_path.clone());
                    }
                }

                Ok(NixValue::Derivation(Arc::new(derivation)))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("derivation expects an attribute set, got {}", args[0]),
            }),
        }
    }
}

/// StorePath builtin - converts a string to a store path value
///
/// Validates that the string is a valid Nix store path and returns it as a StorePath value.
pub struct StorePathBuiltin;

impl Builtin for StorePathBuiltin {
    fn name(&self) -> &str {
        "storePath"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("storePath takes 1 argument, got {}", args.len()),
            });
        }

        match &args[0] {
            NixValue::String(path_str) => {
                // Validate that it's a valid store path format
                // Store paths have format: /nix/store/<hash>-<name>
                if !path_str.starts_with("/nix/store/") {
                    return Err(Error::UnsupportedExpression {
                        reason: format!(
                            "storePath: path must start with /nix/store/, got {}",
                            path_str
                        ),
                    });
                }

                // Extract the part after /nix/store/
                let store_part = &path_str[11..]; // Length of "/nix/store/"

                // Find the first `-` which separates hash from name
                if let Some(dash_pos) = store_part.find('-') {
                    let hash = &store_part[..dash_pos];
                    let _name = &store_part[dash_pos + 1..];

                    // Validate hash: should be base32 alphanumeric
                    if hash.is_empty() || !hash.chars().all(|c| c.is_ascii_alphanumeric()) {
                        return Err(Error::UnsupportedExpression {
                            reason: format!("storePath: invalid hash in path {}", path_str),
                        });
                    }

                    Ok(NixValue::StorePath(path_str.clone()))
                } else {
                    Err(Error::UnsupportedExpression {
                        reason: format!(
                            "storePath: invalid store path format, missing hash-name separator: {}",
                            path_str
                        ),
                    })
                }
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("storePath expects a string, got {}", args[0]),
            }),
        }
    }
}

/// Path builtin - creates a path value from a string
///
/// In Nix, `builtins.path` can:
/// - Convert a string to a path value
/// - Optionally copy files to the store (with name, filter, etc.)
/// For now, we implement basic string-to-path conversion.
pub struct PathBuiltin;

impl Builtin for PathBuiltin {
    fn name(&self) -> &str {
        "path"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() < 1 || args.len() > 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("path takes 1 or 2 arguments, got {}", args.len()),
            });
        }

        match &args[0] {
            NixValue::String(path_str) => {
                // If it's already a store path, return as StorePath
                if path_str.starts_with("/nix/store/") {
                    // Validate store path format
                    let store_part = &path_str[11..];
                    if let Some(dash_pos) = store_part.find('-') {
                        let hash = &store_part[..dash_pos];
                        if !hash.is_empty() && hash.chars().all(|c| c.is_ascii_alphanumeric()) {
                            return Ok(NixValue::StorePath(path_str.clone()));
                        }
                    }
                }

                // Otherwise, convert to a Path value
                use std::path::PathBuf;
                let path = PathBuf::from(path_str);
                Ok(NixValue::Path(path))
            }
            NixValue::Path(_) => {
                // Already a path, return as-is
                Ok(args[0].clone())
            }
            NixValue::StorePath(_) => {
                // Already a store path, return as-is
                Ok(args[0].clone())
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("path expects a string or path, got {}", args[0]),
            }),
        }
    }
}

/// GenList builtin - generates a list by calling a function for each index
///
/// `builtins.genList f n` generates a list of length n by calling f for each index from 0 to n-1.
/// This is a placeholder implementation - full implementation requires evaluator context to call Nix functions.
pub struct GenListBuiltin;

impl Builtin for GenListBuiltin {
    fn name(&self) -> &str {
        "genList"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("genList takes 2 arguments, got {}", args.len()),
            });
        }
        
        // Get the length
        let length = match &args[1] {
            NixValue::Integer(n) => {
                if *n < 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("genList: length must be non-negative, got {}", n),
                    });
                }
                *n as usize
            }
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("genList: second argument must be an integer, got {}", args[1]),
                });
            }
        };
        
        // Get the function
        // Note: This is a placeholder - full implementation would need evaluator context
        // to call the Nix function for each index
        match &args[0] {
            NixValue::Function(_) => {
                // For now, return an error indicating this needs evaluator context
                Err(Error::UnsupportedExpression {
                    reason: "genList requires evaluator context to call Nix functions".to_string(),
                })
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("genList: first argument must be a function, got {}", args[0]),
            }),
        }
    }
}
