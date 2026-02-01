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
            // Entry is an AttrpathValue - cast from the entry's syntax node
            let entry_syntax = entry.syntax();
            let attrpath_value = AttrpathValue::cast(entry_syntax.clone()).ok_or_else(|| {
                Error::UnsupportedExpression {
                    reason: "cannot cast entry to AttrpathValue".to_string(),
                }
            })?;

            // Get the first identifier from the attrpath as the key
            let attrpath =
                attrpath_value
                    .attrpath()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "attribute entry missing attrpath".to_string(),
                    })?;

            // Get the key from the first attribute in the attrpath
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

            // Create a thunk for lazy evaluation of attribute values
            // This is the key to lazy evaluation: attribute values are not evaluated
            // until they are actually accessed.
            let file_id = self.current_file_id();
            let thunk = thunk::Thunk::new(&value_expr, self.scope.clone(), file_id);
            attrs.insert(key, NixValue::Thunk(Arc::new(thunk)));
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

        for entry in set.entries() {
            // Entry is an AttrpathValue - cast from the entry's syntax node
            let entry_syntax = entry.syntax();
            let attrpath_value = AttrpathValue::cast(entry_syntax.clone()).ok_or_else(|| {
                Error::UnsupportedExpression {
                    reason: "cannot cast entry to AttrpathValue".to_string(),
                }
            })?;

            // Get the first identifier from the attrpath as the key
            let attrpath =
                attrpath_value
                    .attrpath()
                    .ok_or_else(|| Error::UnsupportedExpression {
                        reason: "attribute entry missing attrpath".to_string(),
                    })?;

            // Get the key from the first attribute in the attrpath
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

        // Create thunks sequentially, where each thunk's closure includes previous thunks
        // This supports forward references: `rec { y = 1; x = y; }` works
        // But backward references like `rec { x = y; y = 1; }` won't work with this approach
        let file_id = self.current_file_id();
        for (key, value_expr) in &attr_entries {
            // Create thunk with current scope (includes outer scope + previous attributes)
            let thunk = thunk::Thunk::new(value_expr, rec_scope.clone(), file_id);
            let thunk_arc = Arc::new(thunk);

            // Add to both attribute set and scope for next iteration
            attrs.insert(key.clone(), NixValue::Thunk(thunk_arc.clone()));
            rec_scope.insert(key.clone(), NixValue::Thunk(thunk_arc));
        }

        Ok(NixValue::AttributeSet(attrs))
    }

}
