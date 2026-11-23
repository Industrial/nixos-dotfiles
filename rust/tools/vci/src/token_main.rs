//! Entry point of vci-token (GH-247): the GitHub App installation token vci
//! posts its statuses with. The program is `src/token.vlt`.
fn main() -> std::process::ExitCode {
    vci::token::main_code()
}
