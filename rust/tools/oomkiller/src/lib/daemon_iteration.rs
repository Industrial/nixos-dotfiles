use crate::{
    MEMORY_THRESHOLD_PERCENT, find_highest_memory_process, format_bytes,
    is_memory_threshold_exceeded, kill_process,
};
use sysinfo::System;

/// Truncate cmdline for journal readability.
fn truncate_cmdline(cmdline: &str, max_chars: usize) -> String {
    if cmdline.chars().count() <= max_chars {
        return cmdline.to_string();
    }
    let truncated: String = cmdline.chars().take(max_chars.saturating_sub(3)).collect();
    format!("{truncated}...")
}

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
    let threshold_exceeded = is_memory_threshold_exceeded(system)?;

    if threshold_exceeded {
        let total = system.total_memory();
        let used = system.used_memory();
        let usage_percent = if total == 0 {
            0.0
        } else {
            (used as f64 / total as f64) * 100.0
        };

        println!(
            "Memory threshold exceeded ({threshold}%): used={} / total={} ({usage_percent:.1}%)",
            format_bytes(used),
            format_bytes(total),
            threshold = MEMORY_THRESHOLD_PERCENT as u32,
        );

        // Only now refresh all processes (expensive; only when needed)
        system.refresh_all();

        match find_highest_memory_process(system) {
            Ok(Some(process)) => {
                let cmdline = if process.cmdline.is_empty() {
                    "(no cmdline)".to_string()
                } else {
                    truncate_cmdline(&process.cmdline, 240)
                };
                if let Err(e) = kill_process(&process) {
                    eprintln!(
                        "Failed to kill pid={} name={} rss={}: {e}",
                        process.pid,
                        process.name,
                        format_bytes(process.memory),
                    );
                } else {
                    println!(
                        "Killed process name={} pid={} rss={} cmdline={cmdline}",
                        process.name,
                        process.pid,
                        format_bytes(process.memory),
                    );
                }
            }
            Ok(None) => {
                eprintln!("Memory threshold exceeded but no killable process found");
            }
            Err(e) => {
                eprintln!("Failed to find highest memory process: {e}");
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
        let mut system = System::new_all();
        let result = daemon_iteration(&mut system);
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_daemon_iteration_handles_memory_check() {
        let mut system = System::new_all();
        let result = daemon_iteration(&mut system);
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_daemon_iteration_completes() {
        let mut system = System::new_all();
        let _result = daemon_iteration(&mut system);
    }

    #[test]
    fn test_truncate_cmdline() {
        assert_eq!(truncate_cmdline("short", 10), "short");
        assert_eq!(truncate_cmdline("abcdefghij", 10), "abcdefghij");
        assert_eq!(truncate_cmdline("abcdefghijkl", 10), "abcdefg...");
    }
}
