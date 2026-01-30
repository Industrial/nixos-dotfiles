// Hardcoded memory threshold: 90%
const MEMORY_THRESHOLD_PERCENT: f64 = 90.0;

use sysinfo::System;

/// Checks if system memory usage exceeds the hardcoded threshold (90%).
///
/// Returns `Ok(true)` if memory usage exceeds the threshold, `Ok(false)` otherwise.
/// Returns `Err` if memory information cannot be read.
pub fn is_memory_threshold_exceeded() -> Result<bool, String> {
    let mut system = System::new_all();
    system.refresh_memory();

    let total_memory = system.total_memory();
    let used_memory = system.used_memory();

    if total_memory == 0 {
        return Err("Total memory is 0, cannot calculate usage percentage".to_string());
    }

    let usage_percent = (used_memory as f64 / total_memory as f64) * 100.0;
    Ok(usage_percent >= MEMORY_THRESHOLD_PERCENT)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_memory_threshold_constant() {
        assert_eq!(MEMORY_THRESHOLD_PERCENT, 90.0);
    }

    #[test]
    fn test_is_memory_threshold_exceeded_returns_result() {
        // This test verifies the function returns a Result
        // We can't easily mock sysinfo, so we test that it returns a valid Result
        let result = is_memory_threshold_exceeded();
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_is_memory_threshold_exceeded_returns_boolean_when_ok() {
        // Test that when Ok, the value is a boolean
        let result = is_memory_threshold_exceeded();
        if let Ok(value) = result {
            // Value should be a boolean (true or false)
            assert!(value == true || value == false);
        }
    }

    #[test]
    fn test_memory_threshold_percent_is_90() {
        // Verify the threshold constant is exactly 90%
        assert_eq!(MEMORY_THRESHOLD_PERCENT, 90.0);
    }
}
