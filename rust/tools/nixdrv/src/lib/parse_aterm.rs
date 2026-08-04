//! Classic Nix derivation ATerm parser.

use std::collections::BTreeMap;

use crate::error::ParseError;
use crate::model::{Derivation, DerivationOutput};

/// Parse a `.drv` ATerm blob into a [`Derivation`].
pub fn parse_drv_aterm(bytes: &[u8]) -> Result<Derivation, ParseError> {
    let mut p = Parser::new(bytes);
    p.parse_derivation()
}

struct Parser<'a> {
    input: &'a [u8],
    pos: usize,
}

impl<'a> Parser<'a> {
    fn new(input: &'a [u8]) -> Self {
        Self { input, pos: 0 }
    }

    fn eof_err(&self) -> ParseError {
        ParseError::Eof { offset: self.pos }
    }

    fn peek(&self) -> Option<u8> {
        self.input.get(self.pos).copied()
    }

    fn bump(&mut self) -> Option<u8> {
        let ch = self.peek()?;
        self.pos += 1;
        Some(ch)
    }

    fn skip_ws(&mut self) {
        while matches!(self.peek(), Some(b' ' | b'\n' | b'\r' | b'\t')) {
            self.bump();
        }
    }

    fn expect_byte(&mut self, expected: u8) -> Result<(), ParseError> {
        self.skip_ws();
        match self.bump() {
            Some(b) if b == expected => Ok(()),
            Some(b) => Err(ParseError::Unexpected {
                offset: self.pos - 1,
                message: format!("expected {:?}, got {:?}", expected as char, b as char),
            }),
            None => Err(self.eof_err()),
        }
    }

    fn expect_ident(&mut self, ident: &str) -> Result<(), ParseError> {
        self.skip_ws();
        let start = self.pos;
        for &b in ident.as_bytes() {
            match self.bump() {
                Some(c) if c == b => {}
                _ => {
                    return Err(ParseError::Unexpected {
                        offset: start,
                        message: format!("expected {ident}"),
                    });
                }
            }
        }
        Ok(())
    }

    fn parse_derivation(&mut self) -> Result<Derivation, ParseError> {
        self.expect_ident("Derive")?;
        self.expect_byte(b'(')?;
        let outputs = self.parse_outputs()?;
        self.expect_byte(b',')?;
        let input_drvs = self.parse_input_drvs()?;
        self.expect_byte(b',')?;
        let input_srcs = self.parse_string_list()?;
        self.expect_byte(b',')?;
        let platform = self.parse_string()?;
        self.expect_byte(b',')?;
        let builder = self.parse_string()?;
        self.expect_byte(b',')?;
        let args = self.parse_string_list()?;
        self.expect_byte(b',')?;
        let env = self.parse_env_list()?;
        self.expect_byte(b')')?;
        self.skip_ws();
        let name = env.get("name").cloned();
        Ok(Derivation {
            outputs,
            input_drvs,
            input_srcs,
            platform,
            builder,
            args,
            env,
            name,
        })
    }

    fn parse_outputs(&mut self) -> Result<BTreeMap<String, DerivationOutput>, ParseError> {
        self.expect_byte(b'[')?;
        let mut map = BTreeMap::new();
        self.skip_ws();
        if self.peek() == Some(b']') {
            self.bump();
            return Ok(map);
        }
        loop {
            self.expect_byte(b'(')?;
            let key = self.parse_string()?;
            self.expect_byte(b',')?;
            let path = self.parse_string()?;
            self.expect_byte(b',')?;
            let hash_algo = self.parse_optional_string()?;
            self.expect_byte(b',')?;
            let hash = self.parse_optional_string()?;
            self.expect_byte(b')')?;
            map.insert(
                key,
                DerivationOutput {
                    path,
                    hash_algo: nonempty(hash_algo),
                    hash: nonempty(hash),
                },
            );
            self.skip_ws();
            match self.peek() {
                Some(b',') => {
                    self.bump();
                }
                Some(b']') => {
                    self.bump();
                    break;
                }
                _ => return Err(self.eof_err()),
            }
        }
        Ok(map)
    }

    fn parse_input_drvs(&mut self) -> Result<BTreeMap<String, Vec<String>>, ParseError> {
        self.expect_byte(b'[')?;
        let mut map = BTreeMap::new();
        self.skip_ws();
        if self.peek() == Some(b']') {
            self.bump();
            return Ok(map);
        }
        loop {
            self.expect_byte(b'(')?;
            let path = self.parse_string()?;
            self.expect_byte(b',')?;
            let outs = self.parse_string_list()?;
            self.expect_byte(b')')?;
            map.insert(path, outs);
            self.skip_ws();
            match self.peek() {
                Some(b',') => {
                    self.bump();
                }
                Some(b']') => {
                    self.bump();
                    break;
                }
                _ => return Err(self.eof_err()),
            }
        }
        Ok(map)
    }

