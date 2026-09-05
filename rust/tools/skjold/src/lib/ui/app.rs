//! Main Iced application for Skjold.

use std::collections::HashSet;
use std::sync::Arc;
use std::time::Duration;

use iced::futures::channel::mpsc::Sender;
use iced::widget::{Space, button, container, row, text};
use iced::{Color, Element, Length, Subscription, Task, Theme};

use iced_exwlshell::to_layer_message;

use crate::capabilities::{BatteryService, SystemInfoService, TimeService};
use crate::domain::{BatteryStatus, Clock, CpuLoad, ThermalSensors};
use crate::providers::{
    LiveBatteryService, LiveHyprlandIpc, LiveSystemInfoService, LiveTimeService,
};
use crate::ui::widgets::{battery_widget, cpu_widget, thermal_widget};

/// Messages for the Skjold application.
#[to_layer_message]
#[derive(Debug, Clone)]
pub enum Message {
    /// Clock tick - update time display.
    Tick,
    /// System info refresh tick.
    SystemInfoTick,
    /// Workspace button clicked.
    SwitchWorkspace(i32),
    /// Active workspace changed (from click or event).
    ActiveWorkspaceChanged(i32),
    /// Workspaces refreshed from Hyprland.
    WorkspacesRefreshed(Vec<i32>),
    /// Hyprland event received.
    HyprlandEvent(HyprlandEventMsg),
}

/// Hyprland events we subscribe to.
#[derive(Debug, Clone)]
pub enum HyprlandEventMsg {
    WorkspaceChanged(i32),
    WindowOpened,
    WindowClosed,
}

/// The main Skjold application state.
pub struct SkjoldApp {
    /// Current clock state.
    clock: Clock,
    /// Currently active workspace ID.
    active_workspace_id: i32,
    /// Workspace IDs that have windows (occupied).
    occupied_workspaces: HashSet<i32>,
    /// Hyprland IPC capability.
    hyprland: Arc<LiveHyprlandIpc>,
    /// Time service capability.
    time_service: Arc<LiveTimeService>,
    /// System info service capability.
    system_info: Arc<LiveSystemInfoService>,
    /// Battery service capability.
    battery_service: Arc<LiveBatteryService>,
    /// Current CPU load.
    cpu_load: CpuLoad,
    /// Current thermal sensors.
    thermal: ThermalSensors,
    /// Current battery status.
    battery: BatteryStatus,
}

impl SkjoldApp {
    /// Create a new Skjold application with live providers (for iced_exwlshell default fn).
    pub fn new_default(
        hyprland: Arc<LiveHyprlandIpc>,
        time_service: Arc<LiveTimeService>,
        system_info: Arc<LiveSystemInfoService>,
        battery_service: Arc<LiveBatteryService>,
    ) -> Self {
        let initial_ws = hyprland.get_active_workspace().map(|ws| ws.id).unwrap_or(1);
        let occupied: HashSet<i32> = hyprland
            .get_workspaces()
            .map(|wss| {
                wss.into_iter()
                    .filter(|ws| ws.windows > 0)
                    .map(|ws| ws.id)
                    .collect()
            })
            .unwrap_or_default();

        // Get initial system info
        system_info.refresh();
        let cpu_load = system_info.get_cpu_load();
        let thermal = system_info.get_thermal();
        let battery = battery_service.get_status();

        Self {
            clock: Clock::now(),
            active_workspace_id: initial_ws,
            occupied_workspaces: occupied,
            hyprland,
            time_service,
            system_info,
            battery_service,
            cpu_load,
            thermal,
            battery,
        }
    }

    /// Create a new Skjold application with live providers (returns Task for standard iced).
    pub fn new(
        hyprland: Arc<LiveHyprlandIpc>,
        time_service: Arc<LiveTimeService>,
        system_info: Arc<LiveSystemInfoService>,
        battery_service: Arc<LiveBatteryService>,
    ) -> (Self, Task<Message>) {
        // Query initial state
        let initial_ws = hyprland.get_active_workspace().map(|ws| ws.id).unwrap_or(1);
        let occupied: HashSet<i32> = hyprland
            .get_workspaces()
            .map(|wss| {
                wss.into_iter()
                    .filter(|ws| ws.windows > 0)
                    .map(|ws| ws.id)
                    .collect()
            })
            .unwrap_or_default();

        // Get initial system info
        system_info.refresh();
        let cpu_load = system_info.get_cpu_load();
        let thermal = system_info.get_thermal();
        let battery = battery_service.get_status();

        let app = Self {
            clock: Clock::now(),
            active_workspace_id: initial_ws,
            occupied_workspaces: occupied,
            hyprland,
            time_service,
            system_info,
            battery_service,
            cpu_load,
            thermal,
            battery,
        };

        (app, Task::none())
    }

    /// Application title.
    pub fn title(&self) -> String {
        String::from("Skjold")
    }

