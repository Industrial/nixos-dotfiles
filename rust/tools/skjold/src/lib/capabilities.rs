//! Capabilities for Skjold.
//!
//! MVP uses simple traits. Full id_effect integration in Wave 2.

/// Capability for time operations.
pub trait TimeService: Send + Sync {
    /// Get the current local time.
    fn now(&self) -> chrono::DateTime<chrono::Local>;
}
