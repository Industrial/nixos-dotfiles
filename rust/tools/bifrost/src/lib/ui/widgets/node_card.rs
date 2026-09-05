//! Node card widget — displays a single host's status and metrics.

use iced::widget::{Space, button, column, container, row, text};
use iced::{Alignment, Color, Element, Length};

use crate::domain::{Host, HostStatus, SystemMetrics};

/// Create a node card widget for a host.
pub fn node_card_widget<'a, Message: Clone + 'a>(
    host: &'a Host,
    on_deploy: Message,
) -> Element<'a, Message> {
    // Status indicator and label
    let status_color = match &host.status {
        HostStatus::Online { .. } => Color::from_rgb(0.2, 0.8, 0.2),
        HostStatus::Unreachable => Color::from_rgb(0.8, 0.2, 0.2),
        HostStatus::Deploying => Color::from_rgb(0.8, 0.8, 0.2),
        HostStatus::Degraded { .. } => Color::from_rgb(0.8, 0.5, 0.2),
        HostStatus::Unknown => Color::from_rgb(0.5, 0.5, 0.5),
    };

    let status_row = row![
        text(host.status.indicator()).size(16).color(status_color),
        text(host.status.label()).size(12),
    ]
    .spacing(4)
    .align_y(Alignment::Center);

    // Host name
    let name = text(&host.name).size(18);

    // Metrics display
    let metrics_display = if let Some(metrics) = &host.metrics {
        metrics_widget(metrics)
    } else {
        column![text("Loading...").size(12)].into()
    };

    // Generation info
    let gen_display = if let Some(generation) = &host.nixos_generation {
        column![
            text(format!("gen {}", generation.number)).size(12),
            text(&generation.nixos_version).size(10),
        ]
        .spacing(2)
    } else {
        column![text("—").size(12)]
    };

    // Deploy button
    let deploy_btn = button(text("Deploy").size(12))
        .padding([4, 8])
        .on_press(on_deploy);

    // Compose the card
    let content = column![
        name,
        status_row,
        Space::new().height(8),
        metrics_display,
        Space::new().height(8),
        gen_display,
        Space::new().height(8),
        deploy_btn,
    ]
    .spacing(4)
    .padding(12)
    .width(Length::Fixed(160.0));

    container(content).style(card_style).into()
}

/// Metrics display within a node card.
fn metrics_widget<'a, Message: 'a>(metrics: &SystemMetrics) -> Element<'a, Message> {
    let cpu_bar = metric_bar("CPU", metrics.cpu_percent);
    let mem_bar = metric_bar("MEM", metrics.memory_percent);
    let disk_bar = metric_bar("DSK", metrics.disk_percent);

    column![cpu_bar, mem_bar, disk_bar].spacing(4).into()
}

/// A single metric bar (label + percentage).
fn metric_bar<'a, Message: 'a>(label: &'static str, value: f32) -> Element<'a, Message> {
    let bar_width = (value / 100.0 * 80.0).max(0.0).min(80.0);
    let color = if value > 90.0 {
        Color::from_rgb(0.8, 0.2, 0.2)
    } else if value > 70.0 {
        Color::from_rgb(0.8, 0.6, 0.2)
    } else {
        Color::from_rgb(0.2, 0.6, 0.8)
    };

    row![
        text(label).size(10).width(Length::Fixed(30.0)),
        container(Space::new())
            .width(Length::Fixed(bar_width))
            .height(Length::Fixed(8.0))
            .style(move |_theme: &iced::Theme| container::Style {
                background: Some(color.into()),
                ..Default::default()
            }),
        text(format!("{:.0}%", value)).size(10),
    ]
    .spacing(4)
    .align_y(Alignment::Center)
    .into()
}

/// Card container style.
fn card_style(_theme: &iced::Theme) -> container::Style {
    container::Style {
        background: Some(Color::from_rgb(0.15, 0.15, 0.18).into()),
        border: iced::Border {
            color: Color::from_rgb(0.25, 0.25, 0.3),
            width: 1.0,
            radius: 8.0.into(),
        },
        ..Default::default()
    }
}
