use oomkiller::daemon_iteration;

fn main() {
    // Main daemon loop: check memory every 1 second
    loop {
        // Perform one daemon iteration
        match daemon_iteration() {
            Ok(()) => {
                // Iteration completed successfully, continue monitoring
            }
            Err(e) => {
                // Memory reading failed, exit with code 1
                eprintln!("Failed to read memory: {}", e);
                std::process::exit(1);
            }
        }

        // Sleep for 1 second before next check
        std::thread::sleep(std::time::Duration::from_secs(1));
    }
}
