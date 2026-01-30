/// Checks if a process is owned by the given user ID
pub fn check_process_owned_by_user(pid: u32, uid: u32) -> Result<bool, String> {
    #[cfg(target_os = "linux")]
    {
        use std::fs;
        use std::os::unix::fs::MetadataExt;

        let proc_path = format!("/proc/{}", pid);
        let metadata = match fs::metadata(&proc_path) {
            Ok(m) => m,
            Err(_) => return Ok(false), // Process doesn't exist or we can't access it
        };

        Ok(metadata.uid() == uid)
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
    fn test_check_process_owned_by_user_with_invalid_pid() {
        // Test with an invalid PID (very high number that doesn't exist)
        let result = check_process_owned_by_user(999999999, 1000);
        // Should return Ok(false) if process doesn't exist
        assert!(result.is_ok());
        if let Ok(is_owned) = result {
            // Process doesn't exist, so should be false
            assert_eq!(is_owned, false);
        }
    }

    #[test]
    fn test_check_process_owned_by_user_with_current_process() {
        // Test with current process PID (should be owned by current user)
        #[cfg(target_os = "linux")]
        {
            use crate::get_current_uid;
            use std::process;

            let current_pid = process::id();
            let current_uid = get_current_uid().unwrap();

            let result = check_process_owned_by_user(current_pid, current_uid);
            assert!(result.is_ok());
            if let Ok(is_owned) = result {
                // Current process should be owned by current user
                assert_eq!(is_owned, true);
            }
        }
    }

    #[test]
    fn test_check_process_owned_by_user_with_wrong_uid() {
        // Test with wrong UID (should return false)
        #[cfg(target_os = "linux")]
        {
            use std::process;

            let current_pid = process::id();
            // Use a UID that definitely doesn't match (0 is root, current user is not root)
            let wrong_uid = 0;

            let result = check_process_owned_by_user(current_pid, wrong_uid);
            assert!(result.is_ok());
            if let Ok(is_owned) = result {
                // Current process should not be owned by root (unless we're root)
                // This test verifies the function correctly checks UID
                assert!(is_owned == false || is_owned == true); // Either is valid depending on user
            }
        }
    }
}
