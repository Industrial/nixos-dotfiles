//! Workspaces indicator widget - minimal dot style.

use iced::widget::{button, row, text};
use iced::{Color, Element};

use crate::domain::Workspace;

/// Render workspaces as minimal clickable dots.
/// Style: ● active, ● occupied (dimmed), ○ empty
pub fn workspaces_widget<'a, Message: Clone + 'a>(
    workspaces: &[Workspace],
    active_id: Option<i32>,
    on_switch: impl Fn(i32) -> Message + 'a,
) -> Element<'a, Message> {
    let active_color = Color::from_rgb(0.92, 0.86, 0.70); // Gruvbox fg - bright
    let occupied_color = Color::from_rgb(0.60, 0.56, 0.46); // Gruvbox fg dimmed
    let empty_color = Color::from_rgb(0.35, 0.35, 0.35); // Dim gray

    // Show workspaces 1-5 always, plus any occupied beyond that
    let max_static = 5;
    let mut ws_to_show: Vec<i32> = (1..=max_static).collect();

    // Add any occupied workspaces beyond the static range
    for ws in workspaces {
        if ws.id > max_static && ws.windows > 0 && !ws_to_show.contains(&ws.id) {
            ws_to_show.push(ws.id);
        }
    }
    ws_to_show.sort();

    // Build dots for each workspace
    let dots: Vec<Element<Message>> = ws_to_show
        .iter()
        .map(|&ws_id| {
            let ws = workspaces.iter().find(|w| w.id == ws_id);
            let is_active = active_id == Some(ws_id);
            let has_windows = ws.map(|w| w.windows > 0).unwrap_or(false);

            // Choose dot and color based on state
            let (dot, color) = if is_active {
                ("●", active_color) // Filled, bright
            } else if has_windows {
                ("●", occupied_color) // Filled, dim
            } else {
                ("○", empty_color) // Empty outline
            };

            button(text(dot).size(10).color(color))
                .padding([4, 3])
                .style(move |_theme: &iced::Theme, status| {
                    let bg = match status {
                        iced::widget::button::Status::Hovered => Some(iced::Background::Color(
                            Color::from_rgba(1.0, 1.0, 1.0, 0.1),
                        )),
                        iced::widget::button::Status::Pressed => Some(iced::Background::Color(
                            Color::from_rgba(1.0, 1.0, 1.0, 0.15),
                        )),
                        _ => None,
                    };
                    iced::widget::button::Style {
                        background: bg,
                        text_color: color,
                        border: iced::Border {
                            color: Color::TRANSPARENT,
                            width: 0.0,
                            radius: 8.0.into(),
                        },
                        shadow: iced::Shadow::default(),
                        snap: false,
                    }
                })
                .on_press(on_switch(ws_id))
                .into()
        })
        .collect();

    row(dots).spacing(2).into()
}
