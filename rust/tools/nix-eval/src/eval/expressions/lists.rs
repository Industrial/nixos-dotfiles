//! List expression evaluation

use crate::error::Result;
use crate::eval::Evaluator;
use crate::eval::context::VariableScope;
use crate::thunk;
use crate::value::NixValue;
use rnix::ast::List;
use std::sync::Arc;

impl Evaluator {
    pub(crate) fn evaluate_list(
        &self,
        list: &rnix::ast::List,
        scope: &VariableScope,
    ) -> Result<NixValue> {
        let mut values = Vec::new();

        // In Nix, list elements are lazy (thunks) - they're only evaluated when accessed
        // This allows tryEval to catch errors from list elements
        for item in list.items() {
            let file_id = self.current_file_id();
            let thunk = thunk::Thunk::new(&item, scope.clone(), file_id);
            values.push(NixValue::Thunk(Arc::new(thunk)));
        }

        Ok(NixValue::List(values))
    }
}
