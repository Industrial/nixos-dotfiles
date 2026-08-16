use std::process::Command;

use clap::Parser;
use nixos_update_notifier::{CheckOutcome, Config, SystemNotifier, default_flake_dir, run_check};

fn main() {
    let mut config = Config::parse();
    apply_hostname_default(&mut config);
    apply_flake_default(&mut config);

    let mut notifier = SystemNotifier;
    match run_check(&config, &mut notifier) {
        Ok(CheckOutcome::UpToDate) => {
            println!("nixos-update-notifier: system flake lock is up to date");
        }
        Ok(CheckOutcome::LockChangedNoPackageDiff) => {
            println!(
                "nixos-update-notifier: flake.lock would change, but no package-level diff vs {}",
                config.current_system.display()
            );
        }
        Ok(CheckOutcome::LockUpdatesPending { reason, payloads }) => {
            println!("nixos-update-notifier: updates pending ({reason})");
            for p in &payloads {
                println!("--- {} ---\n{}", p.summary, p.body);
            }
        }
        Ok(CheckOutcome::PackageUpdates { changes, payloads }) => {
            println!(
                "nixos-update-notifier: {} package(s) would update:",
                changes.len()
            );
            for c in &changes {
                println!("  {c}");
            }
            for p in &payloads {
                eprintln!("notified: {}", p.summary);
            }
        }
        Err(e) => {
            eprintln!("nixos-update-notifier: {e}");
            std::process::exit(1);
        }
    }
}

fn apply_hostname_default(config: &mut Config) {
    if !config.hostname.is_empty() {
        return;
    }
    if let Ok(h) = hostname_from_uname() {
        config.hostname = h;
    }
}

fn apply_flake_default(config: &mut Config) {
    if config.flake.as_os_str().is_empty() {
        let home = std::env::var("HOME").unwrap_or_else(|_| "/home/tom".into());
        config.flake = default_flake_dir(&home, &config.hostname);
    }
}

fn hostname_from_uname() -> Result<String, std::io::Error> {
    let out = Command::new("uname").arg("-n").output()?;
    if !out.status.success() {
        return Err(std::io::Error::other("uname -n failed"));
    }
    Ok(String::from_utf8_lossy(&out.stdout).trim().to_string())
}
