use std::env;
use std::fs;
use std::path::{Path, PathBuf};

fn main() {
    // Tell Cargo to rerun this build script if test files change
    println!("cargo:rerun-if-changed=tests/tvix-tests");

    let out_dir = env::var("OUT_DIR").unwrap();
    let test_dir = PathBuf::from("tests/tvix-tests");
    
    if !test_dir.exists() {
        return; // No test files, skip generation
    }

    let mut test_code = String::from("// Auto-generated test functions\n");

    // Generate tests for identity-*.nix files
    generate_tests_for_pattern(&test_dir, "identity-*.nix", "identity", true, &mut test_code);
    
    // Generate tests for eval-okay-*.nix files (tvix_tests, not notyetpassing)
    generate_tests_for_pattern_with_filter(
        &test_dir,
        "eval-okay-*.nix",
        "eval_okay",
        true,
        |p| {
            let s = p.to_string_lossy();
            !s.contains("notyetpassing") && !s.contains("nix_tests")
        },
        &mut test_code,
    );

    // Generate tests for eval-okay-*.nix files (nix_tests, not notyetpassing)
    generate_tests_for_pattern_with_filter(
        &test_dir,
        "eval-okay-*.nix",
        "nix_eval_okay",
        true,
        |p| {
            let s = p.to_string_lossy();
            s.contains("nix_tests") && !s.contains("notyetpassing")
        },
        &mut test_code,
    );

    // Generate tests for eval-okay-*.nix files (nix_tests/notyetpassing)
    generate_tests_for_pattern_with_filter(
        &test_dir,
        "eval-okay-*.nix",
        "nix_eval_okay_currently_failing",
        false,
        |p| p.to_string_lossy().contains("nix_tests/notyetpassing"),
        &mut test_code,
    );

    // Generate tests for eval-okay-*.nix files (tvix_tests/notyetpassing)
    generate_tests_for_pattern_with_filter(
        &test_dir,
        "eval-okay-*.nix",
        "eval_okay_currently_failing",
        false,
        |p| p.to_string_lossy().contains("tvix_tests/notyetpassing"),
        &mut test_code,
    );

    // Generate tests for eval-fail-*.nix files (tvix_tests)
    generate_tests_for_pattern_with_filter(
        &test_dir,
        "eval-fail-*.nix",
        "eval_fail",
        false,
        |p| {
            let s = p.to_string_lossy();
            s.contains("tvix_tests") && !s.contains("nix_tests")
        },
        &mut test_code,
    );

    // Generate tests for eval-fail-*.nix files (nix_tests)
    generate_tests_for_pattern_with_filter(
        &test_dir,
        "eval-fail-*.nix",
        "nix_eval_fail",
        false,
        |p| p.to_string_lossy().contains("nix_tests"),
        &mut test_code,
    );

    // Write the generated test code
    let output_path = PathBuf::from(&out_dir).join("generated_tests.rs");
    fs::write(&output_path, test_code).unwrap();
}

fn generate_tests_for_pattern(
    test_dir: &Path,
    pattern: &str,
    prefix: &str,
    expect_success: bool,
    test_code: &mut String,
) {
    generate_tests_for_pattern_with_filter(test_dir, pattern, prefix, expect_success, |_| true, test_code);
}

fn generate_tests_for_pattern_with_filter<F>(
    test_dir: &Path,
    pattern: &str,
    prefix: &str,
    expect_success: bool,
    filter: F,
    test_code: &mut String,
) where
    F: Fn(&Path) -> bool,
{
    let (file_prefix, file_suffix) = if let Some(star_pos) = pattern.find('*') {
        (&pattern[..star_pos], &pattern[star_pos + 1..])
    } else {
        (pattern, "")
    };

    let files = find_files(test_dir, file_prefix, file_suffix);
    
    for file_path in files {
        if !filter(&file_path) {
            continue;
        }

        let test_name = path_to_test_name(&file_path, prefix);
        let path_str = file_path.to_string_lossy().replace('\\', "/");
        
        test_code.push_str(&format!(
            "#[test]\nfn {}() {{\n",
            test_name
        ));
        test_code.push_str(&format!(
            "    let code_path = std::path::PathBuf::from(env!(\"CARGO_MANIFEST_DIR\")).join(\"{}\");\n",
            path_str
        ));
        test_code.push_str(&format!(
            "    eval_test(code_path, {});\n",
            expect_success
        ));
        test_code.push_str("}\n\n");
    }
}

fn find_files(dir: &Path, prefix: &str, suffix: &str) -> Vec<PathBuf> {
    let mut files = Vec::new();
    
    if let Ok(entries) = fs::read_dir(dir) {
        for entry in entries.flatten() {
            let path = entry.path();
            if path.is_dir() {
                files.extend(find_files(&path, prefix, suffix));
            } else if path.is_file() {
                if let Some(file_name) = path.file_name().and_then(|n| n.to_str()) {
                    if file_name.starts_with(prefix) && file_name.ends_with(suffix) {
                        files.push(path);
                    }
                }
            }
        }
    }
    
    files
}

fn path_to_test_name(path: &Path, prefix: &str) -> String {
    // Get relative path from tests/tvix-tests
    let test_dir = PathBuf::from("tests/tvix-tests");
    let relative = path.strip_prefix(&test_dir).unwrap_or(path);
    
    // Convert to a valid Rust identifier
    let name = relative
        .to_string_lossy()
        .replace('/', "_")
        .replace('-', "_")
        .replace('.', "_")
        .replace(' ', "_")
        .replace('\\', "_");
    
    format!("{}_{}", prefix, name)
}
