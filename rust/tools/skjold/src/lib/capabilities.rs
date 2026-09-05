//! Capabilities for Skjold.
//!
//! MVP uses simple traits. Full id_effect integration in Wave 2.

use crate::domain::{
    AudioState, BatteryStatus, BluetoothState, CpuLoad, LauncherEntry, NetworkState, SessionAction,
    ThermalSensors, Workspace,
};

/// Capability for time operations.
pub trait TimeService: Send + Sync {
    /// Get the current local time.
    fn now(&self) -> chrono::DateTime<chrono::Local>;
}

// === System Info Capabilities (Wave 1) ===

/// Capability for battery status.
pub trait BatteryService: Send + Sync {
    /// Get current battery status.
    fn get_status(&self) -> BatteryStatus;
}

/// Capability for system information (CPU, memory, etc.).
pub trait SystemInfoService: Send + Sync {
    /// Get current CPU load.
    fn get_cpu_load(&self) -> CpuLoad;

    /// Get thermal sensor readings.
    fn get_thermal(&self) -> ThermalSensors;

    /// Refresh system info (call periodically).
    fn refresh(&self);
}

// === D-Bus Capabilities (Wave 2) ===

/// Capability for Bluetooth operations via D-Bus.
pub trait BluetoothService: Send + Sync {
    /// Get current Bluetooth state.
    fn get_state(&self) -> BluetoothState;

    /// Toggle Bluetooth power.
    fn toggle_power(&self);

    /// Refresh Bluetooth state.
    fn refresh(&self);
}

/// Capability for session operations via D-Bus (logind).
pub trait SessionService: Send + Sync {
    /// Execute a session action.
    fn execute(&self, action: SessionAction);

    /// Check if an action is available.
    fn is_available(&self, action: SessionAction) -> bool;
}

// === Launcher Capabilities (Wave 3) ===

/// Capability for application launcher.
pub trait LauncherService: Send + Sync {
    /// Get all available applications.
    fn get_entries(&self) -> Vec<LauncherEntry>;

    /// Search entries by query (fuzzy match).
    fn search(&self, query: &str) -> Vec<usize>;

    /// Launch an application by index.
    fn launch(&self, index: usize);

    /// Refresh the application list.
    fn refresh(&self);
}

// === Workspace Capabilities (Wave 4) ===

/// Capability for Hyprland workspace operations.
pub trait WorkspaceService: Send + Sync {
    /// Get all workspaces.
    fn get_workspaces(&self) -> Vec<Workspace>;

    /// Get the currently active workspace.
    fn get_active(&self) -> Option<Workspace>;

    /// Switch to a workspace by ID.
    fn switch_to(&self, id: i32);

    /// Refresh workspace state.
    fn refresh(&self);
}

// === Audio Capabilities (Wave 5) ===

/// Capability for audio control via PulseAudio.
pub trait AudioService: Send + Sync {
    /// Get current audio state.
    fn get_state(&self) -> AudioState;

    /// Set volume (0-100).
    fn set_volume(&self, volume: u32);

    /// Toggle mute.
    fn toggle_mute(&self);

    /// Refresh audio state.
    fn refresh(&self);
}

// === Network Capabilities (Wave 6) ===

/// Capability for network status via NetworkManager.
pub trait NetworkService: Send + Sync {
    /// Get current network state.
    fn get_state(&self) -> NetworkState;

    /// Refresh network state.
    fn refresh(&self);
}

// === Window List Capabilities (Wave 7) ===

use crate::domain::WindowInfo;

/// Capability for window/client operations via Hyprland IPC.
pub trait WindowService: Send + Sync {
    /// Get all windows on the current workspace.
    fn get_windows(&self) -> Vec<WindowInfo>;

    /// Get the focused window.
    fn get_focused(&self) -> Option<WindowInfo>;

    /// Focus a window by address.
    fn focus(&self, address: &str);

    /// Refresh window list.
    fn refresh(&self);
}

// === Notification Capabilities (Wave 8) ===

use crate::domain::NotificationInfo;

/// Capability for notification display.
pub trait NotificationService: Send + Sync {
    /// Get recent notifications.
    fn get_notifications(&self) -> Vec<NotificationInfo>;

    /// Dismiss a notification by ID.
    fn dismiss(&self, id: u32);

    /// Clear all notifications.
    fn clear_all(&self);

    /// Get notification count.
    fn count(&self) -> usize;
}

// === System Tray Capabilities (Wave 9) ===

use crate::domain::TrayItem;

/// Capability for system tray (StatusNotifierItem/SNI).
pub trait SystemTrayService: Send + Sync {
    /// Get all registered tray items.
    fn get_items(&self) -> Vec<TrayItem>;

    /// Activate a tray item (left click).
    fn activate(&self, bus_name: &str, object_path: &str);

    /// Secondary activate (middle click).
    fn secondary_activate(&self, bus_name: &str, object_path: &str);

    /// Context menu (right click).
    fn context_menu(&self, bus_name: &str, object_path: &str);

    /// Refresh tray items.
    fn refresh(&self);
}
