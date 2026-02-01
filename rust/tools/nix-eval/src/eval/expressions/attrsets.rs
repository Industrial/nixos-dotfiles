//! Attribute set expression evaluation

use crate::error::{Error, Result};
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::value::NixValue;
use rnix::ast::{AttrpathValue, HasEntry, Inherit, InheritFrom};
use rowan::ast::AstNode;
use std::collections::HashMap;
use std::sync::Arc;
use crate::thunk;

impl Evaluator {
        pub(crate) fn evaluate_attr_set(&self, set: &rnix::ast::AttrSet, scope: &VariableScope) -> Result<NixValue> {
        // Check if this is a recursive attribute set
        // In rnix, recursive sets are represented differently - check if rec keyword is present
        let is_recursive = set.rec_token().is_some();

        if is_recursive {
            self.evaluate_recursive_attr_set(set, scope)
        } else {
            self.evaluate_normal_attr_set(set, scope)
        }
    }



        fn evaluate_normal_attr_set(&self, set: &rnix::ast::AttrSet, scope: &VariableScope) -> Result<NixValue> {
        let mut attrs = HashMap::new();

        for entry in set.entries() {
            let entry_syntax = entry.syntax();
            
            // Check if this is an inherit statement
            if let Some(inherit_node) = Inherit::cast(entry_syntax.clone()) {
                // Handle inherit statement: inherit attr1 attr2 ...;
                // or inherit (expr) attr1 attr2 ...;
                
                // Get the inherit from expression (if any)
                let inherit_from = inherit_node.from();
                
                // Determine the scope to inherit from
                let inherit_scope = if let Some(inherit_from_node) = inherit_from {
                    // Get the expression from the InheritFrom node
                    if let Some(from_expr) = inherit_from_node.expr() {
                        // Evaluate the from expression to get an attribute set
                        let from_value = self.evaluate_expr_with_scope(&from_expr, scope)?;
                        match from_value {
                            NixValue::AttributeSet(from_attrs) => {
                                // Create a scope from the attribute set
                                let mut inherit_scope = VariableScope::new();
                                for (key, value) in from_attrs {
                                    inherit_scope.insert(key, value);
                                }
                                inherit_scope
                            }
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: "inherit from expression must be an attribute set".to_string(),
                                });
                            }
                        }
                    } else {
                        // No expression in InheritFrom - inherit from current scope
                        scope.clone()
                    }
                } else {
                    // Inherit from the current scope
                    scope.clone()
                };
                
