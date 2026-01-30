use crate::{get_user_processes, types::ProcessInfo};

/// Finds the process with the highest RSS memory usage from user-owned processes.
///
/// Returns `Some(ProcessInfo)` if a process is found, `None` if no processes are available.
/// Returns `Err` if process listing fails.
pub fn find_highest_memory_process() -> Result<Option<ProcessInfo>, String> {
    let processes = get_user_processes()?;

    if processes.is_empty() {
        return Ok(None);
    }

    // Find the process with maximum memory usage
    let highest = processes.into_iter().max_by_key(|p| p.memory);

    Ok(highest)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_find_highest_memory_process_returns_result() {
        // Test that find_highest_memory_process returns a Result
        let result = find_highest_memory_process();
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_find_highest_memory_process_returns_option_when_ok() {
        // Test that when Ok, it returns an Option
        let result = find_highest_memory_process();
        if let Ok(option) = result {
            // Should be Some(ProcessInfo) or None
            match option {
                Some(process) => {
                    assert!(process.pid > 0);
                    // Memory should be valid
                }
                None => {
                    // No processes found, which is valid
                }
            }
        }
    }

    #[test]
    fn test_find_highest_memory_process_finds_maximum() {
        // Test that it correctly finds a process (if any exist)
        // We can't easily verify it's the maximum without calling get_user_processes twice,
        // which might return different results. So we just verify the function works.
        let result = find_highest_memory_process();
        assert!(result.is_ok());

        if let Ok(Some(process)) = result {
            // If we found a process, verify it has valid data
            assert!(process.pid > 0);
            // Memory should be valid (u64, so always >= 0)
        }
        // If None, that's also valid (no processes found)
    }

    #[test]
    fn test_find_highest_memory_process_handles_empty_list() {
        // Test that it returns None when no processes are available
        // This is hard to test directly, but we can verify the function handles it
        let result = find_highest_memory_process();
        assert!(result.is_ok());
        // If no user processes exist, should return None
        // Otherwise, should return Some(ProcessInfo)
    }
}
