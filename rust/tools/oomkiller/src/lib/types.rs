/// Represents a process with its PID and memory usage
#[derive(Debug, Clone)]
pub struct ProcessInfo {
    pub pid: u32,
    pub memory: u64,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_process_info_struct() {
        // Test ProcessInfo struct creation
        let process = ProcessInfo {
            pid: 1234,
            memory: 1024,
        };
        assert_eq!(process.pid, 1234);
        assert_eq!(process.memory, 1024);
    }

    #[test]
    fn test_process_info_debug() {
        // Test Debug trait implementation
        let process = ProcessInfo {
            pid: 5678,
            memory: 2048,
        };
        let debug_str = format!("{:?}", process);
        assert!(debug_str.contains("5678"));
        assert!(debug_str.contains("2048"));
    }

    #[test]
    fn test_process_info_clone() {
        // Test Clone trait implementation
        let process1 = ProcessInfo {
            pid: 9999,
            memory: 4096,
        };
        let process2 = process1.clone();
        assert_eq!(process1.pid, process2.pid);
        assert_eq!(process1.memory, process2.memory);
        // Verify they are separate instances
        assert_eq!(process1.pid, 9999);
        assert_eq!(process2.pid, 9999);
    }
}
