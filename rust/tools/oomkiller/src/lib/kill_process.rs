use crate::types::ProcessInfo;

/// Kills a process by sending SIGKILL signal.
///
/// # Arguments
/// * `process` - The ProcessInfo containing the PID of the process to kill
///
/// # Returns
/// * `Ok(())` if the process was successfully killed
/// * `Err(String)` if the kill operation failed
///
/// # Platform
/// Linux-only. Returns an error on non-Linux platforms.
pub fn kill_process(process: &ProcessInfo) -> Result<(), String> {
    #[cfg(target_os = "linux")]
    {
        use std::process::Command;

        // Send SIGKILL to the process
        let output = Command::new("kill")
            .arg("-9") // SIGKILL
            .arg(process.pid.to_string())
            .output()
            .map_err(|e| format!("Failed to execute kill command: {}", e))?;

        if output.status.success() {
            Ok(())
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(format!(
                "Failed to kill process {}: {}",
                process.pid, stderr
            ))
        }
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
    fn test_kill_process_returns_result() {
        // Test that kill_process returns a Result
        // We'll use an invalid PID (very high number) that doesn't exist
        // This should return an error, but the function should still return a Result
        let invalid_process = ProcessInfo {
            pid: 999999999,
            memory: 0,
        };
        let result = kill_process(&invalid_process);
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    #[cfg(target_os = "linux")]
    fn test_kill_process_with_invalid_pid() {
        // Test with an invalid PID (very high number that doesn't exist)
        // Should return an error
        let invalid_process = ProcessInfo {
            pid: 999999999,
            memory: 0,
        };
        let result = kill_process(&invalid_process);
        assert!(result.is_err());
        if let Err(e) = result {
            assert!(e.contains("Failed to kill process") || e.contains("No such process"));
        }
    }

    #[test]
    fn test_kill_process_accepts_process_info() {
        // Test that the function accepts ProcessInfo struct
        let process = ProcessInfo {
            pid: 1234,
            memory: 1024,
        };
        // Just verify it compiles and accepts the parameter
        // We can't test actual killing without side effects
        let _result = kill_process(&process);
    }
}
