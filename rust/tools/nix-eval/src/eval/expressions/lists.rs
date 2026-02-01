//! List expression evaluation

use crate::error::Result;
use crate::eval::Evaluator;
use crate::value::NixValue;
use rnix::ast::List;

impl Evaluator {
        pub(crate) fn evaluate_list(&self, list: &rnix::ast::List) -> Result<NixValue> {
        let mut values = Vec::new();

        for item in list.items() {
            let value = self.evaluate_expr(&item)?;
            values.push(value);
        }

        Ok(NixValue::List(values))
    }



}
