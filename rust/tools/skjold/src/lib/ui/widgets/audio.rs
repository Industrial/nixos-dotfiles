//! Audio control widget.

use iced::widget::{button, row, text};
use iced::{Color, Element};

use crate::domain::AudioState;

/// Render audio control as a clickable volume indicator.
pub fn audio_widget<'a, Message: Clone + 'a>(
    audio: &AudioState,
    on_toggle_mute: Message,
) -> Element<'a, Message> {
    let muted_color = Color::from_rgb(0.92, 0.28, 0.28); // Gruvbox red
    let normal_color = Color::from_rgb(0.92, 0.86, 0.70); // Gruvbox fg

    // Choose icon based on mute state and volume level
    let icon = if audio.muted {
        "\u{f057f}" // nf-md-volume_off
    } else if audio.volume == 0 {
        "\u{f057f}" // nf-md-volume_off
    } else if audio.volume < 30 {
        "\u{f057e}" // nf-md-volume_low
    } else if audio.volume < 70 {
        "\u{f0580}" // nf-md-volume_medium
    } else {
        "\u{f057d}" // nf-md-volume_high
    };

    let color = if audio.muted {
        muted_color
    } else {
        normal_color
    };

    // Volume percentage display
    let volume_text = if audio.muted {
        "Mute".to_string()
    } else {
        format!("{}%", audio.volume)
    };

    button(
        row![
            text(icon).size(14).color(color),
            text(volume_text).size(12).color(color),
        ]
        .spacing(4)
        .align_y(iced::Alignment::Center),
    )
    .padding([4, 8])
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
    .on_press(on_toggle_mute)
    .into()
}
