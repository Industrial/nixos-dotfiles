//! Skjold — Hyprland panel shell.
//!
//! A native Rust panel for Hyprland built with id_effect and Iced.

use skjold::providers::live_providers;
use skjold::ui::SkjoldApp;

fn main() -> iced::Result {
    let (hyprland, time_service) = live_providers();

    iced::application("Skjold", SkjoldApp::update, SkjoldApp::view)
        .subscription(SkjoldApp::subscription)
        .theme(SkjoldApp::theme)
        .run_with(move || SkjoldApp::new(hyprland, time_service))
}
