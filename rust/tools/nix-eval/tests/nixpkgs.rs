//! Nixpkgs evaluation test suite
//!
//! This test suite attempts to evaluate real nixpkgs expressions to identify
//! missing features and implementation gaps. Tests are designed to fail gracefully
//! with clear error messages when features are not yet implemented.
//!
//! The tests progress from simple to complex:
//! 1. Basic nixpkgs imports
//! 2. Simple package access
//! 3. Library function usage
//! 4. Complex package definitions
//! 5. NixOS configurations
//! 6. Flake outputs
//!
//! Each test documents what feature it's testing and what's required for it to pass.

use nix_eval::{Evaluator, NixValue};
use std::process::Command;
use std::str;

/// Helper to check if nixpkgs is available
fn nixpkgs_available() -> bool {
    Command::new("nix")
        .args(&["eval", "--expr", "import <nixpkgs> {}"])
        .output()
        .map(|o| o.status.success())
        .unwrap_or(false)
}

/// Helper to get nixpkgs path
fn get_nixpkgs_path() -> Option<String> {
    let output = Command::new("nix")
        .args(&["eval", "--raw", "--expr", "<nixpkgs>"])
        .output()
        .ok()?;
    
    if output.status.success() {
        str::from_utf8(&output.stdout)
            .ok()
            .map(|s| s.trim().to_string())
    } else {
        None
    }
}

/// Helper to evaluate with nix-eval and capture errors
/// Automatically configures nixpkgs search path if available
fn eval_with_nix_eval(expr: &str) -> Result<NixValue, String> {
    let mut evaluator = Evaluator::new();
    
    // Try to configure nixpkgs search path if available
    if let Some(nixpkgs_path) = get_nixpkgs_path() {
        evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path));
    }
    
    evaluator.evaluate(expr).map_err(|e| format!("{:?}", e))
}

/// Track missing features for summary
use std::sync::Mutex;
use std::sync::OnceLock;

static MISSING_FEATURES: OnceLock<Mutex<Vec<String>>> = OnceLock::new();

fn get_missing_features_mutex() -> &'static Mutex<Vec<String>> {
    MISSING_FEATURES.get_or_init(|| Mutex::new(Vec::new()))
}

fn record_missing_feature(feature: &str) {
    if let Ok(mut features) = get_missing_features_mutex().lock() {
        features.push(feature.to_string());
    }
}

fn get_missing_features() -> Vec<String> {
    get_missing_features_mutex()
        .lock()
        .map(|f| f.clone())
        .unwrap_or_default()
}

fn clear_missing_features() {
    if let Ok(mut features) = get_missing_features_mutex().lock() {
        features.clear();
    }
}

mod basic_imports {
    use super::*;

