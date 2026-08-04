//! Differential oracle: corpus vs stock `nix-hash` when available.

use std::fs;
use std::path::PathBuf;
use std::process::Command;

use crate::{Encoding, HashAlgo, run_convert, run_hash_paths};

fn stock_nix_hash(args: &[&str]) -> Option<String> {
    let out = Command::new("nix-hash").args(args).output().ok()?;
    if !out.status.success() {
        return None;
    }
    Some(String::from_utf8_lossy(&out.stdout).trim_end().to_string())
}

fn temp_hello() -> PathBuf {
    use std::sync::atomic::{AtomicU64, Ordering};
    static SEQ: AtomicU64 = AtomicU64::new(0);
    let n = SEQ.fetch_add(1, Ordering::Relaxed);
    let dir = std::env::temp_dir().join(format!("nix1-oracle-{}-{n}", std::process::id()));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    let path = dir.join("f");
    fs::write(&path, b"hello").unwrap();
    path
}

#[test]
fn oracle_flat_md5_matches_stock_when_present() {
    let path = temp_hello();
    let path_s = path.to_string_lossy();
    let Some(want) = stock_nix_hash(&["--flat", "--type", "md5", path_s.as_ref()]) else {
        eprintln!("nix-hash not available; skipping live oracle");
        return;
    };
    let got = run_hash_paths(&[path.as_path()], HashAlgo::Md5, true, false, Encoding::Base16).unwrap();
    assert_eq!(got.join("\n"), want);
}

#[test]
fn oracle_recursive_sha256_encodings_match_stock_when_present() {
    let path = temp_hello();
    let p = path.to_string_lossy();
    let cases: &[(&[&str], HashAlgo, Encoding, bool)] = &[
        (&["--type", "sha256", p.as_ref()], HashAlgo::Sha256, Encoding::Base16, false),
        (
            &["--type", "sha256", "--base32", p.as_ref()],
            HashAlgo::Sha256,
            Encoding::Base32,
            false,
        ),
        (
            &["--type", "sha256", "--sri", p.as_ref()],
            HashAlgo::Sha256,
            Encoding::Sri,
            false,
        ),
        (
            &["--type", "sha256", "--truncate", p.as_ref()],
            HashAlgo::Sha256,
            Encoding::Base16,
            true,
        ),
        (
            &["--type", "sha1", "--base32", p.as_ref()],
            HashAlgo::Sha1,
            Encoding::Base32,
            false,
        ),
    ];
    for (args, algo, enc, trunc) in cases {
        let Some(want) = stock_nix_hash(args) else {
            eprintln!("nix-hash not available; skipping");
            return;
        };
        let got = run_hash_paths(&[path.as_path()], *algo, false, *trunc, *enc).unwrap();
        assert_eq!(got.join("\n"), want, "mismatch for {args:?}");
    }
}

#[test]
fn oracle_to_sri_matches_stock_when_present() {
    let path = temp_hello();
    let flat =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Base16).unwrap();
    let hex = &flat[0];
    let Some(want) = stock_nix_hash(&["--to-sri", "--type", "sha256", hex]) else {
        eprintln!("nix-hash not available; skipping");
        return;
    };
    let got = run_convert(&[hex.clone()], Some(HashAlgo::Sha256), Encoding::Sri).unwrap();
    assert_eq!(got.join("\n"), want);
}

#[test]
fn embedded_flat_sha256_hello() {
    let path = temp_hello();
    let got = run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Base16).unwrap();
    assert_eq!(
        got[0],
        "2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"
    );
}
