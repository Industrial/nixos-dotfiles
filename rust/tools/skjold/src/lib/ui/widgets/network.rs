//! Network status widget.

use iced::widget::{row, text};
use iced::{Alignment, Color, Element};

use crate::domain::{NetworkState, NetworkType};

/// Render network status as an icon with optional connection name.
pub fn network_widget<'a, Message: Clone + 'a>(network: &'a NetworkState) -> Element<'a, Message> {
    let connected_color = Color::from_rgb(0.56, 0.75, 0.49); // Gruvbox green
    let disconnected_color = Color::from_rgb(0.92, 0.28, 0.28); // Gruvbox red
    let normal_color = Color::from_rgb(0.92, 0.86, 0.70); // Gruvbox fg

    // Choose icon based on connection type
    let (icon, color) = match network.network_type {
        NetworkType::Disconnected => ("\u{f0378}", disconnected_color), // nf-md-wifi_off
        NetworkType::Wireless => {
            let signal_icon = match network.signal_strength {
                Some(s) if s >= 75 => "\u{f0928}", // nf-md-wifi_strength_4
                Some(s) if s >= 50 => "\u{f0927}", // nf-md-wifi_strength_3
                Some(s) if s >= 25 => "\u{f0926}", // nf-md-wifi_strength_2
                Some(_) => "\u{f0925}",            // nf-md-wifi_strength_1
                None => "\u{f05a9}",               // nf-md-wifi
            };
            (
                signal_icon,
                if network.connected {
                    connected_color
                } else {
                    normal_color
                },
            )
        }
        NetworkType::Wired => {
            let icon = if network.connected {
                "\u{f059f}" // nf-md-ethernet
            } else {
                "\u{f0a39}" // nf-md-ethernet_cable_off
            };
            (
                icon,
                if network.connected {
                    connected_color
                } else {
                    disconnected_color
                },
            )
        }
        NetworkType::Vpn => ("\u{f0582}", connected_color), // nf-md-vpn
    };

    // Show connection name if available
    let label = network
        .connection_name
        .as_ref()
        .map(|s| s.as_str())
        .unwrap_or("");

    row![
        text(icon).size(14).color(color),
        text(label).size(12).color(normal_color),
    ]
    .spacing(4)
    .align_y(iced::Alignment::Center)
    .into()
}
