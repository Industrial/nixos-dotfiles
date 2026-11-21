//! Entry point. The daemon is `src/daemon.vlt`; its decisions are `src/policy.vlt`.
fn main() {
    oomkiller::daemon::run();
}
