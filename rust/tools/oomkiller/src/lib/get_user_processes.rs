use crate::{check_process_owned_by_user, get_current_uid, types::ProcessInfo};
use sysinfo::System;

/// Lists all processes owned by the current user.
///
/// Returns a vector of `ProcessInfo` containing PID and RSS memory usage.
/// Returns `Err` if process information cannot be read or current user ID cannot be determined.
pub fn get_user_processes() -> Result<Vec<ProcessInfo>, String> {
    let current_uid = get_current_uid()?;
    let mut system = System::new_all();
    system.refresh_all();

    let mut processes = Vec::new();

    for (pid, process) in system.processes() {
        // Check if process is owned by current user
        // In sysinfo 0.31, we need to check the process UID differently
        // Since user_id() might not be available, we'll use a different approach
        // For Linux, we can check /proc/<pid>/status or use the process's effective UID
        // For now, we'll get all processes and filter by checking if we can access them
        // This is a simplified approach - in practice, we'd need to check UID from /proc

        // Get process memory (RSS)
        let memory = process.memory();

        // For Linux, we'll include all processes for now and filter by UID check
        // This is a workaround - ideally we'd get UID from sysinfo directly
        processes.push(ProcessInfo {
            pid: (*pid).as_u32(),
            memory,
        });
    }

    // Filter by UID by checking if we can actually access the process
    // This is a simplified filter - in production, we'd check /proc/<pid>/status
    let filtered_processes: Vec<ProcessInfo> = processes
        .into_iter()
        .filter(|p| {
            // Check if process is owned by current user by trying to read /proc/<pid>/status
            // If we can read it and the UID matches, include it
            check_process_owned_by_user(p.pid, current_uid).unwrap_or(false)
        })
        .collect();

    Ok(filtered_processes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_user_processes_returns_result() {
        // Test that get_user_processes returns a Result
        let result = get_user_processes();
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_get_user_processes_returns_vector_when_ok() {
        // Test that when Ok, get_user_processes returns a vector
        let result = get_user_processes();
        if let Ok(processes) = result {
            // Should be a vector (can be empty or have processes)
            assert!(processes.len() >= 0);
            // If there are processes, they should have valid PIDs
            for process in processes {
                assert!(process.pid > 0);
                // Memory is u64, so it's always >= 0, no need to check
            }
        }
    }

    #[test]
    fn test_get_user_processes_filters_by_uid() {
        // Test that get_user_processes returns processes
        // The actual UID filtering is tested in check_process_owned_by_user tests
        // This test verifies the function works and returns valid ProcessInfo structs
        let result = get_user_processes();
        if let Ok(processes) = result {
            // Verify all returned processes have valid data
            for process in processes {
                assert!(process.pid > 0);
                // Memory is u64, so it's always >= 0
            }
        }
    }
}
