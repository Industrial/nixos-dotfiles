//! Main Iced application for Skjold.

use std::collections::HashSet;
use std::sync::Arc;
use std::time::Duration;

use iced::futures::channel::mpsc::Sender;
use iced::widget::{Space, button, container, row, text};
use iced::{Color, Element, Length, Subscription, Task, Theme};

use iced_exwlshell::to_layer_message;

use crate::capabilities::{
    BatteryService, BluetoothService, LauncherService, SessionService, SystemInfoService,
    TimeService, WorkspaceService,
};
use crate::domain::{
    BatteryStatus, BluetoothState, Clock, CpuLoad, LauncherEntry, LauncherState, SessionAction,
    ThermalSensors, Workspace,
};
use crate::providers::{
    LiveBatteryService, LiveBluetoothService, LiveHyprlandIpc, LiveLauncherService,
    LiveSessionService, LiveSystemInfoService, LiveTimeService, LiveWorkspaceService,
};
use crate::ui::widgets::{
    battery_widget, bluetooth_widget, cpu_widget, launcher_widget, session_widget, thermal_widget,
    workspaces_widget,
};

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
    /// Toggle Bluetooth power.
    BluetoothToggle,
    /// Toggle session menu visibility.
    SessionMenuToggle,
    /// Execute a session action.
    SessionAction(SessionAction),
    /// Toggle launcher visibility.
    LauncherToggle,
    /// Launcher search query changed.
    LauncherQueryChange(String),
    /// Launcher item selected.
    LauncherSelect(usize),
    /// Close launcher.
    LauncherClose,
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
    /// Workspace service capability.
    workspace_service: Arc<LiveWorkspaceService>,
    /// Current workspaces list.
    workspaces: Vec<Workspace>,
    /// Current CPU load.
    cpu_load: CpuLoad,
    /// Current thermal sensors.
    thermal: ThermalSensors,
    /// Current battery status.
    battery: BatteryStatus,
    /// Bluetooth service capability.
    bluetooth_service: Arc<LiveBluetoothService>,
    /// Session service capability.
    session_service: Arc<LiveSessionService>,
    /// Launcher service capability.
    launcher_service: Arc<LiveLauncherService>,
    /// Current Bluetooth state.
    bluetooth: BluetoothState,
    /// Whether the session menu is expanded.
    session_menu_expanded: bool,
    /// Launcher state.
    launcher: LauncherState,
    /// Cached launcher entries.
    launcher_entries: Vec<LauncherEntry>,
}

impl SkjoldApp {
    /// Create a new Skjold application with live providers (for iced_exwlshell default fn).
    pub fn new_default(
        hyprland: Arc<LiveHyprlandIpc>,
        time_service: Arc<LiveTimeService>,
        system_info: Arc<LiveSystemInfoService>,
        battery_service: Arc<LiveBatteryService>,
        bluetooth_service: Arc<LiveBluetoothService>,
        session_service: Arc<LiveSessionService>,
        launcher_service: Arc<LiveLauncherService>,
        workspace_service: Arc<LiveWorkspaceService>,
    ) -> Self {
        // Get initial workspace state
        let workspaces = workspace_service.get_workspaces();
        let initial_ws = workspace_service.get_active().map(|ws| ws.id).unwrap_or(1);
        let occupied: HashSet<i32> = workspaces
            .iter()
            .filter(|ws| ws.windows > 0)
            .map(|ws| ws.id)
            .collect();

        // Get initial system info
        system_info.refresh();
        let cpu_load = system_info.get_cpu_load();
        let thermal = system_info.get_thermal();
        let battery = battery_service.get_status();
        let bluetooth = bluetooth_service.get_state();

        // Get launcher entries
        let launcher_entries = launcher_service.get_entries();
        let filtered: Vec<usize> = (0..launcher_entries.len()).collect();

        Self {
            clock: Clock::now(),
            active_workspace_id: initial_ws,
            occupied_workspaces: occupied,
            hyprland,
            time_service,
            system_info,
            battery_service,
            workspace_service,
            workspaces,
            cpu_load,
            thermal,
            battery,
            bluetooth_service,
            session_service,
            launcher_service,
            bluetooth,
            session_menu_expanded: false,
            launcher: LauncherState {
                visible: false,
                query: String::new(),
                entries: Vec::new(), // Stored separately
                filtered,
                selected: 0,
            },
            launcher_entries,
        }
    }