    fn parse_string_list(&mut self) -> Result<Vec<String>, ParseError> {
        self.expect_byte(b'[')?;
        let mut items = Vec::new();
        self.skip_ws();
        if self.peek() == Some(b']') {
            self.bump();
            return Ok(items);
        }
        loop {
            items.push(self.parse_string()?);
            self.skip_ws();
            match self.peek() {
                Some(b',') => {
                    self.bump();
                }
                Some(b']') => {
                    self.bump();
                    break;
                }
                _ => return Err(self.eof_err()),
            }
        }
        Ok(items)
    }

    fn parse_env_list(&mut self) -> Result<BTreeMap<String, String>, ParseError> {
        self.expect_byte(b'[')?;
        let mut map = BTreeMap::new();
        self.skip_ws();
        if self.peek() == Some(b']') {
            self.bump();
            return Ok(map);
        }
        loop {
            self.expect_byte(b'(')?;
            let key = self.parse_string()?;
            self.expect_byte(b',')?;
            let val = self.parse_string()?;
            self.expect_byte(b')')?;
            map.insert(key, val);
            self.skip_ws();
            match self.peek() {
                Some(b',') => {
                    self.bump();
                }
                Some(b']') => {
                    self.bump();
                    break;
                }
                _ => return Err(self.eof_err()),
            }
        }
        Ok(map)
    }

    fn parse_optional_string(&mut self) -> Result<String, ParseError> {
        self.skip_ws();
        if self.peek() == Some(b'"') {
            return self.parse_string();
        }
        Ok(String::new())
    }

    fn parse_string(&mut self) -> Result<String, ParseError> {
        self.skip_ws();
        self.expect_byte(b'"')?;
        let mut out = String::new();
        loop {
            match self.bump() {
                None => return Err(self.eof_err()),
                Some(b'"') => return Ok(out),
                Some(b'\\') => match self.bump() {
                    Some(b'"') => out.push('"'),
                    Some(b'\\') => out.push('\\'),
                    Some(b'n') => out.push('\n'),
                    Some(b't') => out.push('\t'),
                    Some(c) => {
                        out.push('\\');
                        out.push(c as char);
                    }
                    None => return Err(self.eof_err()),
                },
                Some(c) => out.push(c as char),
            }
        }
    }
}

fn nonempty(s: String) -> Option<String> {
    if s.is_empty() { None } else { Some(s) }
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;
    use std::path::PathBuf;

    fn fixture_path(name: &str) -> PathBuf {
        PathBuf::from(env!("CARGO_MANIFEST_DIR"))
            .join("fixtures")
            .join(name)
    }

    #[test]
    fn parses_simple_fixture() {
        let bytes = fs::read_to_string(fixture_path("simple.drv")).unwrap();
        let drv = parse_drv_aterm(bytes.as_bytes()).unwrap();
        assert_eq!(drv.name(), Some("simple-1.0"));
        assert_eq!(
            drv.default_out_path(),
            Some("/nix/store/aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-simple-1.0")
        );
        assert_eq!(drv.platform, "x86_64-linux");
        assert_eq!(drv.builder, "/bin/sh");
        assert_eq!(drv.input_srcs.len(), 1);
        assert_eq!(drv.input_drvs.len(), 1);
    }

    #[test]
    fn parses_escaped_quotes() {
        let input = br#"Derive([("out","/nix/store/x","","")],[],[],"x86_64-linux","/bin/sh",["say \"hi\""],[("name","pkg")])"#;
        let drv = parse_drv_aterm(input).unwrap();
        assert_eq!(drv.args, vec!["say \"hi\"".to_string()]);
    }

    #[test]
    fn rejects_missing_derive_prefix() {
        let err = parse_drv_aterm(b"NotDerive()").unwrap_err();
        assert!(matches!(err, ParseError::Unexpected { .. }));
    }

    #[test]
    fn rejects_truncated_input() {
        let err = parse_drv_aterm(b"Derive([").unwrap_err();
        assert!(matches!(
            err,
            ParseError::Eof { .. } | ParseError::Unexpected { .. }
        ));
    }

    #[test]
    fn synthetic_minimal() {
        let s = concat!(
            "Derive([",
            "(\"out\",\"/nix/store/out\",\"\",\"\")",
            "],[],[],",
            "\"aarch64-linux\",\"/bin/sh\",[],",
            "[(\"name\",\"n\")])"
        );
        let drv = parse_drv_aterm(s.as_bytes()).unwrap();
        assert_eq!(drv.platform, "aarch64-linux");
        assert_eq!(drv.name(), Some("n"));
    }
}
