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
