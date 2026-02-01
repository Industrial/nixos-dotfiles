//! Builtin functions for the Nix evaluator
//!
//! This module provides implementations of Nix builtin functions that can be
//! registered with the evaluator.

use crate::builtin::Builtin;
use crate::error::{Error, Result};
use crate::value::NixValue;
use std::collections::HashMap;
use std::sync::Arc;
use std::path::PathBuf;
use regex::Regex;

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
            NixValue::Path(_path) => {
                // Import the file - this will be handled by the evaluator's import_file method
                // For now, return an error indicating this needs evaluator context
                Err(Error::UnsupportedExpression {
                    reason: "import builtin requires evaluator context".to_string(),
                })
            }
            NixValue::StorePath(_path) => {
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

/// IsFunction builtin - checks if a value is a function
pub struct IsFunctionBuiltin;
impl Builtin for IsFunctionBuiltin {
    fn name(&self) -> &str {
        "isFunction"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("isFunction takes 1 argument, got {}", args.len()),
            });
        }
        Ok(NixValue::Boolean(matches!(
            args[0],
            NixValue::Function(_)
        )))
    }
}

/// StringLength builtin - returns the length of a string (alias for length)
pub struct StringLengthBuiltin;
impl Builtin for StringLengthBuiltin {
    fn name(&self) -> &str {
        "stringLength"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("stringLength takes 1 argument, got {}", args.len()),
            });
        }
        let len = match &args[0] {
            NixValue::String(s) => s.len(),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("stringLength expects a string, got {}", args[0]),
                });
            }
        };
        Ok(NixValue::Integer(len as i64))
    }
}

/// Seq builtin - forces evaluation of first argument, returns second argument
/// 
/// `builtins.seq a b` evaluates `a` (forcing any thunks) and then returns `b`.
/// This is used for strict evaluation in otherwise lazy contexts.
pub struct SeqBuiltin;
impl Builtin for SeqBuiltin {
    fn name(&self) -> &str {
        "seq"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("seq takes 2 arguments, got {}", args.len()),
            });
        }
        // Force the first argument (evaluate any thunks)
        // Note: This requires evaluator context, so seq needs special handling
        // For now, we'll return an error indicating it needs evaluator context
        Err(Error::UnsupportedExpression {
            reason: "seq requires evaluator context to force thunks".to_string(),
        })
    }
}

/// Elem builtin - checks if an element is in a list
/// 
/// `builtins.elem x xs` returns true if `x` is an element of list `xs`.
/// Note: This requires evaluator context to force thunks in the list.
pub struct ElemBuiltin;
impl Builtin for ElemBuiltin {
    fn name(&self) -> &str {
        "elem"
    }
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // elem requires evaluator context to force thunks in the list
        // It's handled specially in evaluate_apply
        Err(Error::UnsupportedExpression {
            reason: "elem requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// IntersectAttrs builtin - returns the intersection of two attribute sets
/// 
/// `builtins.intersectAttrs e1 e2` returns an attribute set containing only the attributes
/// that are present in both `e1` and `e2`, with values from `e2`.
pub struct IntersectAttrsBuiltin;
impl Builtin for IntersectAttrsBuiltin {
    fn name(&self) -> &str {
        "intersectAttrs"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("intersectAttrs takes 2 arguments, got {}", args.len()),
            });
        }
        match (&args[0], &args[1]) {
            (NixValue::AttributeSet(e1), NixValue::AttributeSet(e2)) => {
                let mut result = HashMap::new();
                // Only include attributes that exist in both sets, with values from e2
                for (key, value) in e2 {
                    if e1.contains_key(key) {
                        result.insert(key.clone(), value.clone());
                    }
                }
                Ok(NixValue::AttributeSet(result))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("intersectAttrs: both arguments must be attribute sets, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// ElemAt builtin - gets an element from a list by index
/// 
/// `builtins.elemAt xs n` returns the element at index `n` (0-based) in list `xs`.
/// Note: The argument order in Nix is `elemAt list index`, not `elemAt index list`.
pub struct ElemAtBuiltin;
impl Builtin for ElemAtBuiltin {
    fn name(&self) -> &str {
        "elemAt"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("elemAt takes 2 arguments, got {}", args.len()),
            });
        }
        // In Nix, elemAt is called as: elemAt list index
        // So args[0] is the list, args[1] is the index
        match &args[0] {
            NixValue::List(list) => {
                let index = match &args[1] {
                    NixValue::Integer(i) => {
                        if *i < 0 {
                            return Err(Error::UnsupportedExpression {
                                reason: format!("elemAt: index must be non-negative, got {}", i),
                            });
                        }
                        *i as usize
                    }
                    _ => {
                        return Err(Error::UnsupportedExpression {
                            reason: format!("elemAt: second argument must be an integer, got {}", args[1]),
                        });
                    }
                };
                if index >= list.len() {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("elemAt: index {} out of bounds for list of length {}", index, list.len()),
                    });
                }
                Ok(list[index].clone())
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("elemAt: first argument must be a list, got {}", args[0]),
            }),
        }
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
                let mut names: Vec<String> = attrs.keys().cloned().collect();
                names.sort(); // Nix returns attribute names in sorted order
                let names_values: Vec<NixValue> =
                    names.into_iter().map(|k| NixValue::String(k)).collect();
                Ok(NixValue::List(names_values))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("attrNames expects an attribute set, got {}", args[0]),
            }),
        }
    }
}

