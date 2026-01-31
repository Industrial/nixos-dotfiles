use oomkiller::daemon_iteration;
use sysinfo::System;

fn main() {
    // Create System object once and reuse it to avoid expensive initialization
    let mut system = System::new_all();

    // Main daemon loop: check memory every 5 seconds (reduced from 1 second)
    // This significantly reduces CPU usage while still being responsive enough
    loop {
        // Perform one daemon iteration with the reused System object
        match daemon_iteration(&mut system) {
            Ok(()) => {
                // Iteration completed successfully, continue monitoring
            }
            Err(e) => {
                // Memory reading failed, exit with code 1
                eprintln!("Failed to read memory: {}", e);
                std::process::exit(1);
            }
        }

        // Sleep for 5 seconds before next check (reduced frequency = lower CPU)
        std::thread::sleep(std::time::Duration::from_secs(5));
    }
}
