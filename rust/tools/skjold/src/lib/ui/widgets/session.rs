//! Session/power menu widget.

use iced::widget::{button, column, container, row, text};
use iced::{Color, Element, Length};

use crate::domain::SessionAction;

/// Render the session menu button.
/// When expanded, shows all session actions.
pub fn session_widget<'a, Message: Clone + 'a>(
    expanded: bool,
    on_toggle: Message,
    on_action: impl Fn(SessionAction) -> Message + 'a,
) -> Element<'a, Message> {
    // Power icon
    let icon = "\u{f0425}"; // nf-md-power
    let color = Color::from_rgb(0.92, 0.86, 0.70); // Gruvbox fg

    let toggle_button = button(text(icon).size(14).color(color))
        .padding(4)
        .style(iced::widget::button::text)
        .on_press(on_toggle);

    if !expanded {
        return toggle_button.into();
    }

    // Build expanded menu
    let actions: Vec<Element<Message>> = SessionAction::all()
        .iter()
        .map(|&action| {
            let action_color = match action {
                SessionAction::Shutdown => Color::from_rgb(0.98, 0.29, 0.20), // Red
                SessionAction::Reboot => Color::from_rgb(0.98, 0.74, 0.18),   // Yellow
                _ => color,
            };

            button(
                row![
                    text(action.icon()).size(12).color(action_color),
                    text(action.label()).size(12).color(action_color),
                ]
                .spacing(4),
            )
            .padding(4)
            .width(Length::Fill)
            .style(iced::widget::button::text)
            .on_press(on_action(action))
            .into()
        })
        .collect();

    let menu = container(column(actions).spacing(2).padding(4)).style(|_theme: &iced::Theme| {
        container::Style {
            background: Some(iced::Background::Color(Color::from_rgba(
                0.16, 0.16, 0.16, 0.95,
            ))),
            border: iced::Border {
                color: Color::from_rgb(0.3, 0.3, 0.3),
                width: 1.0,
                radius: 4.0.into(),
            },
            ..Default::default()
        }
    });

    column![toggle_button, menu].spacing(4).into()
}