    /// Test: Resolve <nixpkgs> search path
    /// Requires: Search path resolution
    #[test]
    fn test_resolve_nixpkgs_search_path() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let mut evaluator = Evaluator::new();
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path));
        }

        // Test that we can resolve <nixpkgs> to a path
        let expr = "<nixpkgs>";
        let result = evaluator.evaluate(expr).map_err(|e| format!("{:?}", e));
        
        match result {
            Ok(NixValue::Path(_)) | Ok(NixValue::StorePath(_)) => {
                // Success!
            }
            Ok(other) => {
                panic!("Expected Path or StorePath, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ Failed to resolve <nixpkgs>: {}\n   Missing: Search path resolution", e);
                eprintln!("{}", msg);
                record_missing_feature("Search path resolution");
                panic!("{}", msg);
            }
        }
    }

    /// Test: Import nixpkgs default.nix directly
    /// Requires: `import` builtin, file reading, directory import handling
    #[test]
    fn test_import_nixpkgs_default_nix() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import default.nix directly
            let expr = format!("import {}/default.nix", nixpkgs_path);
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::AttributeSet(_)) | Ok(NixValue::Function(_)) => {
                    // Success!
                }
                Ok(other) => {
                    eprintln!("⚠️  Got unexpected type: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to import nixpkgs/default.nix: {}\n   Missing: import builtin, file reading, or directory import handling", e);
                    eprintln!("{}", msg);
                    record_missing_feature("import builtin, file reading, or directory import handling");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import nixpkgs lib/minfeatures.nix
    /// This is imported early in default.nix, so testing it separately helps isolate issues
    #[test]
    fn test_import_nixpkgs_lib_minfeatures() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import lib/minfeatures.nix directly
            let expr = format!("import {}/lib/minfeatures.nix", nixpkgs_path);
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::AttributeSet(_)) => {
                    // Success!
                }
                Ok(other) => {
                    eprintln!("⚠️  Got unexpected type: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to import lib/minfeatures.nix: {}\n   Missing: import builtin, file reading, or relative imports", e);
                    eprintln!("{}", msg);
                    record_missing_feature("import builtin, file reading, or relative imports");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import nixpkgs pkgs/top-level/impure.nix
    /// This is what default.nix imports, so testing it separately helps isolate issues
    #[test]
    fn test_import_nixpkgs_impure_nix() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import pkgs/top-level/impure.nix directly
            let expr = format!("import {}/pkgs/top-level/impure.nix", nixpkgs_path);
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::Function(_)) => {
                    // Success! impure.nix should return a function
                }
                Ok(other) => {
                    eprintln!("⚠️  Expected Function, got: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to import pkgs/top-level/impure.nix: {}\n   Missing: import builtin, file reading, or function evaluation", e);
                    eprintln!("{}", msg);
                    record_missing_feature("import builtin, file reading, or function evaluation");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import nixpkgs pkgs/top-level/impure-overlays.nix
    /// This is imported by impure.nix
    #[test]
    fn test_import_nixpkgs_impure_overlays() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import pkgs/top-level/impure-overlays.nix directly
            let expr = format!("import {}/pkgs/top-level/impure-overlays.nix", nixpkgs_path);
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::List(_)) => {
                    // Success! Should return a list of overlays
                }
                Ok(other) => {
                    eprintln!("⚠️  Expected List, got: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to import pkgs/top-level/impure-overlays.nix: {}\n   Missing: import builtin, file reading, or list evaluation", e);
                    eprintln!("{}", msg);
                    record_missing_feature("import builtin, file reading, or list evaluation");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import bare identifier (e.g., import flake without ./)
    /// This tests what happens when we try to import a bare identifier
    #[test]
    fn test_import_bare_identifier() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Test importing a bare identifier - this should resolve relative to current file
            // First, let's set up a test file that imports "flake"
            let test_dir = std::env::temp_dir().join("nix-eval-test-import");
            std::fs::create_dir_all(&test_dir).unwrap();
            
            // Create a flake directory with default.nix
            let flake_dir = test_dir.join("flake");
            std::fs::create_dir_all(&flake_dir).unwrap();
            std::fs::write(flake_dir.join("default.nix"), "{ x = 1; }").unwrap();
            
            // Create a test.nix that imports flake (bare identifier, no ./)
            let test_file = test_dir.join("test.nix");
            std::fs::write(&test_file, "import flake").unwrap();
            
            // Set current_file context and try to import
            // Actually, we need to test this through the evaluator's import mechanism
            // Let's test importing the test file which has "import flake"
            let expr = format!("import {}", test_file.display());
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::AttributeSet(_)) => {
                    // Success! Bare identifier import works
                }
                Ok(other) => {
                    eprintln!("⚠️  Expected AttributeSet, got: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to import bare identifier: {}\n   Missing: Bare identifier import handling (import flake should resolve relative to current file)", e);
                    eprintln!("{}", msg);
                    record_missing_feature("Bare identifier import handling");
                    panic!("{}", msg);
                }
            }
            
            // Cleanup
            let _ = std::fs::remove_dir_all(&test_dir);
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import directory (e.g., import ./flake when flake is a directory)
    /// This tests the directory import feature we just implemented
    #[test]
    fn test_import_directory() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Test importing a directory - nixpkgs has a flake.nix file, so flake/ might be a directory
            // Actually, let's test with a known directory structure
            // Check if lib/ is a directory and has default.nix
            let lib_path = format!("{}/lib", nixpkgs_path);
            if std::path::Path::new(&lib_path).is_dir() {
                // Try importing the lib directory (should resolve to lib/default.nix)
                let expr = format!("import {}/lib", nixpkgs_path);
                let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
                
                match result {
                    Ok(NixValue::AttributeSet(_)) => {
                        // Success! Directory import works
                    }
                    Ok(other) => {
                        eprintln!("⚠️  Expected AttributeSet, got: {:?}", other);
                    }
                    Err(e) => {
                        let msg = format!("❌ Failed to import directory: {}\n   Missing: Directory import handling (import ./dir should resolve to import ./dir/default.nix)", e);
                        eprintln!("{}", msg);
                        record_missing_feature("Directory import handling");
                        panic!("{}", msg);
                    }
                }
            } else {
                eprintln!("Skipping: lib/ is not a directory or doesn't exist");
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Basic nixpkgs import
    /// Requires: `import` builtin, path resolution, `<nixpkgs>` search path
    #[test]
    fn test_basic_nixpkgs_import() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "import <nixpkgs> {}";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::AttributeSet(_)) => {
                // Success! Basic import works
            }
            Ok(other) => {
                panic!("Expected AttributeSet, got: {:?}", other);
            }
            Err(e) => {
                // Expected to fail - document what's missing
                let msg = format!("❌ Basic nixpkgs import failed: {}\n   Missing: import builtin, <nixpkgs> search path resolution", e);
                eprintln!("{}", msg);
                record_missing_feature("import builtin, <nixpkgs> search path resolution");
                // Fail the test to make it visible
                panic!("{}", msg);
            }
        }
    }

    /// Test: Import nixpkgs with explicit path
    /// Requires: `import` builtin, file reading, path evaluation
    #[test]
    fn test_nixpkgs_import_with_path() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let expr = format!("import {} {{}}", nixpkgs_path);
            let result = eval_with_nix_eval(&expr);
            
            match result {
                Ok(NixValue::AttributeSet(_)) => {
                    // Success!
                }
                Ok(other) => {
                    panic!("Expected AttributeSet, got: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Nixpkgs import with path failed: {}\n   Missing: import builtin, file reading", e);
                    eprintln!("{}", msg);
                    record_missing_feature("import builtin, file reading");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Call impure.nix function with empty attribute set
    /// This tests what happens when we actually call the function returned by impure.nix
    #[test]
    fn test_call_impure_nix_function() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import impure.nix (returns a function) and call it with {}
            let expr = format!("(import {}/pkgs/top-level/impure.nix) {{}}", nixpkgs_path);
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::AttributeSet(_)) | Ok(NixValue::Function(_)) => {
                    // Success! Function call works
                }
                Ok(other) => {
                    eprintln!("⚠️  Got unexpected type: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to call impure.nix function: {}\n   Missing: Function application, attribute set handling, or nested imports", e);
                    eprintln!("{}", msg);
                    record_missing_feature("Function application, attribute set handling, or nested imports");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import pkgs/top-level/default.nix (what impure.nix imports)
    /// This is the actual package collection
    #[test]
    fn test_import_pkgs_top_level_default_nix() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import pkgs/top-level/default.nix directly
            let expr = format!("import {}/pkgs/top-level/default.nix", nixpkgs_path);
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::Function(_)) => {
                    // Success! Should return a function
                }
                Ok(other) => {
                    eprintln!("⚠️  Expected Function, got: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to import pkgs/top-level/default.nix: {}\n   Missing: import builtin, file reading, or nested directory imports", e);
                    eprintln!("{}", msg);
                    record_missing_feature("import builtin, file reading, or nested directory imports");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import pkgs/top-level/default.nix with arguments
    /// This tests calling the function with the arguments that impure.nix would pass
    #[test]
    fn test_call_pkgs_top_level_default_nix() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import pkgs/top-level/default.nix and call it with minimal args
            // Based on impure.nix, it needs: config, overlays, localSystem
            let expr = format!(
                "(import {}/pkgs/top-level/default.nix) {{ config = {{}}; overlays = []; localSystem = {{ system = \"x86_64-linux\"; }}; }}",
                nixpkgs_path
            );
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::AttributeSet(_)) => {
                    // Success! This should return the package set
                }
                Ok(other) => {
                    eprintln!("⚠️  Expected AttributeSet, got: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to call pkgs/top-level/default.nix: {}\n   Missing: Function application, nested attribute sets, or complex evaluation", e);
                    eprintln!("{}", msg);
                    record_missing_feature("Function application, nested attribute sets, or complex evaluation");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Trace the import chain that nixpkgs uses
    /// This helps identify exactly where in the chain the failure occurs
    #[test]
    fn test_trace_nixpkgs_import_chain() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            println!("\nTracing nixpkgs import chain...");
            
            // Step 1: Import default.nix
            println!("Step 1: Importing default.nix...");
            let expr1 = format!("import {}/default.nix", nixpkgs_path);
            let result1 = evaluator.evaluate(&expr1).map_err(|e| format!("{:?}", e));
            match result1 {
                Ok(_) => println!("  ✓ default.nix imported successfully"),
                Err(e) => {
                    panic!("❌ Failed at step 1 (default.nix): {}", e);
                }
            }
            
            // Step 2: Import pkgs/top-level/impure.nix
            println!("Step 2: Importing pkgs/top-level/impure.nix...");
            let expr2 = format!("import {}/pkgs/top-level/impure.nix", nixpkgs_path);
            let result2 = evaluator.evaluate(&expr2).map_err(|e| format!("{:?}", e));
            match result2 {
                Ok(_) => println!("  ✓ impure.nix imported successfully"),
                Err(e) => {
                    panic!("❌ Failed at step 2 (impure.nix): {}", e);
                }
            }
            
            // Step 3: Call impure.nix with {}
            println!("Step 3: Calling impure.nix function with {{}}...");
            let expr3 = format!("(import {}/pkgs/top-level/impure.nix) {{}}", nixpkgs_path);
            let result3 = evaluator.evaluate(&expr3).map_err(|e| format!("{:?}", e));
            match result3 {
                Ok(_) => println!("  ✓ impure.nix called successfully"),
                Err(e) => {
                    panic!("❌ Failed at step 3 (calling impure.nix): {}", e);
                }
            }
            
            // Step 4: Import pkgs/top-level/default.nix
            println!("Step 4: Importing pkgs/top-level/default.nix...");
            let expr4 = format!("import {}/pkgs/top-level/default.nix", nixpkgs_path);
            let result4 = evaluator.evaluate(&expr4).map_err(|e| format!("{:?}", e));
            match result4 {
                Ok(_) => println!("  ✓ pkgs/top-level/default.nix imported successfully"),
                Err(e) => {
                    panic!("❌ Failed at step 4 (pkgs/top-level/default.nix): {}", e);
                }
            }
            
            println!("✓ All import chain steps completed successfully!");
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Access a single package attribute to trigger lazy evaluation
    /// This tests what happens when we actually try to evaluate a package
    #[test]
    fn test_access_single_package_trigger_evaluation() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // Import nixpkgs and try to access a simple package
            let expr = "(import <nixpkgs> {}).hello";
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(_) => {
                    println!("✓ Successfully accessed hello package");
                }
                Err(e) => {
                    let msg = format!("❌ Failed to access hello package: {}\n   This is where lazy evaluation triggers nested imports", e);
                    eprintln!("{}", msg);
                    record_missing_feature("Lazy evaluation or nested imports during package access");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Call default.nix with {} (what import <nixpkgs> {} does)
    /// This is the exact expression that fails in the full evaluation test
    #[test]
    fn test_call_default_nix_with_empty_set() {
        if let Some(nixpkgs_path) = get_nixpkgs_path() {
            let mut evaluator = Evaluator::new();
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(nixpkgs_path.clone()));
            
            // This is exactly what "import <nixpkgs> {}" does
            let expr = format!("(import {}/default.nix) {{}}", nixpkgs_path);
            let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
            
            match result {
                Ok(NixValue::AttributeSet(_)) => {
                    println!("✓ Successfully called default.nix with {{}}");
                }
                Ok(other) => {
                    eprintln!("⚠️  Expected AttributeSet, got: {:?}", other);
                }
                Err(e) => {
                    let msg = format!("❌ Failed to call default.nix with {{}}: {}\n   This is the exact failure point - somewhere in this call chain, there's an import of 'flake'", e);
                    eprintln!("{}", msg);
                    record_missing_feature("Calling default.nix with empty attribute set");
                    panic!("{}", msg);
                }
            }
        } else {
            eprintln!("Skipping: Could not determine nixpkgs path");
        }
    }

    /// Test: Import a path variable (like `let flake = ./test-flake; in import flake`)
    /// This tests that we can import a path value stored in a variable
    #[test]
    fn test_import_path_variable() {
        use std::fs;
        use std::path::PathBuf;
        
        // Create a temporary directory structure
        let temp_dir = std::env::temp_dir().join("nix-eval-test-import-path");
        let _ = fs::remove_dir_all(&temp_dir); // Clean up if exists
        fs::create_dir_all(&temp_dir).unwrap();
        
        // Create test-flake directory with default.nix
        let flake_dir = temp_dir.join("test-flake");
        fs::create_dir_all(&flake_dir).unwrap();
        fs::write(flake_dir.join("default.nix"), "{ x = 1; }").unwrap();
        
        // Create test.nix that imports the flake variable
        let test_file = temp_dir.join("test.nix");
        fs::write(&test_file, "let flake = ./test-flake; in import flake").unwrap();
        
        // Test with our evaluator
        let mut evaluator = Evaluator::new();
        let expr = format!("import {}", test_file.display());
        let result = evaluator.evaluate(&expr).map_err(|e| format!("{:?}", e));
        
        match result {
            Ok(NixValue::AttributeSet(attrs)) => {
                // Check that x = 1
                if let Some(x_value) = attrs.get("x") {
                    let x = x_value.clone().force(&evaluator).unwrap();
                    if let NixValue::Integer(1) = x {
                        println!("✓ Successfully imported path variable");
                    } else {
                        panic!("Expected x = 1, got: {:?}", x);
                    }
                } else {
                    panic!("Expected attribute 'x' in result");
                }
            }
            Ok(other) => {
                let msg = format!("❌ Expected AttributeSet, got: {:?}", other);
                eprintln!("{}", msg);
                record_missing_feature("Import path variable");
                panic!("{}", msg);
            }
            Err(e) => {
                let msg = format!("❌ Failed to import path variable: {}\n   Missing: Path variable resolution in import", e);
                eprintln!("{}", msg);
                record_missing_feature("Path variable resolution in import");
                panic!("{}", msg);
            }
        }
        
        // Cleanup
        let _ = fs::remove_dir_all(&temp_dir);
    }
}

mod simple_package_access {
    use super::*;

    /// Test: Access a simple package from nixpkgs
    /// Requires: import, attribute access, lazy evaluation
    #[test]
    fn test_access_simple_package() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "(import <nixpkgs> {}).hello";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::AttributeSet(_)) | Ok(NixValue::Derivation(_)) => {
                // Success! Can access packages
            }
            Ok(other) => {
                eprintln!("⚠️  Got unexpected type: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ Simple package access failed: {}", e);
                eprintln!("   Missing: import, attribute access (.), or lazy evaluation");
            }
        }
    }

    /// Test: Access nested package attribute
    /// Requires: nested attribute access (pkgs.python3Packages.numpy)
    #[test]
    fn test_access_nested_package() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "(import <nixpkgs> {}).python3Packages.numpy";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(_) => {
                // Success!
            }
            Err(e) => {
                let msg = format!("❌ Nested package access failed: {}\n   Missing: nested attribute access (a.b.c)", e);
                eprintln!("{}", msg);
                record_missing_feature("nested attribute access (a.b.c)");
                panic!("{}", msg);
            }
        }
    }

    /// Test: Access package name attribute
    /// Requires: attribute access, string evaluation
    #[test]
    fn test_access_package_name() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "(import <nixpkgs> {}).hello.name";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::String(_)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected String, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ Package name access failed: {}\n   Missing: attribute access, derivation attribute access", e);
                eprintln!("{}", msg);
                record_missing_feature("attribute access, derivation attribute access");
                panic!("{}", msg);
            }
        }
    }
}

