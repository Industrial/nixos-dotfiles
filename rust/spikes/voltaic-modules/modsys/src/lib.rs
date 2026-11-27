//! S1b spike for #417: what Voltaic 0.3.0 can express for a typed,
//! NixOS-style module system. The source is Voltaic (`src/*.vlt`); build.rs
//! compiles it into `OUT_DIR`. See docs/research/417/s1b-voltaic-feature-check.md.

// The allows are on the shape of Voltaic's emitted code, not on decisions in
// the source (see rust/tools/vgc/src/lib.rs).
#![allow(
    // Voltaic 0.3.0 has no `^=`, so drv.vlt writes `x := x ^ y`.
    clippy::assign_op_pattern,
    clippy::just_underscores_and_digits,
    clippy::redundant_closure,
    clippy::type_complexity
)]

pub mod option {
    include!(concat!(env!("OUT_DIR"), "/option.rs"));
}

pub mod eval {
    include!(concat!(env!("OUT_DIR"), "/eval.rs"));
}

pub mod lazy {
    include!(concat!(env!("OUT_DIR"), "/lazy.rs"));
}

pub mod pure {
    include!(concat!(env!("OUT_DIR"), "/pure.rs"));
}

pub mod drv {
    include!(concat!(env!("OUT_DIR"), "/drv.rs"));
}

pub mod index {
    include!(concat!(env!("OUT_DIR"), "/index.rs"));
}

#[cfg(test)]
mod tests {
    include!(concat!(env!("OUT_DIR"), "/tests.rs"));
}
