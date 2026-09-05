//! Application launcher overlay widget.

use iced::widget::{Column, Space, button, column, container, row, scrollable, text, text_input};
use iced::{Color, Element, Length};

use crate::domain::{LauncherEntry, LauncherState};

/// Render the launcher overlay.
/// Returns a full-screen overlay with search input and results list.
pub fn launcher_widget<'a, Message: Clone + 'a>(
    state: &LauncherState,
    entries: &'a [LauncherEntry],
    on_query_change: impl Fn(String) -> Message + 'a,
    on_select: impl Fn(usize) -> Message + 'a,
    on_close: Message,
) -> Element<'a, Message> {
    if !state.visible {
        return container(text("")).into();
    }

    // Search input
    let search = text_input("Search applications...", &state.query)
        .on_input(on_query_change)
        .padding(12)
        .size(18)
        .width(Length::Fill);

    // Results list
    let results: Vec<Element<Message>> = state
        .filtered
        .iter()
        .enumerate()
        .take(10) // Show top 10 results
        .map(|(i, &entry_idx)| {
            let entry = &entries[entry_idx];
            let is_selected = i == state.selected;

            let bg_color = if is_selected {
                Color::from_rgba(0.27, 0.52, 0.53, 0.3) // Gruvbox blue highlight
            } else {
                Color::TRANSPARENT
            };

            let name_color = if is_selected {
                Color::from_rgb(0.98, 0.74, 0.18) // Gruvbox yellow
            } else {
                Color::from_rgb(0.92, 0.86, 0.70) // Gruvbox fg
            };

            let subtitle_color = Color::from_rgb(0.66, 0.60, 0.52); // Gruvbox gray

            let content = column![
                text(&entry.name).size(16).color(name_color),
                text(entry.subtitle().unwrap_or(""))
                    .size(12)
                    .color(subtitle_color),
            ]
            .spacing(2);

            button(content)
                .width(Length::Fill)
                .padding(8)
                .style(move |_theme, _status| button::Style {
                    background: Some(iced::Background::Color(bg_color)),
                    text_color: name_color,
                    border: iced::Border::default(),
                    shadow: iced::Shadow::default(),
                    snap: false,
                })
                .on_press(on_select(entry_idx))
                .into()
        })
        .collect();

    let results_list = scrollable(Column::with_children(results).spacing(4))
        .height(Length::FillPortion(1))
        .width(Length::Fill);

    // Close button
    let close_btn = button(text("\u{f0156}").size(20)) // nf-md-close
        .padding(8)
        .style(iced::widget::button::text)
        .on_press(on_close);

    // Header with close button
    let header = row![
        text("Applications")
            .size(14)
            .color(Color::from_rgb(0.66, 0.60, 0.52)),
        Space::new().width(Length::Fill),
        close_btn,
    ]
    .spacing(8)
    .padding(8);

    // Main content
    let content = column![header, search, results_list]
        .spacing(8)
        .padding(16)
        .width(Length::Fixed(500.0))
        .height(Length::Fixed(400.0));

    // Centered overlay with dark background
    let overlay = container(content).style(|_theme| container::Style {
        background: Some(iced::Background::Color(Color::from_rgba(
            0.16, 0.16, 0.16, 0.98,
        ))),
        border: iced::Border {
            color: Color::from_rgb(0.3, 0.3, 0.3),
            width: 1.0,
            radius: 8.0.into(),
        },
        ..Default::default()
    });

    // Full-screen container to center the overlay
    container(overlay)
        .width(Length::Fill)
        .height(Length::Fill)
        .center_x(Length::Fill)
        .center_y(Length::Fill)
        .style(|_theme| container::Style {
            background: Some(iced::Background::Color(Color::from_rgba(
                0.0, 0.0, 0.0, 0.5,
            ))),
            ..Default::default()
        })
        .into()
}