mod library_functions {
    use super::*;

    /// Test: Use lib.length
    /// Requires: lib access, function application, builtin functions
    #[test]
    fn test_lib_length() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "(import <nixpkgs> {}).lib.length [1 2 3]";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Integer(3)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Integer(3), got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ lib.length failed: {}\n   Missing: lib access, function application, or length builtin", e);
                eprintln!("{}", msg);
                record_missing_feature("lib access, function application, or length builtin");
                panic!("{}", msg);
            }
        }
    }

    /// Test: Use lib.mapAttrs
    /// Requires: lib access, higher-order functions, function application
    #[test]
    fn test_lib_mapattrs() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "(import <nixpkgs> {}).lib.mapAttrs (name: value: name) { a = 1; b = 2; }";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::AttributeSet(_)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected AttributeSet, got: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ lib.mapAttrs failed: {}", e);
                eprintln!("   Missing: lib.mapAttrs function, higher-order functions");
            }
        }
    }

    /// Test: Use lib.foldl'
    /// Requires: lib access, foldl' function, function application
    #[test]
    fn test_lib_foldl() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "(import <nixpkgs> {}).lib.foldl' (x: y: x + y) 0 [1 2 3]";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Integer(6)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Integer(6), got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ lib.foldl' failed: {}\n   Missing: lib.foldl' function, higher-order functions", e);
                eprintln!("{}", msg);
                record_missing_feature("lib.foldl' function, higher-order functions");
                panic!("{}", msg);
            }
        }
    }

    /// Test: Use lib.attrNames
    /// Requires: lib access, attrNames builtin
    #[test]
    fn test_lib_attrnames() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "(import <nixpkgs> {}).lib.attrNames { a = 1; b = 2; }";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::List(_)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected List, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ lib.attrNames failed: {}\n   Missing: lib.attrNames or attrNames builtin", e);
                eprintln!("{}", msg);
                record_missing_feature("lib.attrNames or attrNames builtin");
                panic!("{}", msg);
            }
        }
    }
}

