//! Notification widget for Skjold.

use iced::widget::{Column, button, column, container, row, text, tooltip};
use iced::{Element, Length};

use crate::domain::NotificationInfo;

/// Create a notification indicator widget.
///
/// Shows a bell icon with notification count. When there are notifications,
/// displays a badge with the count.
pub fn notification_widget<'a, Message: Clone + 'a>(
    notifications: &'a [NotificationInfo],
    on_dismiss: impl Fn(u32) -> Message + 'a,
    on_clear_all: Message,
) -> Element<'a, Message> {
    let count = notifications.len();

    // Bell icon (Nerd Font)
    let bell_icon = if count > 0 {
        "\u{f0f3}" // nf-fa-bell (filled)
    } else {
        "\u{f0a2}" // nf-fa-bell_o (outline)
    };

    // Create the indicator
    let indicator = if count > 0 {
        row![
            text(bell_icon).size(16),
            text(format!(" {}", count.min(99))).size(12),
        ]
    } else {
        row![text(bell_icon).size(16)]
    };

    // Build tooltip content with notification list
    let tooltip_content: Element<'a, Message> = if notifications.is_empty() {
        container(text("No notifications").size(12))
            .padding(8)
            .into()
    } else {
        let mut items: Vec<Element<'a, Message>> = Vec::new();

        // Add clear all button at top
        items.push(
            button(text("Clear all").size(10))
                .on_press(on_clear_all)
                .padding(4)
                .into(),
        );

        // Add each notification (most recent first, limit to 5)
        for notification in notifications.iter().rev().take(5) {
            let id = notification.id;
            let item = row![
                column![
                    text(&notification.summary).size(11),
                    text(&notification.app_name).size(9),
                ]
                .width(Length::Fill),
                button(text("\u{f00d}").size(10)) // nf-fa-close
                    .on_press(on_dismiss(id))
                    .padding(2),
            ]
            .spacing(4)
            .padding(4);

            items.push(item.into());
        }

        if count > 5 {
            items.push(text(format!("... and {} more", count - 5)).size(10).into());
        }

        container(Column::with_children(items).spacing(4))
            .padding(8)
            .width(Length::Fixed(200.0))
            .into()
    };

    tooltip(
        container(indicator).padding(4),
        tooltip_content,
        tooltip::Position::Bottom,
    )
    .into()
}
