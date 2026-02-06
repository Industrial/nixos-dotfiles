//! Standalone test runner for compatibility tests
//!
//! This test can be run with: cargo test --test compatibility_runner
//!
//! It runs compatibility tests against the reference Nix implementation
//! using test data from the tests/data directory.

#[cfg(test)]
mod test_runner {
    use super::*;
    use std::collections::HashMap;
    use std::fs;
    use std::path::{Path, PathBuf};
    use std::process::Command;
    use std::str;

    /// Test result for a single expression
    #[derive(Debug, Clone)]
    pub enum TestResult {
        Pass,
        Fail {
            expression: String,
            expected: String,
            actual: String,
            error: Option<String>,
        },
        Skip {
            reason: String,
        },
    }

    /// Test suite results
    #[derive(Debug)]
    pub struct TestSuiteResults {
        pub passed: usize,
        pub failed: usize,
        pub skipped: usize,
        pub failures: Vec<TestResult>,
    }

    impl TestSuiteResults {
        pub fn new() -> Self {
            Self {
                passed: 0,
                failed: 0,
                skipped: 0,
                failures: Vec::new(),
            }
        }

        pub fn total(&self) -> usize {
            self.passed + self.failed + self.skipped
        }

        pub fn success_rate(&self) -> f64 {
            if self.total() == 0 {
                return 0.0;
            }
            (self.passed as f64) / (self.total() as f64) * 100.0
        }
    }

    /// Load test expressions from a directory
    pub fn load_test_expressions<P: AsRef<Path>>(dir: P) -> Result<Vec<(String, PathBuf)>, String> {
        let mut expressions = Vec::new();

        if !dir.as_ref().exists() {
            return Ok(expressions);
        }

        for entry in
            fs::read_dir(dir.as_ref()).map_err(|e| format!("Failed to read directory: {}", e))?
        {
            let entry = entry.map_err(|e| format!("Failed to read entry: {}", e))?;
            let path = entry.path();

            if path.extension().and_then(|s| s.to_str()) == Some("nix") {
                let content = fs::read_to_string(&path)
                    .map_err(|e| format!("Failed to read {}: {}", path.display(), e))?;
                expressions.push((content, path));
            }
        }

        Ok(expressions)
    }

    /// Run a single compatibility test
    pub fn run_compatibility_test(expression: &str, expected_output: Option<&str>) -> TestResult {
        // Evaluate with reference Nix
        let reference_output = match evaluate_with_nix(expression) {
            Ok(output) => output,
            Err(e) => {
                return TestResult::Fail {
                    expression: expression.to_string(),
                    expected: expected_output.unwrap_or("(success)").to_string(),
                    actual: format!("(nix error: {})", e),
                    error: Some(e),
                };
            }
        };

        // Evaluate with our implementation
        let our_output = match evaluate_with_ours(expression) {
            Ok(output) => output,
            Err(e) => {
                return TestResult::Fail {
                    expression: expression.to_string(),
                    expected: reference_output.clone(),
                    actual: format!("(nix-eval error: {})", e),
                    error: Some(e.to_string()),
                };
            }
        };

        // Compare outputs
        if normalize_output(&reference_output) == normalize_output(&our_output) {
            TestResult::Pass
        } else {
            TestResult::Fail {
                expression: expression.to_string(),
                expected: reference_output,
                actual: our_output,
                error: None,
            }
        }
    }

    /// Evaluate expression with reference Nix
    fn evaluate_with_nix(expr: &str) -> Result<String, String> {
        let output = Command::new("nix")
            .args(&["eval", "--raw", "--expr", expr])
            .output()
            .map_err(|e| format!("Failed to execute nix: {}", e))?;

        if !output.status.success() {
            let stderr = str::from_utf8(&output.stderr)
                .unwrap_or("(invalid UTF-8)")
                .to_string();
            return Err(format!("nix eval failed: {}", stderr));
        }

        let stdout = str::from_utf8(&output.stdout).map_err(|e| format!("Invalid UTF-8: {}", e))?;

        Ok(stdout.trim().to_string())
    }

    /// Evaluate expression with our implementation
    fn evaluate_with_ours(expr: &str) -> Result<String, nix_eval::Error> {
        use nix_eval::Evaluator;
        let evaluator = Evaluator::new();
        let value = evaluator.evaluate(expr)?;
        Ok(value.to_string())
    }

    /// Normalize output for comparison
    fn normalize_output(output: &str) -> String {
        output.trim().to_string()
    }

    /// Run a test suite from a directory
    pub fn run_test_suite<P: AsRef<Path>>(dir: P) -> Result<TestSuiteResults, String> {
        let expressions = load_test_expressions(&dir)?;
        let mut results = TestSuiteResults::new();

        for (expression, path) in expressions {
            // Try to load expected output if it exists
            let expected_path = path.with_extension("exp");
            let expected_output = if expected_path.exists() {
                fs::read_to_string(&expected_path).ok()
            } else {
                None
            };

            let result = run_compatibility_test(&expression, expected_output.as_deref());

            match &result {
                TestResult::Pass => results.passed += 1,
                TestResult::Fail { .. } => {
                    results.failed += 1;
                    results.failures.push(result);
                }
                TestResult::Skip { .. } => results.skipped += 1,
            }
        }

        Ok(results)
    }

    /// Print test suite results
    pub fn print_results(results: &TestSuiteResults) {
        println!("\n=== Test Suite Results ===");
        println!("Total:   {}", results.total());
        println!("Passed:  {}", results.passed);
        println!("Failed:  {}", results.failed);
        println!("Skipped: {}", results.skipped);
        println!("Success Rate: {:.2}%", results.success_rate());

        if !results.failures.is_empty() {
            println!("\n=== Failures ===");
            for (i, failure) in results.failures.iter().enumerate() {
                if let TestResult::Fail {
                    expression,
                    expected,
                    actual,
                    error,
                } = failure
                {
                    println!("\nFailure {}:", i + 1);
                    println!("  Expression: {}", expression);
                    println!("  Expected:   {}", expected);
                    println!("  Actual:     {}", actual);
                    if let Some(err) = error {
                        println!("  Error:      {}", err);
                    }
                }
            }
        }
    }
}

#[test]
fn test_compatibility_suite() {
    use std::path::PathBuf;
    use test_runner::{print_results, run_test_suite};

    let test_dir = PathBuf::from(env!("CARGO_MANIFEST_DIR"))
        .join("tests")
        .join("data");

    println!("Running compatibility tests from: {}", test_dir.display());
    println!("(This requires 'nix' to be available in PATH)\n");

    match run_test_suite(&test_dir) {
        Ok(results) => {
            print_results(&results);

            // Fail the test if any tests failed
            if results.failed > 0 {
                panic!("{} compatibility tests failed", results.failed);
            }
        }
        Err(e) => {
            panic!("Error running test suite: {}", e);
        }
    }
}
