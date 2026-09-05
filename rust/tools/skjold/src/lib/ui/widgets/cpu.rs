//! CPU load widget.

use iced::widget::{row, text};
use iced::{Color, Element};

use crate::domain::CpuLoad;

/// Render CPU load as a widget.
pub fn cpu_widget<'a, Message: 'a>(load: &CpuLoad) -> Element<'a, Message> {
    // CPU icon using Nerd Font glyph
    let icon = "\u{f4bc}"; // nf-oct-cpu

    // Color based on load
    let color = match load.usage_percent as u8 {
        0..=50 => Color::from_rgb(0.92, 0.86, 0.70), // Gruvbox fg - normal
        51..=80 => Color::from_rgb(0.98, 0.74, 0.18), // Yellow - elevated
        _ => Color::from_rgb(0.98, 0.29, 0.20),      // Red - high
    };

    row![
        text(icon).size(14).color(color),
        text(format!("{:.0}%", load.usage_percent))
            .size(14)
            .color(color),
    ]
    .spacing(4)
    .into()
}