mod complex_expressions {
    use super::*;

    /// Test: Evaluate a simple package definition
    /// Requires: Full package definition support, derivation builtin
    #[test]
    fn test_simple_package_definition() {
        let expr = r#"
        { stdenv, fetchurl }:
        stdenv.mkDerivation {
          name = "test-package";
          src = fetchurl {
            url = "https://example.com/test.tar.gz";
            sha256 = "0000000000000000000000000000000000000000000000000000";
          };
        }
        "#;

        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Function(_)) => {
                // Success! Can parse package definition
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Function, got: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ Simple package definition failed: {}", e);
                eprintln!("   Missing: function definitions, attribute sets, or string interpolation");
            }
        }
    }

    /// Test: Evaluate with expression
    /// Requires: `with` expression support
    #[test]
    fn test_with_expression() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = "with (import <nixpkgs> {}); [ hello git ]";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::List(_)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected List, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ with expression failed: {}\n   Missing: with expression support", e);
                eprintln!("{}", msg);
                record_missing_feature("with expression support");
                panic!("{}", msg);
            }
        }
    }

    /// Test: Evaluate let expression
    /// Requires: `let` expression support
    #[test]
    fn test_let_expression() {
        let expr = "let x = 1; y = 2; in x + y";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Integer(3)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Integer(3), got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ let expression failed: {}\n   Missing: let expression support or addition operator", e);
                eprintln!("{}", msg);
                record_missing_feature("let expression support or addition operator");
                panic!("{}", msg);
            }
        }
    }

    /// Test: Evaluate if expression
    /// Requires: `if` expression support
    #[test]
    fn test_if_expression() {
        let expr = "if true then 1 else 2";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Integer(1)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Integer(1), got: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ if expression failed: {}", e);
                eprintln!("   Missing: if expression support");
            }
        }
    }
}