    /// Handle messages.
    pub fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::Tick => {
                self.clock = Clock {
                    time: self.time_service.now(),
                };
                Task::none()
            }
            Message::SystemInfoTick => {
                self.system_info.refresh();
                self.cpu_load = self.system_info.get_cpu_load();
                self.thermal = self.system_info.get_thermal();
                self.battery = self.battery_service.get_status();
                Task::none()
            }
            Message::SwitchWorkspace(id) => Task::perform(
                async move {
                    use hyprland::dispatch::{
                        Dispatch, DispatchType, WorkspaceIdentifierWithSpecial,
                    };
                    let _ = Dispatch::call(DispatchType::Workspace(
                        WorkspaceIdentifierWithSpecial::Id(id),
                    ));
                    id
                },
                Message::ActiveWorkspaceChanged,
            ),
            Message::ActiveWorkspaceChanged(id) => {
                self.active_workspace_id = id;
                Task::none()
            }
            Message::WorkspacesRefreshed(occupied) => {
                self.occupied_workspaces = occupied.into_iter().collect();
                Task::none()
            }
            Message::HyprlandEvent(event) => {
                match event {
                    HyprlandEventMsg::WorkspaceChanged(id) => {
                        self.active_workspace_id = id;
                    }
                    HyprlandEventMsg::WindowOpened | HyprlandEventMsg::WindowClosed => {
                        // Refresh workspace occupancy
                        if let Ok(wss) = self.hyprland.get_workspaces() {
                            self.occupied_workspaces = wss
                                .into_iter()
                                .filter(|ws| ws.windows > 0)
                                .map(|ws| ws.id)
                                .collect();
                        }
                    }
                }
                Task::none()
            }
            // Layer-shell messages added by #[to_layer_message] macro - ignore for now
            _ => Task::none(),
        }
    }

    /// Render the application.
    pub fn view(&self) -> Element<'_, Message> {
        // Workspace buttons (1-10)
        let workspace_buttons: Vec<Element<Message>> = (1..=10)
            .map(|i| {
                let is_active = i == self.active_workspace_id;
                let is_occupied = self.occupied_workspaces.contains(&i);
                let label = format!("{}", i);

                let btn = button(text(label).size(14))
                    .padding(8)
                    .on_press(Message::SwitchWorkspace(i));

                if is_active {
                    btn.style(iced::widget::button::primary).into()
                } else if is_occupied {
                    // Occupied but not active - use a distinct style
                    btn.style(|theme: &Theme, status| {
                        let mut style = iced::widget::button::secondary(theme, status);
                        style.text_color = Color::from_rgb(0.9, 0.8, 0.5); // Gruvbox yellow
                        style
                    })
                    .into()
                } else {
                    btn.style(iced::widget::button::secondary).into()
                }
            })
            .collect();

        // Clock display
        let clock_display = text(self.clock.formatted()).size(16);

        // System info widgets
        let cpu_display = cpu_widget(&self.cpu_load);
        let thermal_display = thermal_widget(&self.thermal);
        let battery_display = battery_widget(&self.battery);

        // Main row: workspaces | spacer | cpu | temp | battery | clock
        let content = row![
            row(workspace_buttons).spacing(4),
            Space::new().width(Length::Fill),
            cpu_display,
            thermal_display,
            battery_display,
            clock_display,
        ]
        .spacing(16)
        .padding(8);

        container(content)
            .width(Length::Fill)
            .height(Length::Shrink)
            .into()
    }

    /// Subscriptions for background tasks.
    pub fn subscription(&self) -> Subscription<Message> {
        let clock_tick = iced::time::every(Duration::from_secs(1)).map(|_| Message::Tick);

        // System info refresh every 5 seconds
        let system_info_tick =
            iced::time::every(Duration::from_secs(5)).map(|_| Message::SystemInfoTick);

        // Hyprland event subscription
        let hyprland_events = Subscription::run(hyprland_event_stream);

        Subscription::batch([clock_tick, system_info_tick, hyprland_events])
    }

    /// Application theme.
    pub fn theme(&self) -> Theme {
        Theme::Dark
    }
}

/// Stream Hyprland events as Iced messages.
/// Uses a background thread since EventListener is not Send.
fn hyprland_event_stream() -> impl iced::futures::Stream<Item = Message> {
    iced::stream::channel(32, |sender: Sender<Message>| async move {
        use hyprland::event_listener::EventListener;
        use std::sync::mpsc;

        // Create a std channel to bridge the non-Send listener
        let (tx, rx) = mpsc::channel();

        // Spawn listener in a dedicated thread
        std::thread::spawn(move || {
            let mut listener = EventListener::new();

            let tx_ws = tx.clone();
            listener.add_workspace_changed_handler(move |data| {
                let _ = tx_ws.send(HyprlandEventMsg::WorkspaceChanged(data.id));
            });

            let tx_open = tx.clone();
            listener.add_window_opened_handler(move |_| {
                let _ = tx_open.send(HyprlandEventMsg::WindowOpened);
            });

            let tx_close = tx.clone();
            listener.add_window_closed_handler(move |_| {
                let _ = tx_close.send(HyprlandEventMsg::WindowClosed);
            });

            // This blocks forever
            let _ = listener.start_listener();
        });

        // Forward events from the thread to Iced
        loop {
            match rx.recv() {
                Ok(event) => {
                    let _ = sender.clone().try_send(Message::HyprlandEvent(event));
                }
                Err(_) => break, // Channel closed
            }
        }
    })
}
