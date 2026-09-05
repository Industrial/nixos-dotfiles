//! System tray widget for Skjold.

use iced::Element;
use iced::widget::{Row, button, container, text, tooltip};

use crate::domain::{TrayItem, TrayStatus};

/// Create a system tray widget.
///
/// Shows icons for each registered tray item. Clicking activates the item.
pub fn system_tray_widget<'a, Message: Clone + 'a>(
    items: &'a [TrayItem],
    on_activate: impl Fn(String, String) -> Message + 'a,
) -> Element<'a, Message> {
    if items.is_empty() {
        return container(text("")).into();
    }

    let mut tray_row: Vec<Element<'a, Message>> = Vec::new();

    for item in items.iter().filter(|i| i.status != TrayStatus::Passive) {
        let bus_name = item.bus_name.clone();
        let object_path = item.object_path.clone();

        // Icon: use icon_name if available, otherwise fallback to a generic icon
        let icon_text = if let Some(ref icon) = item.icon_name {
            // Try to map common icon names to Nerd Font icons
            match icon.as_str() {
                "discord" | "discord-tray" => "\u{f392}",   // nf-fa-discord
                "spotify" | "spotify-client" => "\u{f1bc}", // nf-fa-spotify
                "telegram" | "telegram-desktop" => "\u{f2c6}", // nf-fa-telegram
                "signal" => "\u{f086}",                     // nf-fa-comments
                "steam" => "\u{f1b6}",                      // nf-fa-steam
                "dropbox" => "\u{f16b}",                    // nf-fa-dropbox
                "network" | "nm-applet" => "\u{f1eb}",      // nf-fa-wifi
                "bluetooth" => "\u{f294}",                  // nf-fa-bluetooth_b
                "volume" | "audio" => "\u{f028}",           // nf-fa-volume_up
                _ => "\u{f111}",                            // nf-fa-circle (generic)
            }
        } else {
            "\u{f111}" // nf-fa-circle
        };

        let btn = button(text(icon_text).size(14))
            .padding(4)
            .style(iced::widget::button::text)
            .on_press(on_activate(bus_name, object_path));

        let tooltip_text = if item.title.is_empty() {
            item.id.clone()
        } else {
            item.title.clone()
        };

        tray_row.push(tooltip(btn, text(tooltip_text).size(12), tooltip::Position::Bottom).into());
    }

    if tray_row.is_empty() {
        container(text("")).into()
    } else {
        Row::with_children(tray_row).spacing(4).into()
    }
}
