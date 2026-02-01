//! Derivation (build plan) representation

use crate::error::Result;
use std::collections::HashMap;
use std::path::PathBuf;

/// Represents a Nix derivation (build plan)
#[derive(Debug, Clone)]
pub struct Derivation {
    /// Name of the derivation
    pub name: String,
    /// System (e.g., "x86_64-linux")
    pub system: String,
    /// Builder executable path
    pub builder: String,
    /// Builder arguments
    pub args: Vec<String>,
    /// Environment variables
    pub env: HashMap<String, String>,
    /// Input derivations (dependencies)
    pub input_derivations: HashMap<String, Vec<String>>,
    /// Input sources (file dependencies)
    pub input_sources: Vec<String>,
    /// Output paths (where the build results will be stored)
    pub outputs: HashMap<String, String>,
}

impl Derivation {
    /// Serialize the derivation to ATerm format
    ///
    /// The ATerm format for a derivation is:
    /// Derive(
    ///   [outputs],           # list of output specifications
    ///   [input-derivations], # list of input derivations
    ///   [input-sources],     # list of input source paths
    ///   system,              # system string
    ///   builder,             # builder path
    ///   [args],              # builder arguments
    ///   env                  # environment variables as attribute set
    /// )
    pub fn to_aterm(&self) -> String {
        use std::fmt::Write;

        let mut result = String::from("Derive([");

        // Outputs: list of tuples (name, path, hash-algo, hash)
        // For now, we'll use "out" as the default output if none specified
        if self.outputs.is_empty() {
            // Default output "out"
            write!(result, "(\"out\",\"\",\"\",\"\")").unwrap();
        } else {
            let output_parts: Vec<String> = self
                .outputs
                .iter()
                .map(|(name, path)| {
                    format!(
                        "(\"{}\",\"{}\",\"\",\"\")",
                        escape_string(name),
                        escape_string(path)
                    )
                })
                .collect();
            result.push_str(&output_parts.join(","));
        }

        result.push_str("],[");

        // Input derivations: list of tuples (drv-path, [output-names])
        let mut input_drv_parts = Vec::new();
        for (drv_path, output_names) in &self.input_derivations {
            let outputs_str = output_names
                .iter()
                .map(|n| format!("\"{}\"", escape_string(n)))
                .collect::<Vec<_>>()
                .join(",");
            input_drv_parts.push(format!(
                "(\"{}\",[{}])",
                escape_string(drv_path),
                outputs_str
            ));
        }
        result.push_str(&input_drv_parts.join(","));

        result.push_str("],[");

        // Input sources: list of store paths
        let source_parts: Vec<String> = self
            .input_sources
            .iter()
            .map(|s| format!("\"{}\"", escape_string(s)))
            .collect();
        result.push_str(&source_parts.join(","));

        result.push_str("],");

        // System
        write!(result, "\"{}\",", escape_string(&self.system)).unwrap();

        // Builder
        write!(result, "\"{}\",", escape_string(&self.builder)).unwrap();

        // Args
        result.push('[');
        let arg_parts: Vec<String> = self
            .args
            .iter()
            .map(|a| format!("\"{}\"", escape_string(a)))
            .collect();
        result.push_str(&arg_parts.join(","));
        result.push_str("],");

        // Environment variables as attribute set
        result.push('[');
        let env_parts: Vec<String> = self
            .env
            .iter()
            .map(|(k, v)| format!("(\"{}\",\"{}\")", escape_string(k), escape_string(v)))
            .collect();
        result.push_str(&env_parts.join(","));
        result.push_str("])");

        result
    }

    /// Compute the store path hash for this derivation
    ///
    /// The hash is computed as:
    /// 1. Serialize the derivation to ATerm format
    /// 2. Compute SHA256 hash of the serialization
    /// 3. Encode the hash in base32 (Nix uses a modified base32)
    /// 4. Take the first 32 characters as the hash
    pub fn compute_store_path_hash(&self) -> String {
        use base32::Alphabet;
        use sha2::{Digest, Sha256};

        let aterm = self.to_aterm();
        let mut hasher = Sha256::new();
        hasher.update(aterm.as_bytes());
        let hash_bytes = hasher.finalize();

        // Nix uses a modified base32 alphabet: 0-9, a-v (lowercase)
        // Standard base32 uses uppercase, but Nix uses lowercase
        // The base32 crate uses RFC 4648 which is uppercase, so we need to convert
        let base32_upper = base32::encode(Alphabet::RFC4648 { padding: false }, &hash_bytes);
        let base32_lower = base32_upper.to_lowercase();

        // Take first 32 characters (Nix typically uses 32-char hashes)
        base32_lower.chars().take(32).collect()
    }

    /// Get the store path for this derivation
    ///
    /// Returns a path like `/nix/store/<hash>-<name>.drv`
    pub fn store_path(&self) -> String {
        let hash = self.compute_store_path_hash();
        format!("/nix/store/{}-{}.drv", hash, self.name)
    }

    /// Write the derivation to a .drv file in the store
    ///
    /// This creates the .drv file at the computed store path.
    /// The store directory must exist and be writable.
    pub fn write_to_store(&self) -> Result<PathBuf> {
        use std::fs;
        use std::io::Write;

        let store_path_str = self.store_path();
        let store_path = PathBuf::from(&store_path_str);

        // Create parent directory if it doesn't exist
        if let Some(parent) = store_path.parent() {
            fs::create_dir_all(parent)?;
        }

        // Serialize to ATerm and write to file
        let aterm = self.to_aterm();
        let mut file = fs::File::create(&store_path)?;
        file.write_all(aterm.as_bytes())?;

        Ok(store_path)
    }
}

/// Escape a string for use in ATerm format
///
/// ATerm strings need special characters escaped:
/// - Backslash -> \\
/// - Double quote -> \"
/// - Newline -> \n
/// - Carriage return -> \r
/// - Tab -> \t
fn escape_string(s: &str) -> String {
    s.chars()
        .map(|c| match c {
            '\\' => "\\\\".to_string(),
            '"' => "\\\"".to_string(),
            '\n' => "\\n".to_string(),
            '\r' => "\\r".to_string(),
            '\t' => "\\t".to_string(),
            _ => c.to_string(),
        })
        .collect()
}