/// AttrValues builtin - returns the attribute values of an attribute set as a list
pub struct AttrValuesBuiltin;
impl Builtin for AttrValuesBuiltin {
    fn name(&self) -> &str {
        "attrValues"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("attrValues takes 1 argument, got {}", args.len()),
            });
        }
        match &args[0] {
            NixValue::AttributeSet(attrs) => {
                // Get keys, sort them, then collect values in sorted key order
                let mut keys: Vec<String> = attrs.keys().cloned().collect();
                keys.sort(); // Nix returns attribute values in sorted key order
                // Note: attrValues requires evaluator context to force thunks
                // This is handled specially in evaluate_apply
                let values: Vec<NixValue> = keys.iter()
                    .map(|k| attrs.get(k).unwrap().clone())
                    .collect();
                Ok(NixValue::List(values))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("attrValues expects an attribute set, got {}", args[0]),
            }),
        }
    }
}

/// CatAttrs builtin - collects an attribute from a list of attribute sets
pub struct CatAttrsBuiltin;
impl Builtin for CatAttrsBuiltin {
    fn name(&self) -> &str {
        "catAttrs"
    }
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("catAttrs takes 2 arguments, got {}", args.len()),
            });
        }
        
        let attr_name = match &args[0] {
            NixValue::String(s) => s.clone(),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("catAttrs: first argument must be a string, got {}", args[0]),
                });
            }
        };
        
        let list = match &args[1] {
            NixValue::List(l) => l,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("catAttrs: second argument must be a list, got {}", args[1]),
                });
            }
        };
        
        // Collect the attribute from each attribute set in the list
        // Note: catAttrs requires evaluator context to force thunks, so it's handled specially
        // This implementation is a fallback and should not be called directly
        Err(Error::UnsupportedExpression {
            reason: "catAttrs requires evaluator context and must be handled specially".to_string(),
        })
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

/// BaseNameOf builtin - extracts the base name from a path or string
///
/// `builtins.baseNameOf path` returns the last component of the path.
/// For example: `baseNameOf "/foo/bar"` returns `"bar"`.
pub struct BaseNameOfBuiltin;

impl Builtin for BaseNameOfBuiltin {
    fn name(&self) -> &str {
        "baseNameOf"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("baseNameOf takes 1 argument, got {}", args.len()),
            });
        }
        
        let path_str = match &args[0] {
            NixValue::String(s) => s.clone(),
            NixValue::Path(p) => p.display().to_string(),
            NixValue::StorePath(p) => p.clone(),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("baseNameOf expects a string or path, got {}", args[0]),
                });
            }
        };
        
        // Handle empty string
        if path_str.is_empty() {
            return Ok(NixValue::String("".to_string()));
        }
        
        // Remove trailing slashes (but preserve a single leading slash for absolute paths)
        let mut cleaned = path_str.trim_end_matches('/').to_string();
        
        // Handle root path or paths that become empty after removing trailing slashes
        if cleaned == "/" || cleaned.is_empty() {
            return Ok(NixValue::String("".to_string()));
        }
        
        // Handle current directory
        if cleaned == "." {
            return Ok(NixValue::String(".".to_string()));
        }
        
        // Extract the last component
        // Split by '/' and take the last non-empty part
        let parts: Vec<&str> = cleaned.split('/').filter(|s| !s.is_empty()).collect();
        
        if parts.is_empty() {
            // This happens for paths like "///" which become empty after splitting
            Ok(NixValue::String("".to_string()))
        } else {
            Ok(NixValue::String(parts.last().unwrap().to_string()))
        }
    }
}

/// Throw builtin - throws an error with a message
///
/// `builtins.throw msg` throws an error with the given message string.
pub struct ThrowBuiltin;

impl Builtin for ThrowBuiltin {
    fn name(&self) -> &str {
        "throw"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("throw takes 1 argument, got {}", args.len()),
            });
        }
        
        let message = match &args[0] {
            NixValue::String(s) => s.clone(),
            _ => format!("{}", args[0]),
        };
        
        Err(Error::UnsupportedExpression {
            reason: message,
        })
    }
}

/// TryEval builtin - evaluates an expression and catches errors
///
/// `builtins.tryEval expr` evaluates `expr` and returns an attribute set with:
/// - `success`: boolean indicating if evaluation succeeded
/// - `value`: the evaluated value (if success) or undefined (if failure)
///
/// This requires evaluator context to evaluate the expression, so it's handled specially in evaluate_apply.
pub struct TryEvalBuiltin;

