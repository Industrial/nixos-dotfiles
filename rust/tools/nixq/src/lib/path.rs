//! Attrpath parse and get over JSON values.

use serde_json::Value;

use crate::error::PathError;

/// One segment of an attrpath.
#[derive(Debug, Clone, PartialEq, Eq)]
pub enum PathSegment {
    Key(String),
    Index(usize),
}

/// Parsed attrpath (ordered segments).
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct AttrPath {
    pub segments: Vec<PathSegment>,
}

impl AttrPath {
    pub fn display(&self) -> String {
        let mut out = String::from("$");
        for seg in &self.segments {
            match seg {
                PathSegment::Key(k)
                    if k.chars().all(|ch| ch.is_ascii_alphanumeric() || ch == '_') =>
                {
                    out.push('.');
                    out.push_str(k);
                }
                PathSegment::Key(k) => {
                    let escaped = k.replace('\\', "\\\\").replace('"', "\\\"");
                    out.push_str(&["[\"", &escaped, "\"]"].concat());
                }
                PathSegment::Index(i) => {
                    out.push('[');
                    out.push_str(&i.to_string());
                    out.push(']');
                }
            }
        }
        out
    }
}

/// Parse attrpath: optional leading `$`, then `.key`, `["escaped"]`, `[index]`.
pub fn parse_attrpath(input: &str) -> Result<AttrPath, PathError> {
    let s = input.trim();
    let s = s.strip_prefix('$').unwrap_or(s);
    if s.is_empty() {
        return Ok(AttrPath { segments: vec![] });
    }

    let mut segments = Vec::new();
    let mut i = 0;
    let bytes = s.as_bytes();

    while i < bytes.len() {
        match bytes[i] {
            b'.' => {
                i += 1;
                let start = i;
                while i < bytes.len() && (bytes[i].is_ascii_alphanumeric() || bytes[i] == b'_') {
                    i += 1;
                }
                if start == i {
                    return Err(PathError::Invalid(format!(
                        "empty key after '.' in {input:?}"
                    )));
                }
                segments.push(PathSegment::Key(s[start..i].to_string()));
            }
            b'[' => {
                i += 1;
                if i < bytes.len() && bytes[i] == b'"' {
                    i += 1;
                    let mut key = String::new();
                    while i < bytes.len() {
                        match bytes[i] {
                            b'\\' if i + 1 < bytes.len() => {
                                key.push(bytes[i + 1] as char);
                                i += 2;
                            }
                            b'"' => {
                                i += 1;
                                break;
                            }
                            c => {
                                key.push(c as char);
                                i += 1;
                            }
                        }
                    }
                    if i >= bytes.len() || bytes[i] != b']' {
                        return Err(PathError::Invalid(format!(
                            "unclosed string key in {input:?}"
                        )));
                    }
                    i += 1;
                    segments.push(PathSegment::Key(key));
                } else {
                    let start = i;
                    while i < bytes.len() && bytes[i].is_ascii_digit() {
                        i += 1;
                    }
                    if start == i {
                        return Err(PathError::Invalid(format!(
                            "expected index or string key in {input:?}"
                        )));
                    }
                    if i >= bytes.len() || bytes[i] != b']' {
                        return Err(PathError::Invalid(format!("unclosed index in {input:?}")));
                    }
                    let idx: usize = s[start..i]
                        .parse()
                        .map_err(|_| PathError::Invalid(format!("bad index in {input:?}")))?;
                    i += 1;
                    segments.push(PathSegment::Index(idx));
                }
            }
            // bare leading key without leading '.'
            c if c.is_ascii_alphanumeric() || c == b'_' => {
                let start = i;
                while i < bytes.len() && (bytes[i].is_ascii_alphanumeric() || bytes[i] == b'_') {
                    i += 1;
                }
                segments.push(PathSegment::Key(s[start..i].to_string()));
            }
            _ => {
                return Err(PathError::Invalid(format!(
                    "unexpected char at {i} in {input:?}"
                )));
            }
        }
    }

    Ok(AttrPath { segments })
}

/// Walk `value` along `path`; `None` if any segment missing / OOB / wrong type.
pub fn get_at_path<'a>(value: &'a Value, path: &AttrPath) -> Option<&'a Value> {
    let mut cur = value;
    for seg in &path.segments {
        cur = match (cur, seg) {
            (Value::Object(map), PathSegment::Key(k)) => map.get(k)?,
            (Value::Array(items), PathSegment::Index(i)) => items.get(*i)?,
            _ => return None,
        };
    }
    Some(cur)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn parse_dot_and_index() {
        let p = parse_attrpath("$.a.b[0]").unwrap();
        assert_eq!(
            p.segments,
            vec![
                PathSegment::Key("a".into()),
                PathSegment::Key("b".into()),
                PathSegment::Index(0),
            ]
        );
    }

    #[test]
    fn parse_bare_and_escaped() {
        let p = parse_attrpath("a[\"x.y\"]").unwrap();
        assert_eq!(
            p.segments,
            vec![PathSegment::Key("a".into()), PathSegment::Key("x.y".into())]
        );
    }

    #[test]
    fn parse_root_empty() {
        assert!(parse_attrpath("$").unwrap().segments.is_empty());
        assert!(parse_attrpath("").unwrap().segments.is_empty());
    }

    #[test]
    fn get_nested() {
        let v = json!({"a": {"b": [10, 20]}});
        let p = parse_attrpath("a.b[1]").unwrap();
        assert_eq!(get_at_path(&v, &p), Some(&json!(20)));
    }

    #[test]
    fn get_missing_is_none() {
        let v = json!({"a": 1});
        let p = parse_attrpath("a.b").unwrap();
        assert!(get_at_path(&v, &p).is_none());
    }

    #[test]
    fn parse_invalid() {
        assert!(parse_attrpath(".").is_err());
        assert!(parse_attrpath("a[").is_err());
        assert!(parse_attrpath("a[abc]").is_err());
    }

    #[test]
    fn display_roundtrip_style() {
        let p = parse_attrpath("$.foo[0]").unwrap();
        assert_eq!(p.display(), "$.foo[0]");
        let escaped = AttrPath {
            segments: vec![PathSegment::Key("a\"b\\c".into())],
        };
        assert!(escaped.display().contains("[\""));
    }

    #[test]
    fn parse_more_invalid_and_get_type_mismatch() {
        assert!(parse_attrpath("a[\"unterminated").is_err());
        assert!(parse_attrpath("a[!").is_err());
        assert!(parse_attrpath("#").is_err());
        assert!(parse_attrpath("a[]").is_err());
        let v = json!({"a": 1});
        assert!(get_at_path(&v, &parse_attrpath("a[0]").unwrap()).is_none());
        let arr = json!([{"k": 1}]);
        assert!(get_at_path(&arr, &parse_attrpath("$[0].k").unwrap()).is_some());
        assert!(get_at_path(&arr, &parse_attrpath("$[5]").unwrap()).is_none());
        let p2 = parse_attrpath(r#"a["with space"]"#).unwrap();
        assert_eq!(
            p2.segments,
            vec![
                PathSegment::Key("a".into()),
                PathSegment::Key("with space".into())
            ]
        );
    }
}
