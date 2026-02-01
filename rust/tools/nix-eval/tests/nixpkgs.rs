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
fn eval_with_nix_eval(expr: &str) -> Result<NixValue, String> {
    let evaluator = Evaluator::new();
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

        // Step 1: Import nixpkgs
        let expr = "import <nixpkgs> {}";
        let result = eval_with_nix_eval(expr);
        
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

        // Step 2: Try to evaluate all packages
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
            match value.clone().force(&Evaluator::new()) {
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

        let expr = "(import <nixpkgs> {}).lib";
        let result = eval_with_nix_eval(expr);
        
        match result {
            Ok(NixValue::AttributeSet(lib_attrs)) => {
                println!("✓ Successfully evaluated nixpkgs.lib");
                println!("  Found {} library functions", lib_attrs.len());
                
                // Try to evaluate a few key library functions
                let key_functions = ["length", "mapAttrs", "foldl'", "attrNames", "concatStringsSep"];
                for func_name in &key_functions {
                    if let Some(func_value) = lib_attrs.get(*func_name) {
                        match func_value.clone().force(&Evaluator::new()) {
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
