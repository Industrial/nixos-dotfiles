mod build;
mod config;
mod diff;
mod format;
mod lock;
mod notify;
mod pending;
mod run;

pub use config::{Config, Differ};
pub use diff::{PackageChange, VDIFF_SCHEMA, parse_diff_closures, parse_vdiff_json};
pub use format::{chunk_package_lines, format_notification_bodies, format_package_line};
pub use notify::{NotificationPayload, Notifier, SystemNotifier, payloads_for_updates};
pub use pending::{Pending, parse_pull_urls, pending_payloads, reboot_differences};
pub use run::{CheckOutcome, CheckReport, default_flake_dir, run_check};