impl Builtin for TryEvalBuiltin {
    fn name(&self) -> &str {
        "tryEval"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - tryEval is handled specially in evaluate_apply
        // to receive the unevaluated expression AST
        Err(Error::UnsupportedExpression {
            reason: "tryEval requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// Map builtin - applies a function to each element of a list
///
/// `builtins.map f list` applies function `f` to each element of `list` and returns a new list.
/// This requires evaluator context to call Nix functions, so it's handled specially in evaluate_apply.
pub struct MapBuiltin;

impl Builtin for MapBuiltin {
    fn name(&self) -> &str {
        "map"
    }

    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - map is handled specially in evaluate_apply
        // to call Nix functions for each element
        Err(Error::UnsupportedExpression {
            reason: "map requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// ConcatMap builtin - maps a function over a list and concatenates the results
///
/// `builtins.concatMap f list` applies function `f` to each element of `list` and concatenates
/// all the resulting lists into a single list.
/// This requires evaluator context to call Nix functions, so it's handled specially in evaluate_apply.
pub struct ConcatMapBuiltin;

impl Builtin for ConcatMapBuiltin {
    fn name(&self) -> &str {
        "concatMap"
    }

    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - concatMap is handled specially in evaluate_apply
        // to call Nix functions for each element
        Err(Error::UnsupportedExpression {
            reason: "concatMap requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// BitOr builtin - bitwise OR operation on integers
///
/// `builtins.bitOr a b` performs bitwise OR on two integers.
pub struct BitOrBuiltin;

impl Builtin for BitOrBuiltin {
    fn name(&self) -> &str {
        "bitOr"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("bitOr takes 2 arguments, got {}", args.len()),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                Ok(NixValue::Integer(a | b))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("bitOr expects two integers, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// BitAnd builtin - bitwise AND operation on integers
///
/// `builtins.bitAnd a b` performs bitwise AND on two integers.
pub struct BitAndBuiltin;

impl Builtin for BitAndBuiltin {
    fn name(&self) -> &str {
        "bitAnd"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("bitAnd takes 2 arguments, got {}", args.len()),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                Ok(NixValue::Integer(a & b))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("bitAnd expects two integers, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// BitXor builtin - bitwise XOR operation on integers
///
/// `builtins.bitXor a b` performs bitwise XOR on two integers.
pub struct BitXorBuiltin;

impl Builtin for BitXorBuiltin {
    fn name(&self) -> &str {
        "bitXor"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("bitXor takes 2 arguments, got {}", args.len()),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                Ok(NixValue::Integer(a ^ b))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("bitXor expects two integers, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// Foldl' builtin - strict left fold over a list
///
/// `builtins.foldl' op nul list` applies the binary operator `op` to each element of `list`
/// from left to right, starting with `nul` as the initial accumulator.
/// This requires evaluator context to call Nix functions, so it's handled specially in evaluate_apply.
pub struct FoldlStrictBuiltin;

impl Builtin for FoldlStrictBuiltin {
    fn name(&self) -> &str {
        "foldl'"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - foldl' is handled specially in evaluate_apply
        // to call Nix functions for each element
        Err(Error::UnsupportedExpression {
            reason: "foldl' requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// Add builtin - adds two numbers
pub struct AddBuiltin;

impl Builtin for AddBuiltin {
    fn name(&self) -> &str {
        "add"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("add takes 2 arguments, got {}", args.len()),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                Ok(NixValue::Integer(a + b))
            }
            (NixValue::Float(a), NixValue::Float(b)) => {
                Ok(NixValue::Float(a + b))
            }
            (NixValue::Integer(a), NixValue::Float(b)) => {
                Ok(NixValue::Float(*a as f64 + b))
            }
            (NixValue::Float(a), NixValue::Integer(b)) => {
                Ok(NixValue::Float(a + *b as f64))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("add expects two numbers, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// Mul builtin - multiplies two numbers
pub struct MulBuiltin;

impl Builtin for MulBuiltin {
    fn name(&self) -> &str {
        "mul"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("mul takes 2 arguments, got {}", args.len()),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                Ok(NixValue::Integer(a * b))
            }
            (NixValue::Float(a), NixValue::Float(b)) => {
                Ok(NixValue::Float(a * b))
            }
            (NixValue::Integer(a), NixValue::Float(b)) => {
                Ok(NixValue::Float(*a as f64 * b))
            }
            (NixValue::Float(a), NixValue::Integer(b)) => {
                Ok(NixValue::Float(a * *b as f64))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("mul expects two numbers, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// Sub builtin - subtracts two numbers
pub struct SubBuiltin;

impl Builtin for SubBuiltin {
    fn name(&self) -> &str {
        "sub"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("sub takes 2 arguments, got {}", args.len()),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                Ok(NixValue::Integer(a - b))
            }
            (NixValue::Float(a), NixValue::Float(b)) => {
                Ok(NixValue::Float(a - b))
            }
            (NixValue::Integer(a), NixValue::Float(b)) => {
                Ok(NixValue::Float(*a as f64 - b))
            }
            (NixValue::Float(a), NixValue::Integer(b)) => {
                Ok(NixValue::Float(a - *b as f64))
            }
            _ => Err(Error::UnsupportedExpression {
                reason: format!("sub expects two numbers, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// Div builtin - divides two numbers
pub struct DivBuiltin;

impl Builtin for DivBuiltin {
    fn name(&self) -> &str {
        "div"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("div takes 2 arguments, got {}", args.len()),
            });
        }
        
        match (&args[0], &args[1]) {
            (NixValue::Integer(a), NixValue::Integer(b)) => {
                if *b == 0 {
                    return Err(Error::UnsupportedExpression {
                        reason: "division by zero".to_string(),
                    });
                }
                // Integer division in Nix truncates towards zero
                Ok(NixValue::Integer(a / b))
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
                reason: format!("div expects two numbers, got {} and {}", args[0], args[1]),
            }),
        }
    }
}

/// ToJSON builtin - converts a Nix value to JSON string
pub struct ToJSONBuiltin;

impl Builtin for ToJSONBuiltin {
    fn name(&self) -> &str {
        "toJSON"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("toJSON takes 1 argument, got {}", args.len()),
            });
        }
        
        // Convert NixValue to JSON string
        let json_str = match &args[0] {
            NixValue::Null => "null".to_string(),
            NixValue::Boolean(true) => "true".to_string(),
            NixValue::Boolean(false) => "false".to_string(),
            NixValue::Integer(i) => i.to_string(),
            NixValue::Float(f) => f.to_string(),
            NixValue::String(s) => {
                // Escape JSON string
                format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n").replace('\r', "\\r").replace('\t', "\\t"))
            }
            NixValue::List(l) => {
                let items: Vec<String> = l.iter().map(|v| {
                    // Recursively convert each item
                    match v {
                        NixValue::Null => "null".to_string(),
                        NixValue::Boolean(true) => "true".to_string(),
                        NixValue::Boolean(false) => "false".to_string(),
                        NixValue::Integer(i) => i.to_string(),
                        NixValue::Float(f) => f.to_string(),
                        NixValue::String(s) => format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n").replace('\r', "\\r").replace('\t', "\\t")),
                        NixValue::List(_) => {
                            // For nested lists, we'd need recursive conversion
                            // For now, return a placeholder
                            "[]".to_string()
                        }
                        NixValue::AttributeSet(_) => {
                            // For attribute sets, we'd need recursive conversion
                            // For now, return a placeholder
                            "{}".to_string()
                        }
                        _ => format!("\"{}\"", v),
                    }
                }).collect();
                format!("[{}]", items.join(","))
            }
            NixValue::AttributeSet(attrs) => {
                let pairs: Vec<String> = attrs.iter().map(|(k, v)| {
                    let key = format!("\"{}\"", k.replace('\\', "\\\\").replace('"', "\\\""));
                    let val = match v {
                        NixValue::Null => "null".to_string(),
                        NixValue::Boolean(true) => "true".to_string(),
                        NixValue::Boolean(false) => "false".to_string(),
                        NixValue::Integer(i) => i.to_string(),
                        NixValue::Float(f) => f.to_string(),
                        NixValue::String(s) => format!("\"{}\"", s.replace('\\', "\\\\").replace('"', "\\\"").replace('\n', "\\n").replace('\r', "\\r").replace('\t', "\\t")),
                        _ => format!("\"{}\"", v),
                    };
                    format!("{}:{}", key, val)
                }).collect();
                format!("{{{}}}", pairs.join(","))
            }
            _ => format!("\"{}\"", args[0]),
        };
        
        Ok(NixValue::String(json_str))
    }
}

/// Filter builtin - filters a list using a predicate function
///
/// `builtins.filter f list` returns a new list containing only elements for which `f` returns true.
/// This requires evaluator context to call Nix functions, so it's handled specially in evaluate_apply.
pub struct FilterBuiltin;

impl Builtin for FilterBuiltin {
    fn name(&self) -> &str {
        "filter"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - filter is handled specially in evaluate_apply
        // to call Nix functions for each element
        Err(Error::UnsupportedExpression {
            reason: "filter requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// All builtin - checks if all elements of a list satisfy a predicate
///
/// `builtins.all f list` returns true if `f` returns true for all elements in `list`.
/// This requires evaluator context to call Nix functions, so it's handled specially in evaluate_apply.
pub struct AllBuiltin;

impl Builtin for AllBuiltin {
    fn name(&self) -> &str {
        "all"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - all is handled specially in evaluate_apply
        // to call Nix functions for each element
        Err(Error::UnsupportedExpression {
            reason: "all requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// Any builtin - checks if any element of a list satisfies a predicate
///
/// `builtins.any f list` returns true if `f` returns true for any element in `list`.
/// This requires evaluator context to call Nix functions, so it's handled specially in evaluate_apply.
pub struct AnyBuiltin;

impl Builtin for AnyBuiltin {
    fn name(&self) -> &str {
        "any"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - any is handled specially in evaluate_apply
        // to call Nix functions for each element
        Err(Error::UnsupportedExpression {
            reason: "any requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// Sort builtin - sorts a list using a comparison function
///
/// `builtins.sort f list` sorts `list` using comparison function `f` that takes two arguments
/// and returns true if the first should come before the second.
/// This requires evaluator context to call Nix functions, so it's handled specially in evaluate_apply.
pub struct SortBuiltin;

impl Builtin for SortBuiltin {
    fn name(&self) -> &str {
        "sort"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - sort is handled specially in evaluate_apply
        // to call Nix functions for comparison
        Err(Error::UnsupportedExpression {
            reason: "sort requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// FromJSON builtin - parses a JSON string to a Nix value
pub struct FromJSONBuiltin;

impl Builtin for FromJSONBuiltin {
    fn name(&self) -> &str {
        "fromJSON"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("fromJSON takes 1 argument, got {}", args.len()),
            });
        }
        
        let json_str = match &args[0] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("fromJSON expects a string, got {}", args[0]),
                });
            }
        };
        
        // Simple JSON parsing (basic implementation)
        // For a full implementation, we'd want a proper JSON parser
        let trimmed = json_str.trim();
        
        if trimmed == "null" {
            return Ok(NixValue::Null);
        }
        if trimmed == "true" {
            return Ok(NixValue::Boolean(true));
        }
        if trimmed == "false" {
            return Ok(NixValue::Boolean(false));
        }
        
        // Try to parse as integer
        if let Ok(i) = trimmed.parse::<i64>() {
            return Ok(NixValue::Integer(i));
        }
        
        // Try to parse as float
        if let Ok(f) = trimmed.parse::<f64>() {
            return Ok(NixValue::Float(f));
        }
        
        // Try to parse as string (remove quotes)
        if trimmed.starts_with('"') && trimmed.ends_with('"') {
            let unquoted = &trimmed[1..trimmed.len()-1];
            // Unescape JSON string
            let unescaped = unquoted.replace("\\\"", "\"").replace("\\\\", "\\").replace("\\n", "\n").replace("\\r", "\r").replace("\\t", "\t");
            return Ok(NixValue::String(unescaped));
        }
        
        // Try to parse as list
        if trimmed.starts_with('[') && trimmed.ends_with(']') {
            // Simple list parsing - split by comma and parse each element
            let content = &trimmed[1..trimmed.len()-1].trim();
            if content.is_empty() {
                return Ok(NixValue::List(Vec::new()));
            }
            // This is a simplified parser - a full implementation would handle nested structures
            return Err(Error::UnsupportedExpression {
                reason: "fromJSON: complex JSON parsing not yet implemented".to_string(),
            });
        }
        
        // Try to parse as object
        if trimmed.starts_with('{') && trimmed.ends_with('}') {
            // Simple object parsing
            return Err(Error::UnsupportedExpression {
                reason: "fromJSON: object parsing not yet implemented".to_string(),
            });
        }
        
        Err(Error::UnsupportedExpression {
            reason: format!("fromJSON: cannot parse JSON: {}", json_str),
        })
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
        let _length = match &args[1] {
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
                    reason: format!(
                        "genList: second argument must be an integer, got {}",
                        args[1]
                    ),
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
                reason: format!(
                    "genList: first argument must be a function, got {}",
                    args[0]
                ),
            }),
        }
    }
}

/// PathExists builtin - checks if a path exists
pub struct PathExistsBuiltin;

impl Builtin for PathExistsBuiltin {
    fn name(&self) -> &str {
        "pathExists"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - pathExists is handled specially in evaluate_apply
        // to resolve paths relative to the current file
        Err(Error::UnsupportedExpression {
            reason: "pathExists requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// ReadFile builtin - reads a file and returns its contents as a string
pub struct ReadFileBuiltin;

impl Builtin for ReadFileBuiltin {
    fn name(&self) -> &str {
        "readFile"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - readFile is handled specially in evaluate_apply
        // to resolve paths relative to the current file
        Err(Error::UnsupportedExpression {
            reason: "readFile requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// RemoveAttrs builtin - removes attributes from an attribute set
pub struct RemoveAttrsBuiltin;

impl Builtin for RemoveAttrsBuiltin {
    fn name(&self) -> &str {
        "removeAttrs"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("removeAttrs takes 2 arguments, got {}", args.len()),
            });
        }
        
        let attrs = match &args[0] {
            NixValue::AttributeSet(a) => a,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("removeAttrs: first argument must be an attribute set, got {}", args[0]),
                });
            }
        };
        
        let keys_to_remove = match &args[1] {
            NixValue::List(l) => l,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("removeAttrs: second argument must be a list, got {}", args[1]),
                });
            }
        };
        
        // Collect keys to remove as strings
        let mut keys_set = std::collections::HashSet::new();
        for key_value in keys_to_remove {
            let key = match key_value {
                NixValue::String(s) => s.clone(),
                _ => {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("removeAttrs: list must contain strings, got {}", key_value),
                    });
                }
            };
            keys_set.insert(key);
        }
        
        // Create new attribute set without the removed keys
        let mut new_attrs = HashMap::new();
        for (key, value) in attrs {
            if !keys_set.contains(key) {
                new_attrs.insert(key.clone(), value.clone());
            }
        }
        
        Ok(NixValue::AttributeSet(new_attrs))
    }
}

/// ToPath builtin - converts a string to a path value
pub struct ToPathBuiltin;

impl Builtin for ToPathBuiltin {
    fn name(&self) -> &str {
        "toPath"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("toPath takes 1 argument, got {}", args.len()),
            });
        }
        
        match &args[0] {
            NixValue::String(path_str) => {
                // Convert string to a Path value
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
                reason: format!("toPath expects a string or path, got {}", args[0]),
            }),
        }
    }
}

/// MapAttrs builtin - maps a function over an attribute set
pub struct MapAttrsBuiltin;

impl Builtin for MapAttrsBuiltin {
    fn name(&self) -> &str {
        "mapAttrs"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - mapAttrs is handled specially in evaluate_apply
        // to call Nix functions for each attribute
        Err(Error::UnsupportedExpression {
            reason: "mapAttrs requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// ReadDir builtin - reads directory contents
pub struct ReadDirBuiltin;

impl Builtin for ReadDirBuiltin {
    fn name(&self) -> &str {
        "readDir"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - readDir is handled specially in evaluate_apply
        // to resolve paths relative to the current file
        Err(Error::UnsupportedExpression {
            reason: "readDir requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// ReadFileType builtin - returns the type of a file
pub struct ReadFileTypeBuiltin;

impl Builtin for ReadFileTypeBuiltin {
    fn name(&self) -> &str {
        "readFileType"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - readFileType is handled specially in evaluate_apply
        // to resolve paths relative to the current file
        Err(Error::UnsupportedExpression {
            reason: "readFileType requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// LessThan builtin - compares two values
pub struct LessThanBuiltin;

impl Builtin for LessThanBuiltin {
    fn name(&self) -> &str {
        "lessThan"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("lessThan takes 2 arguments, got {}", args.len()),
            });
        }
        
        let a = &args[0];
        let b = &args[1];
        
        // Compare based on type
        let result = match (a, b) {
            (NixValue::Integer(x), NixValue::Integer(y)) => x < y,
            (NixValue::Float(x), NixValue::Float(y)) => x < y,
            (NixValue::Integer(x), NixValue::Float(y)) => (*x as f64) < *y,
            (NixValue::Float(x), NixValue::Integer(y)) => *x < (*y as f64),
            (NixValue::String(x), NixValue::String(y)) => x < y,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("lessThan: cannot compare {} and {}", a, b),
                });
            }
        };
        
        Ok(NixValue::Boolean(result))
    }
}

/// ListToAttrs builtin - converts a list of attribute sets to an attribute set
pub struct ListToAttrsBuiltin;

impl Builtin for ListToAttrsBuiltin {
    fn name(&self) -> &str {
        "listToAttrs"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("listToAttrs takes 1 argument, got {}", args.len()),
            });
        }
        
        let list = match &args[0] {
            NixValue::List(l) => l,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("listToAttrs expects a list, got {}", args[0]),
                });
            }
        };
        
        let mut attrs = HashMap::new();
        
        // Process each element in the list
        for elem in list {
            // Each element should be an attribute set with "name" and "value" keys
            let elem_attrs = match elem {
                NixValue::AttributeSet(a) => a,
                _ => {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("listToAttrs: list element must be an attribute set, got {}", elem),
                    });
                }
            };
            
            // Get the "name" attribute
            let name = match elem_attrs.get("name") {
                Some(NixValue::String(s)) => s.clone(),
                _ => {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("listToAttrs: element must have a 'name' string attribute, got {:?}", elem_attrs.get("name")),
                    });
                }
            };
            
            // Get the "value" attribute
            let value = match elem_attrs.get("value") {
                Some(v) => v.clone(),
                None => {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("listToAttrs: element must have a 'value' attribute"),
                    });
                }
            };
            
            // Insert into result (first occurrence wins if duplicate names)
            attrs.entry(name).or_insert(value);
        }
        
        Ok(NixValue::AttributeSet(attrs))
    }
}

/// Partition builtin - partitions a list based on a predicate
pub struct PartitionBuiltin;

impl Builtin for PartitionBuiltin {
    fn name(&self) -> &str {
        "partition"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - partition is handled specially in evaluate_apply
        // to call the predicate function for each element
        Err(Error::UnsupportedExpression {
            reason: "partition requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// HashString builtin - hashes a string using the specified algorithm
pub struct HashStringBuiltin;

impl Builtin for HashStringBuiltin {
    fn name(&self) -> &str {
        "hashString"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("hashString takes 2 arguments, got {}", args.len()),
            });
        }
        
        let algorithm = match &args[0] {
            NixValue::String(s) => s.as_str(),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("hashString: first argument must be a string, got {}", args[0]),
                });
            }
        };
        
        let input = match &args[1] {
            NixValue::String(s) => s.as_str(),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("hashString: second argument must be a string, got {}", args[1]),
                });
            }
        };
        
        // Compute hash based on algorithm
        let hash_hex = match algorithm {
            "md5" => {
                let digest = md5::compute(input.as_bytes());
                hex::encode(digest.as_slice())
            }
            "sha1" => {
                use sha1::{Sha1, Digest};
                let mut hasher = Sha1::new();
                hasher.update(input.as_bytes());
                let hash_bytes = hasher.finalize();
                hex::encode(hash_bytes)
            }
            "sha256" => {
                use sha2::{Digest, Sha256};
                let mut hasher = Sha256::new();
                hasher.update(input.as_bytes());
                let hash_bytes = hasher.finalize();
                hex::encode(hash_bytes)
            }
            "sha512" => {
                use sha2::{Digest, Sha512};
                let mut hasher = Sha512::new();
                hasher.update(input.as_bytes());
                let hash_bytes = hasher.finalize();
                hex::encode(hash_bytes)
            }
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("hashString: unsupported algorithm '{}', supported: md5, sha1, sha256, sha512", algorithm),
                });
            }
        };
        
        Ok(NixValue::String(hash_hex))
    }
}

/// GroupBy builtin - groups elements of a list by a key function
pub struct GroupByBuiltin;

impl Builtin for GroupByBuiltin {
    fn name(&self) -> &str {
        "groupBy"
    }
    
    fn call(&self, _args: &[NixValue]) -> Result<NixValue> {
        // This should never be called directly - groupBy is handled specially in evaluate_apply
        // to call the key function for each element
        Err(Error::UnsupportedExpression {
            reason: "groupBy requires evaluator context and must be handled specially".to_string(),
        })
    }
}

/// HasContext builtin - checks if a value has a context (store path references)
pub struct HasContextBuiltin;

impl Builtin for HasContextBuiltin {
    fn name(&self) -> &str {
        "hasContext"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("hasContext takes 1 argument, got {}", args.len()),
            });
        }
        
        // Check if the value has context (store path references)
        // For now, we'll check if it's a StorePath or contains StorePath references
        // In a full implementation, we'd need to track context through string interpolation
        let has_context = match &args[0] {
            NixValue::StorePath(_) => true,
            NixValue::String(s) => {
                // Check if string contains store path references (format: /nix/store/...)
                s.contains("/nix/store/")
            }
            _ => false,
        };
        
        Ok(NixValue::Boolean(has_context))
    }
}

/// Substring builtin - extracts a substring from a string
pub struct SubstringBuiltin;

impl Builtin for SubstringBuiltin {
    fn name(&self) -> &str {
        "substring"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 3 {
            return Err(Error::UnsupportedExpression {
                reason: format!("substring takes 3 arguments, got {}", args.len()),
            });
        }
        
        let start = match &args[0] {
            NixValue::Integer(i) => *i,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("substring: first argument must be an integer, got {}", args[0]),
                });
            }
        };
        
        let len = match &args[1] {
            NixValue::Integer(i) => *i,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("substring: second argument must be an integer, got {}", args[1]),
                });
            }
        };
        
        let s = match &args[2] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("substring: third argument must be a string, got {}", args[2]),
                });
            }
        };
        
