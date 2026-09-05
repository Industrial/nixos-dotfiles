//! Thermal sensor widget.

use iced::widget::{row, text};
use iced::{Color, Element};

use crate::domain::ThermalSensors;

/// Render thermal sensors as a widget.
pub fn thermal_widget<'a, Message: 'a>(sensors: &ThermalSensors) -> Element<'a, Message> {
    let Some(temp) = sensors.cpu_temp_celsius else {
        // No temperature sensor available
        return text("").into();
    };

    // Thermometer icon using Nerd Font glyph
    let icon = "\u{f2c8}"; // nf-fa-thermometer_half

    // Color based on temperature
    let color = match temp as u8 {
        0..=60 => Color::from_rgb(0.92, 0.86, 0.70), // Gruvbox fg - normal
        61..=80 => Color::from_rgb(0.98, 0.74, 0.18), // Yellow - warm
        _ => Color::from_rgb(0.98, 0.29, 0.20),      // Red - hot
    };

    row![
        text(icon).size(14).color(color),
        text(format!("{:.0}°C", temp)).size(14).color(color),
    ]
    .spacing(4)
    .into()
}
