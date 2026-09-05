//! Window list/taskbar widget.

use iced::widget::{button, row, text, tooltip};
use iced::{Alignment, Color, Element};

use crate::domain::WindowInfo;

/// Render a taskbar showing windows on the current workspace.
pub fn window_list_widget<'a, Message: Clone + 'a>(
    windows: &'a [WindowInfo],
    on_focus: impl Fn(String) -> Message + 'a,
) -> Element<'a, Message> {
    let focused_bg = Color::from_rgb(0.28, 0.28, 0.28); // Gruvbox bg2
    let normal_bg = Color::TRANSPARENT;
    let focused_color = Color::from_rgb(0.98, 0.73, 0.01); // Gruvbox yellow
    let normal_color = Color::from_rgb(0.92, 0.86, 0.70); // Gruvbox fg

    if windows.is_empty() {
        return text("").into();
    }

    let buttons: Vec<Element<'a, Message>> = windows
        .iter()
        .map(|window| {
            let address = window.address.clone();
            let (bg_color, fg_color) = if window.focused {
                (focused_bg, focused_color)
            } else {
                (normal_bg, normal_color)
            };

            // Use class name as short label, full title in tooltip
            let label = if window.class.is_empty() {
                window.title.chars().take(15).collect::<String>()
            } else {
                window.class.chars().take(12).collect::<String>()
            };

            let btn = button(text(label).size(12).color(fg_color))
                .padding([4, 8])
                .style(move |_theme, status| {
                    let background = match status {
                        iced::widget::button::Status::Hovered => {
                            Some(Color::from_rgb(0.32, 0.32, 0.32).into())
                        }
                        _ => Some(bg_color.into()),
                    };
                    iced::widget::button::Style {
                        background,
                        text_color: fg_color,
                        border: iced::Border::default().rounded(4),
                        ..Default::default()
                    }
                })
                .on_press(on_focus(address));

            tooltip(btn, text(&window.title).size(11), tooltip::Position::Bottom).into()
        })
        .collect();

    row(buttons).spacing(4).align_y(Alignment::Center).into()
}
