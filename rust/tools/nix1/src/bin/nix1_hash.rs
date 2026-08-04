//! `nix1-hash` — 1:1 CLI surface with stock `nix-hash`.

use std::path::PathBuf;
use std::process::ExitCode;

use clap::Parser;

use nix1::{
    CRATE_VERSION, Encoding, HashAlgo, HashError, run_convert, run_hash_paths,
};

#[derive(Debug, Parser)]
#[command(
    name = "nix1-hash",
    version = CRATE_VERSION,
    about = "compute the cryptographic hash of a path (Rust; 1:1 with nix-hash)",
    disable_help_subcommand = true
)]
struct Cli {
    /// Compute hashes of the specified files (and not of their NAR serialisations)
    #[arg(long)]
    flat: bool,

    /// Print hash in hexadecimal (default)
    #[arg(long)]
    base16: bool,

    /// Print hash in base-32 format
    #[arg(long)]
    base32: bool,

    /// Print hash in base-64 format
    #[arg(long)]
    base64: bool,

    /// Print hash in SRI format
    #[arg(long)]
    sri: bool,

    /// Truncate hashes longer than 160 bits
    #[arg(long)]
    truncate: bool,

    /// Hash algorithm: blake3, md5, sha1, sha256, sha512 (default: md5)
    #[arg(long = "type", value_name = "hashAlgo")]
    hash_type: Option<String>,

    /// Convert the base-32 hash representation to hexadecimal
    #[arg(long = "to-base16")]
    to_base16: bool,

    /// Convert the hexadecimal hash representation to base-32
    #[arg(long = "to-base32")]
    to_base32: bool,

    /// Convert the hexadecimal hash representation to base-64
    #[arg(long = "to-base64")]
    to_base64: bool,

    /// Convert the hexadecimal hash representation to SRI
    #[arg(long = "to-sri")]
    to_sri: bool,

    /// Paths to hash, or hash strings when using --to-*
    #[arg(value_name = "PATH_OR_HASH")]
    args: Vec<String>,
}

fn encoding_from_flags(cli: &Cli) -> Result<Encoding, HashError> {
    let flags = [cli.base16, cli.base32, cli.base64, cli.sri]
        .into_iter()
        .filter(|&x| x)
        .count();
    if flags > 1 {
        return Err(HashError::msg(
            "only one of --base16, --base32, --base64, --sri may be specified",
        ));
    }
    Ok(if cli.base32 {
        Encoding::Base32
    } else if cli.base64 {
        Encoding::Base64
    } else if cli.sri {
        Encoding::Sri
    } else {
        Encoding::Base16
    })
}

fn convert_target(cli: &Cli) -> Result<Option<Encoding>, HashError> {
    let flags = [cli.to_base16, cli.to_base32, cli.to_base64, cli.to_sri]
        .into_iter()
        .filter(|&x| x)
        .count();
    if flags > 1 {
        return Err(HashError::msg(
            "only one of --to-base16, --to-base32, --to-base64, --to-sri may be specified",
        ));
    }
    Ok(if cli.to_base16 {
        Some(Encoding::Base16)
    } else if cli.to_base32 {
        Some(Encoding::Base32)
    } else if cli.to_base64 {
        Some(Encoding::Base64)
    } else if cli.to_sri {
        Some(Encoding::Sri)
    } else {
        None
    })
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match run(cli) {
        Ok(lines) => {
            for line in lines {
                println!("{line}");
            }
            ExitCode::SUCCESS
        }
        Err(e) => {
            eprintln!("{e}");
            ExitCode::from(1)
        }
    }
}

fn run(cli: Cli) -> Result<Vec<String>, HashError> {
    let algo = match cli.hash_type.as_deref() {
        None => HashAlgo::Md5,
        Some(s) => HashAlgo::parse(s).map_err(HashError::msg)?,
    };

    if let Some(to) = convert_target(&cli)? {
        if cli.args.is_empty() {
            return Err(HashError::msg("no hashes specified"));
        }
        return run_convert(&cli.args, algo, to);
    }

    if cli.args.is_empty() {
        return Err(HashError::msg("no paths specified"));
    }

    let encoding = encoding_from_flags(&cli)?;
    let paths: Vec<PathBuf> = cli.args.iter().map(PathBuf::from).collect();
    run_hash_paths(&paths, algo, cli.flat, cli.truncate, encoding)
}
