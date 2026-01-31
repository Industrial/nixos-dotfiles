/// Gets the current user's UID
pub fn get_current_uid() -> Result<u32, String> {
    #[cfg(target_os = "linux")]
    {
        use std::fs;
        use std::os::unix::fs::MetadataExt;

        // Get current user's UID by checking /proc/self
        let metadata = fs::metadata("/proc/self")
            .map_err(|e| format!("Failed to get current process metadata: {}", e))?;
        Ok(metadata.uid())
    }

    #[cfg(not(target_os = "linux"))]
    {
        Err("This tool is Linux-only".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_current_uid_returns_result() {
        // Test that get_current_uid returns a Result
        // On Linux, it should return Ok with a UID
        #[cfg(target_os = "linux")]
        {
            let result = get_current_uid();
            assert!(result.is_ok());
            if let Ok(uid) = result {
                assert!(uid > 0); // UID should be positive
            }
        }
    }

    #[test]
    #[cfg(target_os = "linux")]
    fn test_get_current_uid_returns_valid_uid() {
        // Test that get_current_uid returns a valid UID on Linux
        let result = get_current_uid();
        assert!(result.is_ok());
        let uid = result.unwrap();
        // UID should be a positive integer
        assert!(uid > 0);
        // UID should be reasonable (less than 2^31)
        assert!(uid < 2147483648);
    }
}