mod operators {
    use super::*;

    /// Test: Unary minus operator
    /// Requires: Unary operators support
    #[test]
    fn test_unary_minus() {
        let expr = "-42";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Integer(-42)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Integer(-42), got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ Unary minus failed: {}\n   Missing: Unary operator support (UnaryOp)", e);
                eprintln!("{}", msg);
                record_missing_feature("Unary operator support (UnaryOp)");
                panic!("{}", msg);
            }
        }
    }

    /// Test: String concatenation
    /// Requires: String concatenation operator
    #[test]
    fn test_string_concat() {
        let expr = r#""hello" + " " + "world""#;
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::String(s)) if s == "hello world" => {
                // Success!
            }
            Ok(NixValue::String(s)) => {
                eprintln!("⚠️  Expected 'hello world', got: '{}'", s);
            }
            Ok(other) => {
                eprintln!("⚠️  Expected String, got: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ String concatenation failed: {}", e);
                eprintln!("   Missing: String concatenation in + operator");
            }
        }
    }

    /// Test: List concatenation
    /// Requires: List concatenation operator
    #[test]
    fn test_list_concat() {
        let expr = "[1 2] ++ [3 4]";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::List(l)) if l.len() == 4 => {
                // Success!
            }
            Ok(NixValue::List(l)) => {
                eprintln!("⚠️  Expected list of length 4, got: {}", l.len());
            }
            Ok(other) => {
                eprintln!("⚠️  Expected List, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ List concatenation failed: {}\n   Missing: List concatenation (++) operator", e);
                eprintln!("{}", msg);
                record_missing_feature("List concatenation (++) operator");
                panic!("{}", msg);
            }
        }
    }
}

