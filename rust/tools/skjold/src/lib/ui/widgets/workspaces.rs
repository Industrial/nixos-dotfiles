//! Workspaces indicator widget.

use iced::widget::{button, row, text};
use iced::{Color, Element};

use crate::domain::Workspace;

/// Render workspaces as a row of clickable indicators.
pub fn workspaces_widget<'a, Message: Clone + 'a>(
    workspaces: &[Workspace],
    active_id: Option<i32>,
    on_switch: impl Fn(i32) -> Message + 'a,
) -> Element<'a, Message> {
    let active_color = Color::from_rgb(0.56, 0.75, 0.49); // Gruvbox green
    let occupied_color = Color::from_rgb(0.80, 0.74, 0.58); // Gruvbox fg dimmed
    let empty_color = Color::from_rgb(0.40, 0.40, 0.40); // Dim gray

    // Sort workspaces by ID for consistent display
    let mut sorted: Vec<_> = workspaces.iter().collect();
    sorted.sort_by_key(|w| w.id);

    // Build buttons for each workspace
    let buttons: Vec<Element<Message>> = sorted
        .iter()
        .map(|ws| {
            let is_active = active_id == Some(ws.id);
            let has_windows = ws.windows > 0;

            // Choose color based on state
            let color = if is_active {
                active_color
            } else if has_windows {
                occupied_color
            } else {
                empty_color
            };

            // Use filled circle for active, empty for others
            let indicator = if is_active { "●" } else { "○" };

            // Build button with workspace number/name
            let label = if ws.name.starts_with("special:") {
                // Special workspace - show icon
                "󰆴".to_string() // nf-md-dock_window
            } else {
                ws.id.to_string()
            };

            button(
                row![
                    text(indicator).size(8).color(color),
                    text(label).size(12).color(color),
                ]
                .spacing(2)
                .align_y(iced::Alignment::Center),
            )
            .padding([2, 6])
            .style(move |_theme: &iced::Theme, status| {
                let bg = match status {
                    iced::widget::button::Status::Hovered => Some(iced::Background::Color(
                        Color::from_rgba(0.3, 0.3, 0.3, 0.5),
                    )),
                    iced::widget::button::Status::Pressed => Some(iced::Background::Color(
                        Color::from_rgba(0.4, 0.4, 0.4, 0.5),
                    )),
                    _ => None,
                };
                iced::widget::button::Style {
                    background: bg,
                    text_color: color,
                    border: iced::Border {
                        color: Color::TRANSPARENT,
                        width: 0.0,
                        radius: 4.0.into(),
                    },
                    shadow: iced::Shadow::default(),
                    snap: false,
                }
            })
            .on_press(on_switch(ws.id))
            .into()
        })
        .collect();

    row(buttons).spacing(2).into()
}
