//! Capabilities for Skjold.
//!
//! MVP uses simple traits. Full id_effect integration in Wave 2.

use crate::domain::{BatteryStatus, BluetoothState, CpuLoad, SessionAction, ThermalSensors};

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
