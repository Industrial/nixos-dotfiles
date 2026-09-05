//! Event log widget — displays deployment and system events.

use iced::widget::{Space, column, container, scrollable, text};
use iced::{Color, Element, Length};

use crate::domain::{DeploymentEvent, EventSeverity};

/// Create the event log widget.
pub fn event_log_widget<'a, Message: 'a>(events: &[DeploymentEvent]) -> Element<'a, Message> {
    let header = text("EVENTS").size(14);

    let event_list: Element<'a, Message> = if events.is_empty() {
        text("No events").size(12).into()
    } else {
        let items: Vec<Element<'a, Message>> = events
            .iter()
            .rev() // Most recent first
            .take(10) // Show last 10
            .map(|event| event_row(event))
            .collect();

        scrollable(column(items).spacing(4))
            .height(Length::Fixed(150.0))
            .into()
    };

    let content = column![header, Space::new().height(8), event_list,]
        .padding(12)
        .width(Length::Fill);

    container(content).style(log_style).into()
}

/// A single event row.
fn event_row<'a, Message: 'a>(event: &DeploymentEvent) -> Element<'a, Message> {
    let color = match event.severity {
        EventSeverity::Info => Color::from_rgb(0.6, 0.6, 0.6),
        EventSeverity::Success => Color::from_rgb(0.2, 0.8, 0.2),
        EventSeverity::Warning => Color::from_rgb(0.8, 0.6, 0.2),
        EventSeverity::Error => Color::from_rgb(0.8, 0.2, 0.2),
    };

    let timestamp = event.timestamp.format("%H:%M").to_string();

    text(format!(
        "{} {} {} {}",
        timestamp,
        event.severity.icon(),
        event.host,
        event.message
    ))
    .size(11)
    .color(color)
    .into()
}

/// Event log container style.
fn log_style(_theme: &iced::Theme) -> container::Style {
    container::Style {
        background: Some(Color::from_rgb(0.08, 0.08, 0.1).into()),
        border: iced::Border {
            color: Color::from_rgb(0.2, 0.2, 0.25),
            width: 1.0,
            radius: 4.0.into(),
        },
        ..Default::default()
    }
}
