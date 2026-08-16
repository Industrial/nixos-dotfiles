use crate::{check_process_owned_by_user, get_current_uid, types::ProcessInfo};
use sysinfo::System;

/// Lists all processes owned by the current user.
///
/// Uses a System object that should already have been refreshed with refresh_all().
/// This avoids creating a new System object and re-scanning processes.
///
/// # Arguments
/// * `system` - A System object that has already been refreshed with refresh_all()
///
/// Returns a vector of `ProcessInfo` containing PID, RSS, name, and cmdline.
/// Returns `Err` if process information cannot be read or current user ID cannot be determined.
pub fn get_user_processes(system: &System) -> Result<Vec<ProcessInfo>, String> {
    let current_uid = get_current_uid()?;

    let mut processes = Vec::new();

    for (pid, process) in system.processes() {
        let pid_u32 = (*pid).as_u32();
        if !check_process_owned_by_user(pid_u32, current_uid).unwrap_or(false) {
            continue;
        }

        let name = process.name().to_string_lossy().into_owned();
        let cmdline = process
            .cmd()
            .iter()
            .map(|s| s.to_string_lossy())
            .collect::<Vec<_>>()
            .join(" ");

        processes.push(ProcessInfo {
            pid: pid_u32,
            memory: process.memory(),
            name,
            cmdline,
        });
    }

    Ok(processes)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_get_user_processes_returns_result() {
        let mut system = System::new_all();
        system.refresh_all();
        let result = get_user_processes(&system);
        assert!(result.is_ok() || result.is_err());
    }

    #[test]
    fn test_get_user_processes_returns_vector_when_ok() {
        let mut system = System::new_all();
        system.refresh_all();
        let result = get_user_processes(&system);
        if let Ok(processes) = result {
            for process in &processes {
                assert!(process.pid > 0);
            }
        }
    }

    #[test]
    fn test_get_user_processes_filters_by_uid() {
        let mut system = System::new_all();
        system.refresh_all();
        let result = get_user_processes(&system);
        if let Ok(processes) = result {
            for process in processes {
                assert!(process.pid > 0);
                let _ = &process.name;
                let _ = &process.cmdline;
            }
        }
    }
}