        // Handle negative length (Nix allows this)
        let actual_len = if len < 0 {
            s.len().saturating_sub(start.max(0) as usize)
        } else {
            len.max(0) as usize
        };
        
        let start_idx = start.max(0) as usize;
        
        // If start is beyond the string length, return empty string
        if start_idx >= s.len() {
            return Ok(NixValue::String(String::new()));
        }
        
        let end_idx = (start_idx + actual_len).min(s.len());
        
        Ok(NixValue::String(s[start_idx..end_idx].to_string()))
    }
}

/// ReplaceStrings builtin - replaces occurrences of strings in a string
pub struct ReplaceStringsBuiltin;

impl Builtin for ReplaceStringsBuiltin {
    fn name(&self) -> &str {
        "replaceStrings"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 3 {
            return Err(Error::UnsupportedExpression {
                reason: format!("replaceStrings takes 3 arguments, got {}", args.len()),
            });
        }
        
        let from_list = match &args[0] {
            NixValue::List(l) => l,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("replaceStrings: first argument must be a list, got {}", args[0]),
                });
            }
        };
        
        let to_list = match &args[1] {
            NixValue::List(l) => l,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("replaceStrings: second argument must be a list, got {}", args[1]),
                });
            }
        };
        
        if from_list.len() != to_list.len() {
            return Err(Error::UnsupportedExpression {
                reason: format!("replaceStrings: from and to lists must have the same length, got {} and {}", from_list.len(), to_list.len()),
            });
        }
        
        let mut s = match &args[2] {
            NixValue::String(s) => s.clone(),
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("replaceStrings: third argument must be a string, got {}", args[2]),
                });
            }
        };
        
        // Apply replacements sequentially
        // Nix's replaceStrings processes replacements in order, applying each pattern globally
        // Empty strings are handled specially: they insert replacements at boundaries
        let mut result = s.clone();
        
        for (from, to) in from_list.iter().zip(to_list.iter()) {
            let from_str = match from {
                NixValue::String(s) => s,
                _ => {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("replaceStrings: from list must contain strings, got {}", from),
                    });
                }
            };
            
            let to_str = match to {
                NixValue::String(s) => s,
                _ => {
                    return Err(Error::UnsupportedExpression {
                        reason: format!("replaceStrings: to list must contain strings, got {}", to),
                    });
                }
            };
            
            if from_str.is_empty() {
                // Empty string: insert replacement at start and end
                result = format!("{}{}{}", to_str, result, to_str);
            } else {
                // Non-empty string: replace all occurrences
                result = result.replace(from_str, to_str);
            }
        }
        
        Ok(NixValue::String(result))
    }
}

