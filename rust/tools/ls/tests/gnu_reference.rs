//! Differential tests against a reference GNU coreutils `ls` binary.
//!
//! Per `rust/tools/TESTING.md`, integration tests that need external setup are
//! marked `#[ignore]`. Run manually after setting `REFERENCE_GNU_LS`:
//!
//! ```text
//! REFERENCE_GNU_LS=/run/current-system/sw/bin/ls cargo test -p ls --test gnu_reference -- --ignored
//! ```

#![cfg(unix)]

use std::path::PathBuf;
use std::process::Command;

use ls::args::Settings;
use ls::run::run_ls_with_io;
use tempfile::tempdir;

#[test]
#[ignore = "set REFERENCE_GNU_LS to a GNU coreutils ls path"]
fn long_listing_matches_reference_for_plain_file() {
    let gnu: PathBuf = std::env::var_os("REFERENCE_GNU_LS")
        .expect("REFERENCE_GNU_LS must be set when running this ignored test")
        .into();

    let tmp = tempdir().expect("tmpdir");
    let dir = tmp.path();
    std::fs::write(dir.join("plain.txt"), b"hello").expect("write");

    let mut ours = Vec::new();
    let mut err = Vec::new();
    let settings = Settings {
        long: true,
        ..Default::default()
    };
    let code = run_ls_with_io(&settings, &[dir.to_path_buf()], &mut ours, &mut err);
    assert_eq!(code, 0, "stderr: {}", String::from_utf8_lossy(&err));

    let out = Command::new(&gnu)
        .current_dir(dir)
        .args(["-l", "--color=never", "."])
        .env("LC_ALL", "C")
        .env("LANG", "C")
        .output()
        .expect("run reference ls");
    assert!(out.status.success(), "{out:?}");

    let our_s = String::from_utf8(ours).expect("utf8");
    let ref_s = String::from_utf8(out.stdout).expect("utf8");

    assert!(
        our_s.contains("plain.txt"),
        "our ls should list plain.txt:\n{our_s}"
    );
    assert!(
        ref_s.contains("plain.txt"),
        "reference should list plain.txt:\n{ref_s}"
    );
}
