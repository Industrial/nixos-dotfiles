use std::process::Command;
use std::env;

fn main() {
    let args: Vec<String> = env::args().collect();

    // Handle additional arguments first
    if args.len() > 1 {
        match args[1].as_str() {
            "--help" | "-h" => {
                println!("cl - A simple terminal clear command");
                println!("\nUsage:");
                println!("  cl           Clear the entire screen");
                println!("  cl --help    Show this help message");
                return;
            }
            _ => {
                eprintln!("Unknown argument: {}", args[1]);
                eprintln!("Use --help for usage information");
                std::process::exit(1);
            }
        }
    }

    // Execute the clear command based on OS
    let status = if cfg!(target_os = "windows") {
        Command::new("cmd")
            .args(["/C", "cls"])
            .status()
    } else {
        Command::new("clear")
            .status()
    };

    // Handle any errors
    if let Err(e) = status {
        eprintln!("Failed to clear screen: {}", e);
        std::process::exit(1);
    }
}
