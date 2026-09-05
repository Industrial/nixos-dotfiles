//! Skjold — Hyprland panel shell.
//!
//! A native Rust panel for Hyprland built with id_effect and Iced.
//! Uses layer-shell protocol to render as a proper panel, not a window.

use std::sync::{Arc, OnceLock};

use iced_exwlshell::layershell::application;
use iced_exwlshell::reexport::{Anchor, Layer, LayerSize};
use iced_exwlshell::settings::{LayerShellSettings, Settings};

use skjold::providers::{
    LiveBatteryService, LiveBluetoothService, LiveHyprlandIpc, LiveLauncherService,
    LiveSessionService, LiveSystemInfoService, LiveTimeService, LiveWorkspaceService,
    live_providers,
};
use skjold::ui::SkjoldApp;

const PANEL_HEIGHT: u32 = 32;

// Store providers globally for the application factory
static HYPRLAND: OnceLock<Arc<LiveHyprlandIpc>> = OnceLock::new();
static TIME_SERVICE: OnceLock<Arc<LiveTimeService>> = OnceLock::new();
static SYSTEM_INFO: OnceLock<Arc<LiveSystemInfoService>> = OnceLock::new();
static BATTERY_SERVICE: OnceLock<Arc<LiveBatteryService>> = OnceLock::new();
static BLUETOOTH_SERVICE: OnceLock<Arc<LiveBluetoothService>> = OnceLock::new();
static SESSION_SERVICE: OnceLock<Arc<LiveSessionService>> = OnceLock::new();
static LAUNCHER_SERVICE: OnceLock<Arc<LiveLauncherService>> = OnceLock::new();
static WORKSPACE_SERVICE: OnceLock<Arc<LiveWorkspaceService>> = OnceLock::new();

fn main() -> Result<(), iced_exwlshell::Error> {
    let (
        hyprland,
        time_service,
        system_info,
        battery_service,
        bluetooth_service,
        session_service,
        launcher_service,
        workspace_service,
    ) = live_providers();

    // Store providers for the default function
    HYPRLAND
        .set(hyprland)
        .unwrap_or_else(|_| panic!("HYPRLAND already initialized"));
    TIME_SERVICE
        .set(time_service)
        .unwrap_or_else(|_| panic!("TIME_SERVICE already initialized"));
    SYSTEM_INFO
        .set(system_info)
        .unwrap_or_else(|_| panic!("SYSTEM_INFO already initialized"));
    BATTERY_SERVICE
        .set(battery_service)
        .unwrap_or_else(|_| panic!("BATTERY_SERVICE already initialized"));
    BLUETOOTH_SERVICE
        .set(bluetooth_service)
        .unwrap_or_else(|_| panic!("BLUETOOTH_SERVICE already initialized"));
    SESSION_SERVICE
        .set(session_service)
        .unwrap_or_else(|_| panic!("SESSION_SERVICE already initialized"));
    LAUNCHER_SERVICE
        .set(launcher_service)
        .unwrap_or_else(|_| panic!("LAUNCHER_SERVICE already initialized"));
    WORKSPACE_SERVICE
        .set(workspace_service)
        .unwrap_or_else(|_| panic!("WORKSPACE_SERVICE already initialized"));

    application(default, namespace, update, view)
        .subscription(subscription)
        .style(style)
        .settings(Settings {
            layer_settings: LayerShellSettings {
                size: LayerSize::fill_width(PANEL_HEIGHT),
                exclusive_zone: PANEL_HEIGHT as i32,
                anchor: Anchor::Top | Anchor::Left | Anchor::Right,
                layer: Layer::Top,
                ..Default::default()
            },
            ..Default::default()
        })
        .run()
}

fn default() -> SkjoldApp {
    let hyprland = HYPRLAND.get().expect("HYPRLAND not initialized").clone();
    let time_service = TIME_SERVICE
        .get()
        .expect("TIME_SERVICE not initialized")
        .clone();
    let system_info = SYSTEM_INFO
        .get()
        .expect("SYSTEM_INFO not initialized")
        .clone();
    let battery_service = BATTERY_SERVICE
        .get()
        .expect("BATTERY_SERVICE not initialized")
        .clone();
    let bluetooth_service = BLUETOOTH_SERVICE
        .get()
        .expect("BLUETOOTH_SERVICE not initialized")
        .clone();
    let session_service = SESSION_SERVICE
        .get()
        .expect("SESSION_SERVICE not initialized")
        .clone();
    let launcher_service = LAUNCHER_SERVICE
        .get()
        .expect("LAUNCHER_SERVICE not initialized")
        .clone();
    let workspace_service = WORKSPACE_SERVICE
        .get()
        .expect("WORKSPACE_SERVICE not initialized")
        .clone();
    SkjoldApp::new_default(
        hyprland,
        time_service,
        system_info,
        battery_service,
        bluetooth_service,
        session_service,
        launcher_service,
        workspace_service,
    )
}

fn namespace() -> String {
    String::from("Skjold")
}

fn update(app: &mut SkjoldApp, message: skjold::ui::Message) -> iced::Task<skjold::ui::Message> {
    app.update(message)
}

fn view(app: &SkjoldApp) -> iced::Element<'_, skjold::ui::Message> {
    app.view()
}

fn subscription(app: &SkjoldApp) -> iced::Subscription<skjold::ui::Message> {
    app.subscription()
}

fn style(_app: &SkjoldApp, theme: &iced::Theme) -> iced::theme::Style {
    iced::theme::Style {
        background_color: iced::Color::TRANSPARENT,
        text_color: theme.palette().text,
    }
}
