//! The package-index generator (`modsys::index::cli`).

fn main() {
    if let Err(e) = modsys::index::cli() {
        eprintln!("gen-index: {e}");
        std::process::exit(1);
    }
}
