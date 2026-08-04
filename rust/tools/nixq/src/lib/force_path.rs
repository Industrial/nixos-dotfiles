//! Force-path: require attrpaths resolve on a JSON value.

use serde_json::Value;

use crate::error::PathError;
use crate::path::{get_at_path, parse_attrpath};

/// Succeed when every path string resolves on `value`.
pub fn force_paths(value: &Value, paths: &[String]) -> Result<(), PathError> {
    for raw in paths {
        let path = parse_attrpath(raw)?;
        if get_at_path(value, &path).is_none() {
            return Err(PathError::NotFound(path.display()));
        }
    }
    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn force_paths_ok() {
        let v = json!({"a": {"b": 1}});
        assert!(force_paths(&v, &["a.b".into()]).is_ok());
    }

    #[test]
    fn force_paths_missing() {
        let v = json!({"a": 1});
        let err = force_paths(&v, &["a.b".into()]).unwrap_err();
        assert!(matches!(err, PathError::NotFound(_)));
    }

    #[test]
    fn force_paths_empty_ok() {
        assert!(force_paths(&json!(null), &[]).is_ok());
    }

    #[test]
    fn force_paths_oob_index() {
        let v = json!([1]);
        assert!(force_paths(&v, &["$[1]".into()]).is_err());
    }

    #[test]
    fn force_paths_invalid_attrpath() {
        let err = force_paths(&json!({}), &[".".into()]).unwrap_err();
        assert!(matches!(err, PathError::Invalid(_)));
    }
}
