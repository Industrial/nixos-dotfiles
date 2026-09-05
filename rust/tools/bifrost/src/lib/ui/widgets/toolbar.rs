//! Toolbar widget — top bar with fleet actions.

use iced::widget::{Space, button, container, row, text};
use iced::{Alignment, Color, Element, Length};

/// Create the toolbar widget.
pub fn toolbar_widget<'a, Message: Clone + 'a>(
    hosts_online: usize,
    hosts_total: usize,
    on_deploy_all: Message,
    on_refresh: Message,
) -> Element<'a, Message> {
    // Title
    let title = text("BIFRÖST").size(20);

    // Status summary
    let status = text(format!("{}/{} hosts online", hosts_online, hosts_total)).size(14);

    // Action buttons
    let deploy_all_btn = button(text("Deploy All").size(14))
        .padding([6, 12])
        .on_press(on_deploy_all);

    let refresh_btn = button(text("Refresh").size(14))
        .padding([6, 12])
        .on_press(on_refresh);

    let content = row![
        title,
        Space::new().width(Length::Fill),
        status,
        Space::new().width(20),
        deploy_all_btn,
        refresh_btn,
    ]
    .spacing(12)
    .padding(12)
    .align_y(Alignment::Center);

    container(content)
        .width(Length::Fill)
        .style(toolbar_style)
        .into()
}

/// Toolbar container style.
fn toolbar_style(_theme: &iced::Theme) -> container::Style {
    container::Style {
        background: Some(Color::from_rgb(0.1, 0.1, 0.12).into()),
        border: iced::Border {
            color: Color::from_rgb(0.2, 0.2, 0.25),
            width: 0.0,
            radius: 0.0.into(),
        },
        ..Default::default()
    }
}
