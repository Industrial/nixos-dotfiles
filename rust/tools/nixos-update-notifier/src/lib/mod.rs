mod build;
mod config;
mod diff;
mod format;
mod lock;
mod notify;
mod run;

pub use config::Config;
pub use diff::{PackageChange, parse_diff_closures};
pub use format::{chunk_package_lines, format_notification_bodies, format_package_line};
pub use notify::{NotificationPayload, Notifier, SystemNotifier, payloads_for_updates};
pub use run::{CheckOutcome, default_flake_dir, run_check};
