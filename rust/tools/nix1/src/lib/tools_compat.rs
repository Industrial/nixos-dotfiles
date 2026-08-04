//! Compatibility unit tests for NixOS / nixpkgs tools that invoke `nix-hash`.

//! These encode the CLI surfaces discovered under nixpkgs `pkgs/build-support/*`
//! and package `update.sh` scripts (cacert, brave, nuget, vscode, bash patches,
//! bootstrap refresh-tarballs, nix-prefetch-{git,hg,svn,bzr,cvs,docker}, …).

use std::fs;
use std::path::PathBuf;
use std::sync::atomic::{AtomicU64, Ordering};

use crate::{Encoding, HashAlgo, run_convert, run_hash_paths};

static SEQ: AtomicU64 = AtomicU64::new(0);

fn unique_dir(prefix: &str) -> PathBuf {
    let n = SEQ.fetch_add(1, Ordering::Relaxed);
    let dir = std::env::temp_dir().join(format!(
        "{prefix}-{}-{n}",
        std::process::id()
    ));
    let _ = fs::remove_dir_all(&dir);
    fs::create_dir_all(&dir).unwrap();
    dir
}

fn write_hello() -> PathBuf {
    let dir = unique_dir("nix1-tools");
    let path = dir.join("hello");
    fs::write(&path, b"hello").unwrap();
    path
}

fn write_tree() -> PathBuf {
    let dir = unique_dir("nix1-tools-tree");
    fs::create_dir_all(dir.join("a")).unwrap();
    fs::create_dir_all(dir.join("b")).unwrap();
    fs::write(dir.join("a/x"), b"x").unwrap();
    fs::write(dir.join("b/y"), b"y").unwrap();
    dir
}

/// `cacert/update.sh`: bare `nix-hash "$path"` (default md5, recursive).
#[test]
fn tool_cacert_default_recursive_md5() {
    let tree = write_tree();
    let got = run_hash_paths(&[tree.as_path()], HashAlgo::Md5, false, false, Encoding::Base16)
        .unwrap();
    assert_eq!(got[0].len(), 32);
}

/// `nix-prefetch-git`: `nix-hash --type $hashType --base32 "$tmpOut"`.
#[test]
fn tool_nix_prefetch_git_recursive_base32() {
    let tree = write_tree();
    let got =
        run_hash_paths(&[tree.as_path()], HashAlgo::Sha256, false, false, Encoding::Base32).unwrap();
    assert_eq!(got[0].len(), 52);
}

/// `nix-prefetch-git` / brave `update.sh`: `nix-hash --to-sri --type sha256 $hash`
/// where `$hash` is often Nix base32 (prefetch-url / prefetch-git).
#[test]
fn tool_brave_prefetch_to_sri_from_base32() {
    let path = write_hello();
    let b32 =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Base32).unwrap();
    let sri = run_convert(&b32, Some(HashAlgo::Sha256), Encoding::Sri).unwrap();
    assert_eq!(sri[0], "sha256-LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=");
}

/// `nix-prefetch-docker`: `nix-hash --flat --type $hashType --sri "$tmpFile"`.
#[test]
fn tool_nix_prefetch_docker_flat_sri() {
    let path = write_hello();
    let got =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Sri).unwrap();
    assert_eq!(got[0], "sha256-LPJNul+wow4m6DsqxbninhsWHlwfp0JecwQzYpOLmCQ=");
}

/// `bash/update-patch-set.sh`: `nix-hash --flat --type sha256 --base32 "$file"`.
#[test]
fn tool_bash_update_patch_set_flat_base32() {
    let path = write_hello();
    let got =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Base32).unwrap();
    assert_eq!(got[0], "094qif9n4cq4fdg459qzbhg1c6wywawwaaivx0k0x8xhbyx4vwic");
}

/// `nuget-to-json.sh`: `nix-hash --type sha256 --flat --sri` then `--to-sri`.
#[test]
fn tool_nuget_flat_sri_and_to_sri() {
    let path = write_hello();
    let sri =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Sri).unwrap();
    let hex =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Base16).unwrap();
    let via = run_convert(&hex, Some(HashAlgo::Sha256), Encoding::Sri).unwrap();
    assert_eq!(sri, via);
}

/// VS Code `update_installed_exts.sh`: `nix-hash --flat --sri --type sha256`.
#[test]
fn tool_vscode_flat_sri() {
    let path = write_hello();
    let got =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, true, false, Encoding::Sri).unwrap();
    assert!(got[0].starts_with("sha256-"));
}

/// `gitkraken/update.sh`: `nix-hash --sri --type sha256 "$path"`.
#[test]
fn tool_gitkraken_path_sri() {
    let path = write_hello();
    let got =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha256, false, false, Encoding::Sri).unwrap();
    assert!(got[0].starts_with("sha256-"));
}

/// `spotify/update.sh`: `nix-hash --to-sri --type sha512 $hash`.
#[test]
fn tool_spotify_to_sri_sha512() {
    let path = write_hello();
    let hex =
        run_hash_paths(&[path.as_path()], HashAlgo::Sha512, true, false, Encoding::Base16).unwrap();
    let sri = run_convert(&hex, Some(HashAlgo::Sha512), Encoding::Sri).unwrap();
    assert!(sri[0].starts_with("sha512-"));
    assert_eq!(sri[0], format!("sha512-{}", {
        use base64::Engine;
        base64::engine::general_purpose::STANDARD.encode(hex::decode(&hex[0]).unwrap())
    }));
}

/// `fetchcvs` / friends: `nix-hash --type $hashType --sri $path`.
#[test]
fn tool_fetchcvs_recursive_sri() {
    let tree = write_tree();
    let got =
        run_hash_paths(&[tree.as_path()], HashAlgo::Sha256, false, false, Encoding::Sri).unwrap();
    assert!(got[0].starts_with("sha256-"));
}

/// `bootstrap-files/refresh-tarballs.bash`:
/// `nix-hash --to-sri "$(nix-store --query --hash …)"` → `sha256:<nix32>`.
#[test]
fn tool_bootstrap_to_sri_from_store_hash() {
    let store_hash = "sha256:0sg9f58l1jj88w6pdrfdpj5x9b1zrwszk84j81zvby36q9whhhqa";
    let sri = run_convert(&[store_hash.into()], None, Encoding::Sri).unwrap();
    assert_eq!(sri[0], "sha256-CkMIecJm+LV/QJKg+TXPP6zUi7zN5XYNR0jKQFFx6Wk=");
}

/// Same bootstrap script: `nix-hash --to-sri "sha256:$sha256"`.
#[test]
fn tool_bootstrap_to_sri_prefixed_literal() {
    let b32 = "0sg9f58l1jj88w6pdrfdpj5x9b1zrwszk84j81zvby36q9whhhqa";
    let sri = run_convert(&[format!("sha256:{b32}")], None, Encoding::Sri).unwrap();
    assert_eq!(sri[0], "sha256-CkMIecJm+LV/QJKg+TXPP6zUi7zN5XYNR0jKQFFx6Wk=");
}