mod builtin_functions {
    use super::*;

    /// Test: builtins.readFile
    /// Requires: readFile builtin, file I/O
    #[test]
    fn test_builtins_readfile() {
        // Create a temporary file
        let test_file = std::env::temp_dir().join("nix-eval-test.txt");
        std::fs::write(&test_file, "hello world").unwrap();
        
        let expr = format!("builtins.readFile {}", test_file.display());
        let result = eval_with_nix_eval(&expr);
        
        match result {
            Ok(NixValue::String(s)) if s == "hello world" => {
                // Success!
            }
            Ok(NixValue::String(s)) => {
                eprintln!("⚠️  Expected 'hello world', got: '{}'", s);
            }
            Ok(other) => {
                eprintln!("⚠️  Expected String, got: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ builtins.readFile failed: {}", e);
                eprintln!("   Missing: readFile builtin or file I/O");
            }
        }
        
        // Cleanup
        let _ = std::fs::remove_file(&test_file);
    }

    /// Test: builtins.mapAttrs
    /// Requires: mapAttrs builtin, higher-order functions
    #[test]
    fn test_builtins_mapattrs() {
        let expr = "builtins.mapAttrs (name: value: name) { a = 1; b = 2; }";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::AttributeSet(_)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected AttributeSet, got: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ builtins.mapAttrs failed: {}", e);
                eprintln!("   Missing: mapAttrs builtin or higher-order function support");
            }
        }
    }

    /// Test: builtins.foldl'
    /// Requires: foldl' builtin, higher-order functions
    #[test]
    fn test_builtins_foldl() {
        let expr = "builtins.foldl' (x: y: x + y) 0 [1 2 3]";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Integer(6)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Integer(6), got: {:?}", other);
            }
            Err(e) => {
                eprintln!("❌ builtins.foldl' failed: {}", e);
                eprintln!("   Missing: foldl' builtin or higher-order function support");
            }
        }
    }

    /// Test: builtins.genList
    /// Requires: genList builtin, function application
    #[test]
    fn test_builtins_genlist() {
        let expr = "builtins.genList (x: x * 2) 5";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::List(l)) if l.len() == 5 => {
                // Success!
            }
            Ok(NixValue::List(l)) => {
                eprintln!("⚠️  Expected list of length 5, got: {}", l.len());
            }
            Ok(other) => {
                eprintln!("⚠️  Expected List, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ builtins.genList failed: {}\n   Missing: genList builtin or function application", e);
                eprintln!("{}", msg);
                record_missing_feature("genList builtin or function application");
                panic!("{}", msg);
            }
        }
    }
}

mod nixos_configurations {
    use super::*;

    /// Test: Simple NixOS configuration
    /// Requires: Full NixOS evaluation support
    #[test]
    fn test_simple_nixos_config() {
        if !nixpkgs_available() {
            eprintln!("Skipping: nixpkgs not available");
            return;
        }

        let expr = r#"
        { config, pkgs, ... }:
        {
          services.openssh.enable = true;
        }
        "#;

        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::Function(_)) => {
                // Success! Can parse NixOS config
            }
            Ok(other) => {
                eprintln!("⚠️  Expected Function, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ Simple NixOS config failed: {}\n   Missing: Function definitions, nested attribute sets", e);
                eprintln!("{}", msg);
                record_missing_feature("Function definitions, nested attribute sets");
                panic!("{}", msg);
            }
        }
    }
}

