//! S1b spike host: evaluate `hosts/muninn`'s modules at `R = HNil`, emit the
//! toplevel `.drv`, print its path and ATerm. `--write <dir>` also writes the
//! ATerm to `<dir>/<name>.drv` for comparison with Nix's.

#![allow(
    clippy::just_underscores_and_digits,
    clippy::redundant_closure,
    clippy::type_complexity
)]

pub mod pkgs {
    include!(concat!(env!("OUT_DIR"), "/pkgs.rs"));
}

pub mod modules {
    include!(concat!(env!("OUT_DIR"), "/modules.rs"));
}

pub mod host {
    include!(concat!(env!("OUT_DIR"), "/host.rs"));
}

pub mod toplevel {
    include!(concat!(env!("OUT_DIR"), "/toplevel.rs"));
}

fn main() {
    match toplevel::toplevel().block_on() {
        id_effect::Exit::Success(t) => {
            println!("host {} ({} packages)", t.host_name, t.packages);
            println!("{}", t.emitted.path);
            println!("{}", t.emitted.text);
        }
        id_effect::Exit::Failure(cause) => {
            eprintln!("evaluation failed: {cause:?}");
            std::process::exit(1);
        }
    }
}

#[cfg(test)]
mod oracle {
    include!(concat!(env!("OUT_DIR"), "/oracle.rs"));
}
