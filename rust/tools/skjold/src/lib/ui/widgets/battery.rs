//! Battery status widget.

use iced::widget::{row, text};
use iced::{Color, Element};

use crate::domain::BatteryStatus;

/// Render battery status as a widget.
pub fn battery_widget<'a, Message: 'a>(status: &BatteryStatus) -> Element<'a, Message> {
    if !status.present {
        // No battery - show nothing or "AC"
        return text("AC").size(14).into();
    }

    // Battery icon using Nerd Font glyphs
    let icon = match (status.charging, status.percentage) {
        (true, _) => "\u{f0084}",        // nf-md-battery_charging
        (false, 0..=10) => "\u{f007a}",  // nf-md-battery_10
        (false, 11..=20) => "\u{f007b}", // nf-md-battery_20
        (false, 21..=30) => "\u{f007c}", // nf-md-battery_30
        (false, 31..=40) => "\u{f007d}", // nf-md-battery_40
        (false, 41..=50) => "\u{f007e}", // nf-md-battery_50
        (false, 51..=60) => "\u{f007f}", // nf-md-battery_60
        (false, 61..=70) => "\u{f0080}", // nf-md-battery_70
        (false, 71..=80) => "\u{f0081}", // nf-md-battery_80
        (false, 81..=90) => "\u{f0082}", // nf-md-battery_90
        (false, _) => "\u{f0079}",       // nf-md-battery - full
    };

    // Color based on level
    let color = match status.percentage {
        0..=20 => Color::from_rgb(0.98, 0.29, 0.20), // Red - low
        21..=50 => Color::from_rgb(0.98, 0.74, 0.18), // Yellow - medium
        _ if status.charging => Color::from_rgb(0.72, 0.73, 0.15), // Green - charging
        _ => Color::from_rgb(0.92, 0.86, 0.70),      // Gruvbox fg
    };

    row![
        text(icon).size(16).color(color),
        text(format!("{}%", status.percentage))
            .size(14)
            .color(color),
    ]
    .spacing(4)
    .into()
}