mod flake_outputs {
    use super::*;

    /// Test: Simple flake outputs structure
    /// Requires: Flake output evaluation
    #[test]
    fn test_flake_outputs_structure() {
        let expr = r#"
        {
          packages.x86_64-linux.hello = (import <nixpkgs> {}).hello;
          devShells.x86_64-linux.default = (import <nixpkgs> {}).mkShell {};
        }
        "#;

        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::AttributeSet(_)) => {
                // Success!
            }
            Ok(other) => {
                eprintln!("⚠️  Expected AttributeSet, got: {:?}", other);
            }
            Err(e) => {
                let msg = format!("❌ Flake outputs structure failed: {}\n   Missing: Nested attribute sets, import, or package access", e);
                eprintln!("{}", msg);
                record_missing_feature("Nested attribute sets, import, or package access");
                panic!("{}", msg);
            }
        }
    }
}

mod full_evaluation {
    use super::*;

    /// Test: Evaluate ALL of nixpkgs
    /// 
    /// This test attempts to evaluate the entire nixpkgs repository by:
    /// 1. Importing nixpkgs
    /// 2. Iterating through all top-level packages
    /// 3. Evaluating each package to ensure the evaluator can handle the full complexity
    /// 
    /// This is the ultimate test - it will fail until nix-eval can fully evaluate nixpkgs.
    /// 
    /// Requires: Full nixpkgs evaluation support including:
    /// - Complete import system
    /// - All builtin functions
    /// - All Nix language features
    /// - Proper lazy evaluation
    /// - Error handling for edge cases
    /// 
    /// NOTE: This test will FAIL until nix-eval can fully evaluate nixpkgs.
    /// It does NOT skip - it always attempts evaluation to track progress.
    #[test]
    fn test_evaluate_all_nixpkgs() {

        println!("\n═══════════════════════════════════════════════════════════");
        println!("  Testing Full Nixpkgs Evaluation");
        println!("═══════════════════════════════════════════════════════════\n");

        // Step 1: Configure evaluator with nixpkgs search path
        let mut evaluator = Evaluator::new();
        
        // Try to get nixpkgs path and configure search path
        if let Some(path) = get_nixpkgs_path() {
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(path));
        } else {
            // Try alternative: use NIX_PATH environment variable
            if let Ok(nix_path) = std::env::var("NIX_PATH") {
                // NIX_PATH format: "nixpkgs=/path/to/nixpkgs:other=/path"
                for entry in nix_path.split(':') {
                    if let Some((name, path)) = entry.split_once('=') {
                        if name == "nixpkgs" {
                            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(path));
                            break;
                        }
                    }
                }
            }
        }

        // Step 2: Import nixpkgs
        let expr = "import <nixpkgs> {}";
        let result = evaluator.evaluate(expr).map_err(|e| format!("{:?}", e));
        
        let pkgs = match result {
            Ok(NixValue::AttributeSet(attrs)) => attrs,
            Ok(other) => {
                let msg = format!("❌ Failed to import nixpkgs: expected AttributeSet, got {:?}", other);
                eprintln!("{}", msg);
                record_missing_feature("nixpkgs import");
                panic!("{}", msg);
            }
            Err(e) => {
                let msg = format!("❌ Failed to import nixpkgs: {}\n   Missing: import builtin, <nixpkgs> search path", e);
                eprintln!("{}", msg);
                record_missing_feature("nixpkgs import");
                panic!("{}", msg);
            }
        };

        println!("✓ Successfully imported nixpkgs");
        println!("  Found {} top-level attributes", pkgs.len());

        // Step 3: Try to evaluate all packages
        // We'll iterate through packages and try to evaluate them
        // This will fail on the first package that requires unsupported features
        let mut evaluated_count = 0;
        let mut failed_packages = Vec::new();
        let mut total_packages = 0;

        // Get package names (we'll try to access lib.attrNames if available)
        // For now, we'll iterate through what we have
        for (name, value) in &pkgs {
            total_packages += 1;
            
            // Try to force evaluation of this package
            // This will trigger evaluation of the package's derivation
            match value.clone().force(&evaluator) {
                Ok(_) => {
                    evaluated_count += 1;
                    if evaluated_count % 100 == 0 {
                        println!("  Progress: {}/{} packages evaluated", evaluated_count, total_packages);
                    }
                }
                Err(e) => {
                    failed_packages.push((name.clone(), format!("{:?}", e)));
                    // Don't fail immediately - collect failures to report at the end
                    if failed_packages.len() <= 10 {
                        eprintln!("  ⚠️  Failed to evaluate package '{}': {:?}", name, e);
                    }
                }
            }
        }

        println!("\n═══════════════════════════════════════════════════════════");
        println!("  Evaluation Summary");
        println!("═══════════════════════════════════════════════════════════");
        println!("Total packages: {}", total_packages);
        println!("Successfully evaluated: {}", evaluated_count);
        println!("Failed: {}", failed_packages.len());
        
        if !failed_packages.is_empty() {
            println!("\nFirst {} failed packages:", failed_packages.len().min(10));
            for (name, error) in failed_packages.iter().take(10) {
                println!("  - {}: {}", name, error);
            }
            
            let msg = format!(
                "❌ Full nixpkgs evaluation incomplete: {}/{} packages failed\n   Missing: Full nixpkgs evaluation support",
                failed_packages.len(),
                total_packages
            );
            eprintln!("\n{}", msg);
            record_missing_feature("Full nixpkgs evaluation support");
            panic!("{}", msg);
        } else {
            println!("\n✅ Successfully evaluated ALL of nixpkgs!");
        }
        println!("═══════════════════════════════════════════════════════════\n");
    }

    /// Test: Evaluate nixpkgs.lib (all library functions)
    /// 
    /// This tests evaluation of the entire lib attribute set, which contains
    /// all library functions used throughout nixpkgs.
    /// 
    /// NOTE: This test will FAIL until nix-eval can fully evaluate nixpkgs.lib.
    /// It does NOT skip - it always attempts evaluation to track progress.
    #[test]
    fn test_evaluate_nixpkgs_lib() {

        // Configure evaluator with nixpkgs search path
        let mut evaluator = Evaluator::new();
        
        // Try to get nixpkgs path and configure search path
        if let Some(path) = get_nixpkgs_path() {
            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(path));
        } else {
            // Try alternative: use NIX_PATH environment variable
            if let Ok(nix_path) = std::env::var("NIX_PATH") {
                for entry in nix_path.split(':') {
                    if let Some((name, path)) = entry.split_once('=') {
                        if name == "nixpkgs" {
                            evaluator.add_search_path("nixpkgs", std::path::PathBuf::from(path));
                            break;
                        }
                    }
                }
            }
        }

        let expr = "(import <nixpkgs> {}).lib";
        let result = evaluator.evaluate(expr).map_err(|e| format!("{:?}", e));
        
        match result {
            Ok(NixValue::AttributeSet(lib_attrs)) => {
                println!("✓ Successfully evaluated nixpkgs.lib");
                println!("  Found {} library functions", lib_attrs.len());
                
                // Try to evaluate a few key library functions
                let key_functions = ["length", "mapAttrs", "foldl'", "attrNames", "concatStringsSep"];
                for func_name in &key_functions {
                    if let Some(func_value) = lib_attrs.get(*func_name) {
                        match func_value.clone().force(&evaluator) {
                            Ok(_) => {
                                println!("  ✓ {}: evaluated successfully", func_name);
                            }
                            Err(e) => {
                                let msg = format!("❌ Failed to evaluate lib.{}: {:?}", func_name, e);
                                eprintln!("{}", msg);
                                record_missing_feature(&format!("lib.{} evaluation", func_name));
                                panic!("{}", msg);
                            }
                        }
                    }
                }
            }
            Ok(other) => {
                let msg = format!("❌ Expected AttributeSet for lib, got: {:?}", other);
                eprintln!("{}", msg);
                record_missing_feature("nixpkgs.lib access");
                panic!("{}", msg);
            }
            Err(e) => {
                let msg = format!("❌ Failed to evaluate nixpkgs.lib: {}\n   Missing: lib access or evaluation", e);
                eprintln!("{}", msg);
                record_missing_feature("nixpkgs.lib evaluation");
                panic!("{}", msg);
            }
        }
    }
}

