//! Compile `src/*.vlt` into `OUT_DIR` with Voltaic as a library, so the crate
//! builds with plain `cargo build` / buildRustPackage and no `voltaic` binary.
//! Adapted from Voltaic's `examples/cargo-project/build.rs`.

fn main() {
    let out = std::env::var("OUT_DIR").expect("cargo sets OUT_DIR for a build script");

    match voltaic_driver::compile_dir("src".as_ref(), out.as_ref()) {
        Ok(compiled) => {
            for directive in compiled.rerun_directives() {
                println!("{directive}");
            }
            // A `.vlt` added or removed is not covered by the per-file directives.
            println!("cargo::rerun-if-changed=src");
        }
        Err(diagnostics) => {
            eprint!("{}", voltaic_diag::render(&diagnostics, true));
            // Fail here, with the Voltaic error, not later at a missing include!.
            std::process::exit(1);
        }
    }
}
