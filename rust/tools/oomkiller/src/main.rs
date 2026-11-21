//! Entry point. The program is `src/live.vlt`'s `start`: the daemon on the
//! live environment, run by id_effect_cli's `run_main`, which owns the exit code.
fn main() -> std::process::ExitCode {
    oomkiller::live::start()
}
