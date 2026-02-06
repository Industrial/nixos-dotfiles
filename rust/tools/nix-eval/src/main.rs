use anyhow::Result;
use clap::Parser;
use nix_eval::Evaluator;
use serde_json;
use std::fs;
use std::io::{self, Read};

/// A pure Rust Nix expression evaluator
#[derive(Parser, Debug)]
#[command(author, version, about, long_about = None)]
struct Args {
    /// Nix expression to evaluate (or file path if --file is used)
    #[arg(value_name = "EXPRESSION")]
    expression: Option<String>,

    /// Read expression from file instead of command line
    #[arg(short, long)]
    file: bool,

    /// Output format: nix (default), json
    #[arg(short, long, default_value = "nix")]
    format: String,
}

fn main() -> Result<()> {
    let args = Args::parse();

    // Get the Nix expression to evaluate
    let expr = if args.file {
        // Read from file
        let path = args
            .expression
            .ok_or_else(|| anyhow::anyhow!("File path required when using --file"))?;
        fs::read_to_string(&path)?
    } else if let Some(expr) = args.expression {
        // Use provided expression
        expr
    } else {
        // Read from stdin
        let mut buffer = String::new();
        io::stdin().read_to_string(&mut buffer)?;
        buffer
    };

    // Create evaluator and evaluate
    let evaluator = Evaluator::new();
    let value = evaluator
        .evaluate(&expr)
        .map_err(|e| anyhow::anyhow!("{}", e))?;

    // Output the result
    match args.format.as_str() {
        "json" => {
            println!("{}", serde_json::to_string_pretty(&value)?);
        }
        "nix" => {
            println!("{}", value);
        }
        _ => {
            return Err(anyhow::anyhow!("Unsupported format: {}", args.format));
        }
    }

    Ok(())
}
