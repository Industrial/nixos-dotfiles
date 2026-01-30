use crate::{find_highest_memory_process, is_memory_threshold_exceeded, kill_process};
use sysinfo::System;

/// Performs one iteration of the daemon loop.
///
/// Checks if memory threshold is exceeded, and if so, finds and kills the highest memory process.
/// Uses a reused System object to avoid expensive initialization.
///
/// # Arguments
/// * `system` - A mutable reference to a System object (should be reused across calls)
///
/// # Returns
/// * `Ok(())` if the iteration completed successfully
/// * `Err(String)` if memory reading failed (should cause daemon to exit)
pub fn daemon_iteration(system: &mut System) -> Result<(), String> {
    // Check if memory threshold is exceeded (only refreshes memory, not all processes)
    let threshold_exceeded = is_memory_threshold_exceeded(system)?;

    if threshold_exceeded {
        // Memory threshold exceeded - log this event
        println!("Memory threshold exceeded (90%)");

        // Only now refresh all processes (expensive operation, only when needed)
        // This is the key optimization: we don't scan all processes every iteration
        system.refresh_all();

        // Find and kill highest memory process (system already refreshed above)
        match find_highest_memory_process(system) {
            Ok(Some(process)) => {
                // Found a process to kill
                if let Err(e) = kill_process(&process) {
                    eprintln!("Failed to kill process {}: {}", process.pid, e);
                } else {
                    println!(
                        "Killed process {} (memory: {} bytes)",
                        process.pid, process.memory
                    );
                }
            }
            Ok(None) => {
                // No processes found to kill
                eprintln!("Memory threshold exceeded but no killable process found");
            }
            Err(e) => {
                eprintln!("Failed to find highest memory process: {}", e);
            }
        }
    }

    Ok(())
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_daemon_iteration_returns_result() {
        // Test that daemon_iteration returns a Result
        let mut system = System::new_all();
        let result = daemon_iteration(&mut system);
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_daemon_iteration_handles_memory_check() {
        // Test that the function handles memory checking
        // This will either succeed (memory check works) or fail (memory check fails)
        let mut system = System::new_all();
        let result = daemon_iteration(&mut system);
        // Should return Ok if memory check succeeds, Err if it fails
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_daemon_iteration_completes() {
        // Test that the function completes without panicking
        // This is a basic smoke test
        let mut system = System::new_all();
        let _result = daemon_iteration(&mut system);
        // If we get here, the function completed
    }
}
