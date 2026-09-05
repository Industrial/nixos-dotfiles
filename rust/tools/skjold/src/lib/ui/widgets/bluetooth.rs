//! Bluetooth status widget.

use iced::widget::{button, text};
use iced::{Color, Element};

use crate::domain::BluetoothState;

/// Render Bluetooth status as a widget.
/// Returns the widget and optionally a message to toggle power.
pub fn bluetooth_widget<'a, Message: Clone + 'a>(
    state: &BluetoothState,
    on_toggle: Message,
) -> Element<'a, Message> {
    if !state.available {
        // No Bluetooth adapter
        return text("").into();
    }

    // Bluetooth icon using Nerd Font glyphs
    let icon = if state.powered {
        if state.connected_devices.is_empty() {
            "\u{f00af}" // nf-md-bluetooth (on, not connected)
        } else {
            "\u{f00b1}" // nf-md-bluetooth_connect (connected)
        }
    } else {
        "\u{f00b2}" // nf-md-bluetooth_off
    };

    // Color based on state
    let color = if !state.powered {
        Color::from_rgb(0.66, 0.60, 0.52) // Gruvbox gray - off
    } else if state.connected_devices.is_empty() {
        Color::from_rgb(0.51, 0.65, 0.60) // Gruvbox aqua - on but not connected
    } else {
        Color::from_rgb(0.27, 0.52, 0.53) // Gruvbox blue - connected
    };

    // Build display text
    let label = if !state.connected_devices.is_empty() {
        format!("{} ({})", icon, state.connected_devices.len())
    } else {
        icon.to_string()
    };

    button(text(label).size(14).color(color))
        .padding(4)
        .style(iced::widget::button::text)
        .on_press(on_toggle)
        .into()
}