    /// Create a new Skjold application with live providers (returns Task for standard iced).
    pub fn new(
        hyprland: Arc<LiveHyprlandIpc>,
        time_service: Arc<LiveTimeService>,
        system_info: Arc<LiveSystemInfoService>,
        battery_service: Arc<LiveBatteryService>,
        bluetooth_service: Arc<LiveBluetoothService>,
        session_service: Arc<LiveSessionService>,
        launcher_service: Arc<LiveLauncherService>,
        workspace_service: Arc<LiveWorkspaceService>,
    ) -> (Self, Task<Message>) {
        // Get initial workspace state
        let workspaces = workspace_service.get_workspaces();
        let initial_ws = workspace_service.get_active().map(|ws| ws.id).unwrap_or(1);
        let occupied: HashSet<i32> = workspaces
            .iter()
            .filter(|ws| ws.windows > 0)
            .map(|ws| ws.id)
            .collect();

        // Get initial system info
        system_info.refresh();
        let cpu_load = system_info.get_cpu_load();
        let thermal = system_info.get_thermal();
        let battery = battery_service.get_status();
        let bluetooth = bluetooth_service.get_state();

        // Get launcher entries
        let launcher_entries = launcher_service.get_entries();
        let filtered: Vec<usize> = (0..launcher_entries.len()).collect();

        let app = Self {
            clock: Clock::now(),
            active_workspace_id: initial_ws,
            occupied_workspaces: occupied,
            hyprland,
            time_service,
            system_info,
            battery_service,
            workspace_service,
            workspaces,
            cpu_load,
            thermal,
            battery,
            bluetooth_service,
            session_service,
            launcher_service,
            bluetooth,
            session_menu_expanded: false,
            launcher: LauncherState {
                visible: false,
                query: String::new(),
                entries: Vec::new(),
                filtered,
                selected: 0,
            },
            launcher_entries,
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
                self.bluetooth_service.refresh();
                self.bluetooth = self.bluetooth_service.get_state();
                Task::none()
            }
            Message::BluetoothToggle => {
                self.bluetooth_service.toggle_power();
                self.bluetooth = self.bluetooth_service.get_state();
                Task::none()
            }
            Message::SessionMenuToggle => {
                self.session_menu_expanded = !self.session_menu_expanded;
                Task::none()
            }
            Message::SessionAction(action) => {
                self.session_service.execute(action);
                self.session_menu_expanded = false;
                Task::none()
            }
            Message::LauncherToggle => {
                self.launcher.visible = !self.launcher.visible;
                if self.launcher.visible {
                    // Reset state when opening
                    self.launcher.query.clear();
                    self.launcher.filtered = (0..self.launcher_entries.len()).collect();
                    self.launcher.selected = 0;
                }
                Task::none()
            }
            Message::LauncherQueryChange(query) => {
                self.launcher.query = query.clone();
                self.launcher.filtered = self.launcher_service.search(&query);
                self.launcher.selected = 0;
                Task::none()
            }
            Message::LauncherSelect(index) => {
                self.launcher_service.launch(index);
                self.launcher.visible = false;
                self.launcher.query.clear();
                Task::none()
            }
            Message::LauncherClose => {
                self.launcher.visible = false;
                self.launcher.query.clear();
                Task::none()
            }
            Message::SwitchWorkspace(id) => {
                self.workspace_service.switch_to(id);
                self.active_workspace_id = id;
                // Refresh workspace list after switch
                self.workspaces = self.workspace_service.get_workspaces();
                self.occupied_workspaces = self
                    .workspaces
                    .iter()
                    .filter(|ws| ws.windows > 0)
                    .map(|ws| ws.id)
                    .collect();
                Task::none()
            }
            Message::ActiveWorkspaceChanged(id) => {
                self.active_workspace_id = id;
                self.workspace_service.refresh();
                self.workspaces = self.workspace_service.get_workspaces();
                self.occupied_workspaces = self
                    .workspaces
                    .iter()
                    .filter(|ws| ws.windows > 0)
                    .map(|ws| ws.id)
                    .collect();
                Task::none()
            }
            Message::WorkspacesRefreshed(_occupied) => {
                self.workspace_service.refresh();
                self.workspaces = self.workspace_service.get_workspaces();
                self.occupied_workspaces = self
                    .workspaces
                    .iter()
                    .filter(|ws| ws.windows > 0)
                    .map(|ws| ws.id)
                    .collect();
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
        // Workspace indicator using the workspace widget
        let workspace_display = workspaces_widget(
            &self.workspaces,
            Some(self.active_workspace_id),
            Message::SwitchWorkspace,
        );

        // Clock display
        let clock_display = text(self.clock.formatted()).size(16);

        // System info widgets
        let cpu_display = cpu_widget(&self.cpu_load);
        let thermal_display = thermal_widget(&self.thermal);
        let battery_display = battery_widget(&self.battery);
        let bluetooth_display = bluetooth_widget(&self.bluetooth, Message::BluetoothToggle);
        let session_display = session_widget(
            self.session_menu_expanded,
            Message::SessionMenuToggle,
            Message::SessionAction,
        );

        // Launcher toggle button
        let launcher_btn = button(text("\u{f0349}").size(14)) // nf-md-magnify
            .padding(8)
            .style(iced::widget::button::text)
            .on_press(Message::LauncherToggle);

        // Main row: launcher | workspaces | spacer | cpu | temp | battery | bluetooth | clock | session
        let content = row![
            launcher_btn,
            workspace_display,
            Space::new().width(Length::Fill),
            cpu_display,
            thermal_display,
            battery_display,
            bluetooth_display,
            clock_display,
            session_display,
        ]
        .spacing(16)
        .padding(8);

        // If launcher is visible, render overlay on top
        // Note: Full overlay requires separate layer-shell surface - for now just show inline
        if self.launcher.visible {
            let launcher_overlay = launcher_widget(
                &self.launcher,
                &self.launcher_entries,
                Message::LauncherQueryChange,
                Message::LauncherSelect,
                Message::LauncherClose,
            );

            // Stack panel content under launcher overlay
            iced::widget::stack![
                container(content)
                    .width(Length::Fill)
                    .height(Length::Shrink),
                launcher_overlay,
            ]
            .into()
        } else {
            container(content)
                .width(Length::Fill)
                .height(Length::Shrink)
                .into()
        }
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
