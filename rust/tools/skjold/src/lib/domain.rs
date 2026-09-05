//! Domain models for Skjold.

use chrono::{DateTime, Local};

/// A Hyprland workspace.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Workspace {
    pub id: i32,
    pub name: String,
    pub monitor: String,
    pub windows: u32,
    pub has_fullscreen: bool,
    pub last_window_title: String,
}

/// Current time state.
#[derive(Debug, Clone)]
pub struct Clock {
    pub time: DateTime<Local>,
}

impl Clock {
    pub fn now() -> Self {
        Self { time: Local::now() }
    }

    pub fn formatted(&self) -> String {
        self.time.format("%H:%M:%S").to_string()
    }
}

/// Hyprland events we care about.
#[derive(Debug, Clone)]
pub enum HyprlandEvent {
    WorkspaceChanged { id: i32 },
    ActiveWindowChanged { title: String },
    WindowOpened,
    WindowClosed,
}

// === System Info Models (Wave 1) ===

/// Battery status information.
#[derive(Debug, Clone, Default)]
pub struct BatteryStatus {
    /// Battery charge percentage (0-100).
    pub percentage: u8,
    /// Whether the battery is currently charging.
    pub charging: bool,
    /// Whether a battery is present in the system.
    pub present: bool,
}

/// CPU load information.
#[derive(Debug, Clone, Default)]
pub struct CpuLoad {
    /// Overall CPU usage as a percentage (0-100).
    pub usage_percent: f32,
}

/// Thermal sensor readings.
#[derive(Debug, Clone, Default)]
pub struct ThermalSensors {
    /// CPU temperature in Celsius, if available.
    pub cpu_temp_celsius: Option<f32>,
}

// === D-Bus Models (Wave 2) ===

/// Bluetooth adapter state.
#[derive(Debug, Clone, Default)]
pub struct BluetoothState {
    /// Whether the adapter is powered on.
    pub powered: bool,
    /// Whether the adapter is available.
    pub available: bool,
    /// Names of connected devices.
    pub connected_devices: Vec<String>,
}

/// Session actions for the power menu.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum SessionAction {
    Lock,
    Logout,
    Suspend,
    Reboot,
    Shutdown,
}

impl SessionAction {
    /// Get all session actions.
    pub fn all() -> &'static [SessionAction] {
        &[
            SessionAction::Lock,
            SessionAction::Logout,
            SessionAction::Suspend,
            SessionAction::Reboot,
            SessionAction::Shutdown,
        ]
    }

    /// Get the display label for this action.
    pub fn label(&self) -> &'static str {
        match self {
            SessionAction::Lock => "Lock",
            SessionAction::Logout => "Logout",
            SessionAction::Suspend => "Suspend",
            SessionAction::Reboot => "Reboot",
            SessionAction::Shutdown => "Shutdown",
        }
    }

    /// Get the icon for this action (Nerd Font).
    pub fn icon(&self) -> &'static str {
        match self {
            SessionAction::Lock => "\u{f033e}",     // nf-md-lock
            SessionAction::Logout => "\u{f0343}",   // nf-md-logout
            SessionAction::Suspend => "\u{f04b2}",  // nf-md-sleep
            SessionAction::Reboot => "\u{f0709}",   // nf-md-restart
            SessionAction::Shutdown => "\u{f0425}", // nf-md-power
        }
    }
}

// === Launcher Models (Wave 3) ===

/// An application entry from a .desktop file.
#[derive(Debug, Clone)]
pub struct LauncherEntry {
    /// Application name.
    pub name: String,
    /// Optional generic name.
    pub generic_name: Option<String>,
    /// Comment/description.
    pub comment: Option<String>,
    /// Exec command.
    pub exec: String,
    /// Icon name.
    pub icon: Option<String>,
    /// Categories for filtering.
    pub categories: Vec<String>,
    /// Whether this is a terminal application.
    pub terminal: bool,
    /// Path to the .desktop file (for deduplication).
    pub desktop_path: String,
}

impl LauncherEntry {
    /// Get the display name (name or generic name).
    pub fn display_name(&self) -> &str {
        &self.name
    }

    /// Get the subtitle (generic name or comment).
    pub fn subtitle(&self) -> Option<&str> {
        self.generic_name.as_deref().or(self.comment.as_deref())
    }
}

/// Launcher state.
#[derive(Debug, Clone, Default)]
pub struct LauncherState {
    /// Whether the launcher is visible.
    pub visible: bool,
    /// Current search query.
    pub query: String,
    /// All available applications.
    pub entries: Vec<LauncherEntry>,
    /// Filtered results based on query.
    pub filtered: Vec<usize>,
    /// Currently selected index in filtered results.
    pub selected: usize,
}

/// Audio output state.
#[derive(Debug, Clone, Default)]
pub struct AudioState {
    /// Volume level (0-100).
    pub volume: u32,
    /// Whether output is muted.
    pub muted: bool,
    /// Name of the default sink (output device).
    pub sink_name: Option<String>,
}
