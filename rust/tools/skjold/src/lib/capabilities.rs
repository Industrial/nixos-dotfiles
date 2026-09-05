//! Capabilities for Skjold.
//!
//! MVP uses simple traits. Full id_effect integration in Wave 2.

use crate::domain::{BatteryStatus, CpuLoad, ThermalSensors};

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
