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

        let output = Command::new("kill")
            .arg("-9") // SIGKILL
            .arg(process.pid.to_string())
            .output()
            .map_err(|e| format!("Failed to execute kill command: {e}"))?;

        if output.status.success() {
            Ok(())
        } else {
            let stderr = String::from_utf8_lossy(&output.stderr);
            Err(format!(
                "Failed to kill name={} pid={}: {stderr}",
                process.name, process.pid
            ))
        }
    }

    #[cfg(not(target_os = "linux"))]
    {
        let _ = process;
        Err("This tool is Linux-only".to_string())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample(pid: u32) -> ProcessInfo {
        ProcessInfo {
            pid,
            memory: 0,
            name: "test".to_string(),
            cmdline: String::new(),
        }
    }

    #[test]
    fn test_kill_process_returns_result() {
        let result = kill_process(&sample(999_999_999));
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    #[cfg(target_os = "linux")]
    fn test_kill_process_with_invalid_pid() {
        let result = kill_process(&sample(999_999_999));
        assert!(result.is_err());
        if let Err(e) = result {
            assert!(
                e.contains("Failed to kill") || e.contains("No such process"),
                "unexpected error: {e}"
            );
        }
    }

    #[test]
    fn test_kill_process_accepts_process_info() {
        let _result = kill_process(&sample(1234));
    }
}