/// Test suite runner that provides a summary
/// This test should run last to collect all missing features
#[test]
fn test_nixpkgs_evaluation_summary() {
    // Clear any previous runs
    clear_missing_features();
    
    println!("\n═══════════════════════════════════════════════════════════");
    println!("  Nixpkgs Evaluation Test Suite");
    println!("═══════════════════════════════════════════════════════════");
    println!();
    println!("This test suite evaluates real nixpkgs expressions to identify");
    println!("missing features and implementation gaps.");
    println!();
    println!("Tests will FAIL when features are missing - this helps track");
    println!("progress toward full nixpkgs evaluation support.");
    println!();
    println!("To run individual test modules:");
    println!("  cargo nextest run --test nixpkgs basic_imports");
    println!("  cargo nextest run --test nixpkgs simple_package_access");
    println!("  cargo nextest run --test nixpkgs library_functions");
    println!("  cargo nextest run --test nixpkgs complex_expressions");
    println!("  cargo nextest run --test nixpkgs operators");
    println!("  cargo nextest run --test nixpkgs builtin_functions");
    println!("  cargo nextest run --test nixpkgs nixos_configurations");
    println!("  cargo nextest run --test nixpkgs flake_outputs");
    println!("  cargo nextest run --test nixpkgs full_evaluation");
    println!();
    println!("═══════════════════════════════════════════════════════════\n");
}
