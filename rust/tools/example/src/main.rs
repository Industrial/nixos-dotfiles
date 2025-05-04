use anyhow::Result;
use clap::Parser;
use utils::logging::{LogLevel, init_logging};

/// A simple example CLI tool that follows Unix philosophy
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Input file to process
    #[arg(short, long)]
    input: Option<String>,

    /// Output file (defaults to stdout)
    #[arg(short, long)]
    output: Option<String>,

    /// Verbose output
    #[arg(short, long)]
    verbose: bool,
}

#[tokio::main]
async fn main() -> Result<()> {
    // Parse command line arguments
    let args = Args::parse();

    // Initialize logging
    init_logging()?;

    // Process input
    let input = match args.input {
        Some(path) => std::fs::read_to_string(path)?,
        None => {
            let mut buffer = String::new();
            std::io::stdin().read_line(&mut buffer)?;
            buffer
        }
    };

    // Process the input (example: convert to uppercase)
    let output = input.to_uppercase();

    // Output the result
    match args.output {
        Some(path) => std::fs::write(path, output)?,
        None => println!("{}", output),
    }

    if args.verbose {
        utils::logging::log(LogLevel::Info, "Processing completed successfully");
    }

    Ok(())
}
