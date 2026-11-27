//! `nixos-users`: print the generated users/groups JSON. Regenerate the committed file with
//!
//!     cargo run -q > ../../../features/nixos/users/voltaic.json
//!
//! The evaluation is a pure Effect (R = HNil); printing its result is the only IO here.

// The binary is the IO edge: it prints, which the configuration fence forbids in the
// library.
#![allow(clippy::disallowed_methods)]

fn main() {
    match nixos_users::generate::generated().block_on() {
        id_effect::Exit::Success(text) => print!("{text}"),
        id_effect::Exit::Failure(cause) => {
            eprintln!("nixos-users: {cause:?}");
            std::process::exit(1);
        }
    }
}
