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
