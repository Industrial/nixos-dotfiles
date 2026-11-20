use oomkiller::daemon_iteration;
use sysinfo::System;

fn main() {
    // Create System object once and reuse it to avoid expensive initialization
    let mut system = System::new_all();

    // Main daemon loop: check memory every second. A check only refreshes memory totals
    // (one read of /proc/meminfo); the process table is walked only when the threshold is
    // crossed. At 5 seconds a parallel link or a large backtest could take a 61 GiB host
    // from 80% to exhaustion between two checks.
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

        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
