//! Evaluation context and scope management

use crate::value::NixValue;
use codespan::FileId;
use std::collections::HashMap;

/// Represents a variable scope for name resolution
///
/// A scope maps variable names to their values. Scopes can be nested,
/// with inner scopes shadowing outer scopes.
pub type VariableScope = HashMap<String, NixValue>;

/// Evaluation context for tracking file and scope information
///
/// This struct stores the context needed for evaluation, including
/// the file ID (for source tracking) and the variable scope.
#[derive(Debug, Clone)]
pub struct EvaluationContext {
    /// File ID in the source map (None for expressions without a file)
    pub file_id: Option<FileId>,
    /// Variable scope for this context
    pub scope: VariableScope,
}
