//! Path-info model and hash formatting (Nix path-info JSON v1 shape).

use base64::Engine;
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value, json};

use crate::error::InfraError;

/// Options controlling which fields a query computes.
#[derive(Debug, Clone, Copy, Default, PartialEq, Eq)]
pub struct QueryOpts {
    pub include_referrers: bool,
    pub include_closure_size: bool,
}

/// Store path metadata from `ValidPaths` (+ joins).
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct PathInfo {
    pub path: String,
    pub nar_hash: String,
    pub nar_size: u64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub deriver: Option<String>,
    pub registration_time: i64,
    pub ultimate: bool,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub signatures: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub ca: Option<String>,
    pub references: Vec<String>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub referrers: Option<Vec<String>>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub closure_size: Option<u64>,
}

impl PathInfo {
    /// Serialize to Nix path-info `--json` v1-shaped object (field names match Nix).
    pub fn to_json_value(&self) -> Value {
        let mut m = Map::new();
        m.insert("narHash".into(), json!(self.nar_hash));
        m.insert("narSize".into(), json!(self.nar_size));
        m.insert("references".into(), json!(self.references));
        m.insert("registrationTime".into(), json!(self.registration_time));
        m.insert("ultimate".into(), json!(self.ultimate));
        if let Some(d) = &self.deriver {
            m.insert("deriver".into(), json!(d));
        } else {
            m.insert("deriver".into(), Value::Null);
        }
        if !self.signatures.is_empty() {
            m.insert("signatures".into(), json!(self.signatures));
        }
        if let Some(ca) = &self.ca {
            m.insert("ca".into(), json!(ca));
        }
        if let Some(r) = &self.referrers {
            m.insert("referrers".into(), json!(r));
        }
        if let Some(c) = self.closure_size {
            m.insert("closureSize".into(), json!(c));
        }
        Value::Object(m)
    }
}

/// Convert `ValidPaths.hash` (`algo:hex`) to SRI (`algo-base64`).
pub fn db_hash_to_sri(db_hash: &str) -> Result<String, InfraError> {
    let (algo, hex_part) = match db_hash.split_once(':') {
        Some((a, h)) => (a, h),
        None => ("sha256", db_hash),
    };
    let bytes = hex::decode(hex_part).map_err(|e| InfraError::InvalidHash(format!("{db_hash}: {e}")))?;
    if bytes.is_empty() {
        return Err(InfraError::InvalidHash(db_hash.into()));
    }
    Ok(format!(
        "{algo}-{}",
        base64::engine::general_purpose::STANDARD.encode(bytes)
    ))
}

/// Human-readable byte size (nix `-h` style).
pub fn human_bytes(n: u64) -> String {
    const UNITS: [&str; 5] = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut v = n as f64;
    let mut i = 0;
    while v >= 1024.0 && i + 1 < UNITS.len() {
        v /= 1024.0;
        i += 1;
    }
    if i == 0 {
        format!("{n}{}", UNITS[i])
    } else {
        format!("{v:.2}{}", UNITS[i])
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn sri_from_hex() {
        let hex = "00".repeat(32);
        let sri = db_hash_to_sri(&format!("sha256:{hex}")).unwrap();
        assert!(sri.starts_with("sha256-"));
        assert_eq!(sri.len(), "sha256-".len() + 44);
    }

    #[test]
    fn human_bytes_scales() {
        assert_eq!(human_bytes(500), "500B");
        assert!(human_bytes(2048).contains("KiB"));
    }

    #[test]
    fn to_json_includes_core_fields() {
        let info = PathInfo {
            path: "/nix/store/x-a".into(),
            nar_hash: "sha256-AAAA".into(),
            nar_size: 10,
            deriver: None,
            registration_time: 1,
            ultimate: false,
            signatures: vec![],
            ca: None,
            references: vec!["/nix/store/y-b".into()],
            referrers: None,
            closure_size: Some(30),
        };
        let v = info.to_json_value();
        assert_eq!(v["narSize"], 10);
        assert_eq!(v["closureSize"], 30);
        assert!(v["deriver"].is_null());
    }
}