                // Get the attributes to inherit
                for attr in inherit_node.attrs() {
                    // Get the attribute name (can be identifier or string literal)
                    // For string literals like "foo bar", we need to extract the string value
                    let key = if let Some(ident) = rnix::ast::Ident::cast(attr.syntax().clone()) {
                        ident.to_string()
                    } else {
                        // Try to get the text representation and handle string literals
                        let attr_text = attr.syntax().text().to_string();
                        // Check if it's a string literal (starts and ends with quotes)
                        if attr_text.starts_with('"') && attr_text.ends_with('"') && attr_text.len() >= 2 {
                            // String literal - strip quotes
                            attr_text[1..attr_text.len()-1].to_string()
                        } else if let Some(string) = rnix::ast::Str::cast(attr.syntax().clone()) {
                            // String expression - evaluate it to get the string value
                            let str_value = self.evaluate_string(&string, scope)?;
                            match str_value {
                                NixValue::String(s) => s,
                                _ => {
                                    return Err(Error::UnsupportedExpression {
                                        reason: "inherit: string expression must evaluate to a string".to_string(),
                                    });
                                }
                            }
                        } else {
                            // Try to evaluate as an expression (for dynamic attribute names)
                            if let Some(expr) = rnix::ast::Expr::cast(attr.syntax().clone()) {
                                let expr_value = self.evaluate_expr_with_scope(&expr, scope)?;
                                match expr_value {
                                    NixValue::String(s) => s,
                                    _ => {
                                        return Err(Error::UnsupportedExpression {
                                            reason: "inherit: expression must evaluate to a string".to_string(),
                                        });
                                    }
                                }
                            } else {
                                // Fallback: use text representation, trimming quotes if present
                                attr_text.trim_matches('"').to_string()
                            }
                        }
                    };
                    
                    // Look up the value in the inherit scope
                    if let Some(value) = inherit_scope.get(&key) {
                        attrs.insert(key, value.clone());
                    } else {
                        return Err(Error::UnsupportedExpression {
                            reason: format!("inherit: attribute '{}' not found in scope", key),
                        });
                    }
                }
            } else if let Some(attrpath_value) = AttrpathValue::cast(entry_syntax.clone()) {
                // Regular attribute assignment: key = value;
                // Handle nested attribute paths like foo.bar = "baz"
                
                let attrpath =
                    attrpath_value
                        .attrpath()
                        .ok_or_else(|| Error::UnsupportedExpression {
                            reason: "attribute entry missing attrpath".to_string(),
                        })?;

                let value_expr =
                    attrpath_value
                        .value()
                        .ok_or_else(|| Error::UnsupportedExpression {
                            reason: "attribute entry missing value".to_string(),
                        })?;

                // Collect all attributes in the path
                // Attribute names can be identifiers, string literals, or string expressions (with interpolation)
                let mut attr_names = Vec::new();
                for attr in attrpath.attrs() {
                    // Check if it's a string expression (with interpolation like "${expr}")
                    if let Some(str_node) = rnix::ast::Str::cast(attr.syntax().clone()) {
                        // Evaluate the string expression to get the key name
                        // This handles dynamic keys like "${builtins.throw "a"}"
                        match self.evaluate_string(&str_node, scope) {
                            Ok(NixValue::String(s)) => {
                                attr_names.push(s);
                            }
                            Ok(_) => {
                                // If evaluation succeeds but doesn't return a string, use text representation
                                let attr_str = attr.to_string().trim_matches('"').to_string();
                                attr_names.push(attr_str);
                            }
                            Err(e) => {
                                // If evaluation fails, propagate the error
                                // This allows tryEval to catch errors from attribute keys
                                return Err(e);
                            }
                        }
                    } else if let Some(ident) = rnix::ast::Ident::cast(attr.syntax().clone()) {
                        // Simple identifier
                        attr_names.push(ident.to_string());
                    } else {
                        // Fallback: try to get text representation
                        let attr_str = attr.to_string();
                        // Check if it's a string literal (starts and ends with quotes)
                        if attr_str.starts_with('"') && attr_str.ends_with('"') && attr_str.len() >= 2 {
                            attr_names.push(attr_str[1..attr_str.len()-1].to_string());
                        } else {
                            attr_names.push(attr_str);
                        }
                    }
                }

                if attr_names.is_empty() {
                    return Err(Error::UnsupportedExpression {
                        reason: "attribute key must be an identifier".to_string(),
                    });
                }

                // Create a thunk for lazy evaluation of attribute values
                let file_id = self.current_file_id();
                let thunk = thunk::Thunk::new(&value_expr, scope.clone(), file_id);
                let value = NixValue::Thunk(Arc::new(thunk));

                // Handle nested attribute paths: foo.bar.baz = value
                // Create nested attribute sets as needed
                if attr_names.len() == 1 {
                    // Simple case: foo = value
                    // If the key already exists and both are attribute sets, merge them
                    let key = &attr_names[0];
                    if let Some(existing) = attrs.get_mut(key) {
                        // Force both values to check if they're attribute sets
                        // In Nix, attribute set merging happens eagerly
                        let existing_forced = existing.clone().force(self)?;
                        let new_forced = value.clone().force(self)?;
                        match (existing_forced, new_forced) {
                            (NixValue::AttributeSet(mut existing_map), NixValue::AttributeSet(new_map)) => {
                                // Merge the new map into the existing map
                                for (k, v) in new_map {
                                    existing_map.insert(k.clone(), v.clone());
                                }
                                // Update the existing value with the merged map
                                *existing = NixValue::AttributeSet(existing_map);
                            }
                            _ => {
                                // Overwrite if not both attribute sets
                                *existing = value;
                            }
                        }
                    } else {
                        attrs.insert(key.clone(), value);
                    }
                } else {
                    // Nested case: foo.bar = value
                    // Build nested structure from the inside out
                    // For "a.b = 15", attr_names = ["a", "b"]
                    // We want to create { a = { b = 15 } }
                    // So we start with the value (15), then wrap it with "b", then wrap that with "a"
                    let mut nested_value = value;
                    
                    // Start from the last key and work backwards (skip the first key, we'll handle it separately)
                    // For ["a", "b"], we want to iterate over ["b"] (the last one)
                    // Then wrap it with "a" (the first one)
                    for key in attr_names.iter().rev().take(attr_names.len() - 1) {
                        let mut inner_map = HashMap::new();
                        inner_map.insert(key.clone(), nested_value);
                        nested_value = NixValue::AttributeSet(inner_map);
                    }
                    
                    // Now merge into the top-level attrs using the first key
                    let first_key = &attr_names[0];
                    if let Some(existing) = attrs.get_mut(first_key) {
                        // Merge with existing nested structure
                        let existing_forced = existing.clone().force(self)?;
                        match existing_forced {
                            NixValue::AttributeSet(mut existing_map) => {
                                if let NixValue::AttributeSet(new_map) = nested_value {
                                    // Merge the new map into the existing map
                                    for (k, v) in new_map {
                                        existing_map.insert(k.clone(), v.clone());
                                    }
                                    *existing = NixValue::AttributeSet(existing_map);
                                } else {
                                    // Overwrite if not an attribute set
                                    *existing = nested_value;
                                }
                            }
                            _ => {
                                // Overwrite if not an attribute set
                                *existing = nested_value;
                            }
                        }
                    } else {
                        // Insert new nested structure
                        attrs.insert(first_key.clone(), nested_value);
                    }
                }
            } else {
                return Err(Error::UnsupportedExpression {
                    reason: format!("unsupported attribute set entry: {:?}", entry_syntax.kind()),
                });
            }
        }

        Ok(NixValue::AttributeSet(attrs))
    }

    /// Evaluate a recursive attribute set
    ///
    /// Recursive attribute sets like `rec { x = y; y = 1; }` allow forward references.
    /// The key is to create a scope that includes all attribute names (as thunks) before
    /// evaluating any values, so that each value can reference other attributes.
    ///
    /// Implementation strategy:
    /// 1. First pass: Collect all attribute names and expressions
    /// 2. Create a recursive scope that will contain all attribute thunks
    /// 3. Second pass: Create thunks for each attribute, where each thunk's closure
    ///    includes the recursive scope. As we add thunks to the scope, subsequent


        fn evaluate_recursive_attr_set(&self, set: &rnix::ast::AttrSet, scope: &VariableScope) -> Result<NixValue> {
        // First pass: Collect all attribute names and expressions
        let mut attr_entries = Vec::new();
        let mut inherit_attrs = HashMap::new();

        for entry in set.entries() {
            let entry_syntax = entry.syntax();
            
            // Check if this is an inherit statement
            if let Some(inherit_node) = Inherit::cast(entry_syntax.clone()) {
                // Handle inherit in recursive sets
                let inherit_from = inherit_node.from();
                let inherit_scope = if let Some(inherit_from_node) = inherit_from {
                    if let Some(from_expr) = inherit_from_node.expr() {
                        let from_value = self.evaluate_expr_with_scope(&from_expr, scope)?;
                        match from_value {
                            NixValue::AttributeSet(from_attrs) => {
                                let mut inherit_scope = VariableScope::new();
                                for (key, value) in from_attrs {
                                    inherit_scope.insert(key, value);
                                }
                                inherit_scope
                            }
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: "inherit from expression must be an attribute set".to_string(),
                                });
                            }
                        }
                    } else {
                        scope.clone()
                    }
                } else {
                    scope.clone()
                };
                
                // Collect inherited attributes
                for attr in inherit_node.attrs() {
                    let key = if let Some(ident) = rnix::ast::Ident::cast(attr.syntax().clone()) {
                        ident.to_string()
                    } else if let Some(string) = rnix::ast::Str::cast(attr.syntax().clone()) {
                        let str_value = self.evaluate_string(&string, scope)?;
                        match str_value {
                            NixValue::String(s) => s,
                            _ => {
                                return Err(Error::UnsupportedExpression {
                                    reason: "inherit: string expression must evaluate to a string".to_string(),
                                });
                            }
                        }
                    } else {
                        if let Some(expr) = rnix::ast::Expr::cast(attr.syntax().clone()) {
                            let expr_value = self.evaluate_expr_with_scope(&expr, scope)?;
                            match expr_value {
                                NixValue::String(s) => s,
                                _ => {
                                    return Err(Error::UnsupportedExpression {
                                        reason: "inherit: expression must evaluate to a string".to_string(),
                                    });
                                }
                            }
                        } else {
                            attr.syntax().text().to_string().trim_matches('"').to_string()
                        }
                    };
                    
                    if let Some(value) = inherit_scope.get(&key) {
                        inherit_attrs.insert(key.clone(), value.clone());
                    } else {
                        return Err(Error::UnsupportedExpression {
                            reason: format!("inherit: attribute '{}' not found in scope", key),
                        });
                    }
                }
            } else if let Some(attrpath_value) = AttrpathValue::cast(entry_syntax.clone()) {
                // Regular attribute assignment
                let attrpath =
                    attrpath_value
                        .attrpath()
                        .ok_or_else(|| Error::UnsupportedExpression {
                            reason: "attribute entry missing attrpath".to_string(),
                        })?;

                let key = attrpath
                    .attrs()
                    .next()
                    .map(|attr| attr.to_string())
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "attribute key must be an identifier".to_string(),
                    })?;

                let value_expr =
                    attrpath_value
                        .value()
                        .ok_or_else(|| Error::UnsupportedExpression {
                            reason: "attribute entry missing value".to_string(),
                        })?;

                // Store the entry for later evaluation
                attr_entries.push((key, value_expr));
            }
        }

        // For recursive sets, all attributes must be in scope when evaluating any attribute.
        // Since thunks capture their closure at creation time, we need to create all thunks
        // with a scope that includes all attribute names.
        //
        // Strategy: Create all thunks first, then build a scope containing all thunks.
        // However, thunks are immutable once created, so we can't update their closures.
        //
        // Workaround: Create thunks with a scope that includes all attribute names as
        // placeholders (Null), then when a thunk is forced and looks up an attribute,
        // it will find Null. But that's not correct either.
        //
        // The correct solution requires thunks to support dynamic scope lookup or
        // a shared mutable scope. For now, we'll use a sequential approach that supports
        // forward references (later attributes can reference earlier ones).
        //
        // To support full mutual references, we'd need to modify the thunk implementation
        // to support a "recursive scope" that can be updated after thunk creation.
        let mut rec_scope = self.scope.clone();
        let mut attrs = HashMap::new();

        // Add inherited attributes to the recursive scope first
        for (key, value) in &inherit_attrs {
            rec_scope.insert(key.clone(), value.clone());
            attrs.insert(key.clone(), value.clone());
        }
        
        // Create thunks sequentially, where each thunk's closure includes previous thunks
        // This supports forward references: `rec { y = 1; x = y; }` works
        // But backward references like `rec { x = y; y = 1; }` won't work with this approach
        let file_id = self.current_file_id();
        for (key, value_expr) in &attr_entries {
            // Create thunk with current scope (includes outer scope + previous attributes + inherited)
            let thunk = thunk::Thunk::new(value_expr, rec_scope.clone(), file_id);
            let thunk_arc = Arc::new(thunk);

            // Add to both attribute set and scope for next iteration
            attrs.insert(key.clone(), NixValue::Thunk(thunk_arc.clone()));
            rec_scope.insert(key.clone(), NixValue::Thunk(thunk_arc));
        }

        Ok(NixValue::AttributeSet(attrs))
    }

}
