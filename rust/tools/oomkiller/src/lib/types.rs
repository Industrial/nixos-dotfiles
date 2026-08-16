/// Represents a process with its PID, memory usage, and identity for logging.
#[derive(Debug, Clone)]
pub struct ProcessInfo {
    pub pid: u32,
    /// RSS memory in bytes (sysinfo reports bytes).
    pub memory: u64,
    /// Short process name (comm / basename).
    pub name: String,
    /// Full command line, space-joined; may be empty if unavailable.
    pub cmdline: String,
}

/// Formats a byte count for human-readable logs (e.g. `1.28 GiB`).
pub fn format_bytes(bytes: u64) -> String {
    const KIB: f64 = 1024.0;
    const MIB: f64 = KIB * 1024.0;
    const GIB: f64 = MIB * 1024.0;
    let b = bytes as f64;
    if b >= GIB {
        format!("{:.2} GiB", b / GIB)
    } else if b >= MIB {
        format!("{:.1} MiB", b / MIB)
    } else if b >= KIB {
        format!("{:.1} KiB", b / KIB)
    } else {
        format!("{bytes} B")
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    fn sample(pid: u32, memory: u64) -> ProcessInfo {
        ProcessInfo {
            pid,
            memory,
            name: "test".to_string(),
            cmdline: "test --flag".to_string(),
        }
    }

    #[test]
    fn test_process_info_struct() {
        let process = sample(1234, 1024);
        assert_eq!(process.pid, 1234);
        assert_eq!(process.memory, 1024);
        assert_eq!(process.name, "test");
        assert_eq!(process.cmdline, "test --flag");
    }

    #[test]
    fn test_process_info_debug() {
        let process = sample(5678, 2048);
        let debug_str = format!("{:?}", process);
        assert!(debug_str.contains("5678"));
        assert!(debug_str.contains("2048"));
        assert!(debug_str.contains("test"));
    }

    #[test]
    fn test_process_info_clone() {
        let process1 = sample(9999, 4096);
        let process2 = process1.clone();
        assert_eq!(process1.pid, process2.pid);
        assert_eq!(process1.memory, process2.memory);
        assert_eq!(process1.name, process2.name);
        assert_eq!(process1.cmdline, process2.cmdline);
    }

    #[test]
    fn test_format_bytes() {
        assert_eq!(format_bytes(512), "512 B");
        assert_eq!(format_bytes(2048), "2.0 KiB");
        assert_eq!(format_bytes(3 * 1024 * 1024), "3.0 MiB");
        assert_eq!(format_bytes(1377468416), "1.28 GiB");
    }
}