/// Split builtin - splits a string using a regular expression
pub struct SplitBuiltin;

impl Builtin for SplitBuiltin {
    fn name(&self) -> &str {
        "split"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 2 {
            return Err(Error::UnsupportedExpression {
                reason: format!("split takes 2 arguments, got {}", args.len()),
            });
        }
        
        let regex_str = match &args[0] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("split: first argument must be a string (regex), got {}", args[0]),
                });
            }
        };
        
        let s = match &args[1] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("split: second argument must be a string, got {}", args[1]),
                });
            }
        };
        
        // Use regex crate for splitting
        // Note: Nix uses POSIX extended regex, but we'll use Rust's regex crate
        // Nix's split returns a list where even indices are non-matches and odd indices are matches
        let re = match Regex::new(regex_str) {
            Ok(r) => r,
            Err(e) => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("split: invalid regex '{}': {}", regex_str, e),
                });
            }
        };
        
        // Split the string and collect matches
        // Nix's split returns a list where even indices are non-matches and odd indices are matches
        let mut result = Vec::new();
        let mut last_end = 0;
        
        for mat in re.find_iter(s) {
            // Add the part before the match
            if mat.start() > last_end {
                result.push(NixValue::String(s[last_end..mat.start()].to_string()));
            }
            // Add the match itself
            result.push(NixValue::String(mat.as_str().to_string()));
            last_end = mat.end();
        }
        
        // Add the remaining part after the last match
        if last_end < s.len() {
            result.push(NixValue::String(s[last_end..].to_string()));
        }
        
        // If no matches, return the whole string
        if result.is_empty() {
            result.push(NixValue::String(s.clone()));
        }
        
        Ok(NixValue::List(result))
    }
}

/// SplitVersion builtin - splits a version string into components
pub struct SplitVersionBuiltin;

impl Builtin for SplitVersionBuiltin {
    fn name(&self) -> &str {
        "splitVersion"
    }
    
    fn call(&self, args: &[NixValue]) -> Result<NixValue> {
        if args.len() != 1 {
            return Err(Error::UnsupportedExpression {
                reason: format!("splitVersion takes 1 argument, got {}", args.len()),
            });
        }
        
        let version = match &args[0] {
            NixValue::String(s) => s,
            _ => {
                return Err(Error::UnsupportedExpression {
                    reason: format!("splitVersion expects a string, got {}", args[0]),
                });
            }
        };
        
        // Split version string into components
        // Nix splits on non-alphanumeric characters, keeping separators as separate elements
        let mut result = Vec::new();
        let mut current = String::new();
        
        for ch in version.chars() {
            if ch.is_alphanumeric() {
                current.push(ch);
            } else {
                if !current.is_empty() {
                    result.push(NixValue::String(current.clone()));
                    current.clear();
                }
                result.push(NixValue::String(ch.to_string()));
            }
        }
        
        if !current.is_empty() {
            result.push(NixValue::String(current));
        }
        
        Ok(NixValue::List(result))
    }
}
