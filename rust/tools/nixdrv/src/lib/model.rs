//! Derivation model — shared between ATerm and JSON parsers.

use std::collections::BTreeMap;

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct DerivationOutput {
    pub path: String,
    pub hash_algo: Option<String>,
    pub hash: Option<String>,
}

#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Derivation {
    pub outputs: BTreeMap<String, DerivationOutput>,
    pub input_drvs: BTreeMap<String, Vec<String>>,
    pub input_srcs: Vec<String>,
    pub platform: String,
    pub builder: String,
    pub args: Vec<String>,
    pub env: BTreeMap<String, String>,
    pub name: Option<String>,
}

impl Derivation {
    pub fn default_out_path(&self) -> Option<&str> {
        self.outputs
            .get("out")
            .map(|o| o.path.as_str())
            .or_else(|| self.env.get("out").map(String::as_str))
    }

    pub fn name(&self) -> Option<&str> {
        self.name
            .as_deref()
            .or_else(|| self.env.get("name").map(String::as_str))
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample() -> Derivation {
        let mut outputs = BTreeMap::new();
        outputs.insert(
            "out".into(),
            DerivationOutput {
                path: "/nix/store/abc-out".into(),
                hash_algo: None,
                hash: None,
            },
        );
        let mut env = BTreeMap::new();
        env.insert("name".into(), "hello".into());
        Derivation {
            outputs,
            input_drvs: BTreeMap::new(),
            input_srcs: vec![],
            platform: "x86_64-linux".into(),
            builder: "/bin/sh".into(),
            args: vec![],
            env,
            name: None,
        }
    }

    #[test]
    fn default_out_path_and_name_from_env() {
        let drv = sample();
        assert_eq!(drv.default_out_path(), Some("/nix/store/abc-out"));
        assert_eq!(drv.name(), Some("hello"));
    }

    #[test]
    fn name_prefers_explicit_field() {
        let mut drv = sample();
        drv.name = Some("explicit".into());
        assert_eq!(drv.name(), Some("explicit"));
    }
}
