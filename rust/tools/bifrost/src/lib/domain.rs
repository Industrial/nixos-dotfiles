//! Domain types for Bifröst.
//!
//! Pure data structures with no external dependencies.

use std::net::IpAddr;
use std::time::Duration;

use chrono::{DateTime, Utc};
use serde::Deserialize;

/// A host in the fleet.
#[derive(Debug, Clone)]
pub struct Host {
    /// Hostname (e.g., "drakkar", "huginn", "mimir").
    pub name: String,
    /// Tailscale IP address if available.
    pub tailscale_ip: Option<IpAddr>,
    /// Current status.
    pub status: HostStatus,
    /// System metrics from Prometheus.
    pub metrics: Option<SystemMetrics>,
    /// Current NixOS generation.
    pub nixos_generation: Option<Generation>,
}

impl Host {
    /// Create a new host with unknown status.
    pub fn new(name: impl Into<String>) -> Self {
        Self {
            name: name.into(),
            tailscale_ip: None,
            status: HostStatus::Unknown,
            metrics: None,
            nixos_generation: None,
        }
    }
}

/// Status of a fleet host.
#[derive(Debug, Clone, PartialEq)]
pub enum HostStatus {
    /// Host is online and responding.
    Online { uptime: Duration },
    /// Host is unreachable via SSH.
    Unreachable,
    /// Deployment in progress.
    Deploying,
    /// Host is degraded (e.g., high load, disk full).
    Degraded { reason: String },
    /// Status not yet determined.
    Unknown,
}

impl HostStatus {
    /// Check if the host is considered healthy.
    pub fn is_healthy(&self) -> bool {
        matches!(self, HostStatus::Online { .. })
    }

    /// Get a status indicator character.
    pub fn indicator(&self) -> &'static str {
        match self {
            HostStatus::Online { .. } => "●",
            HostStatus::Unreachable => "○",
            HostStatus::Deploying => "◐",
            HostStatus::Degraded { .. } => "◑",
            HostStatus::Unknown => "?",
        }
    }

    /// Get status label.
    pub fn label(&self) -> &'static str {
        match self {
            HostStatus::Online { .. } => "ONLINE",
            HostStatus::Unreachable => "OFFLINE",
            HostStatus::Deploying => "DEPLOYING",
            HostStatus::Degraded { .. } => "DEGRADED",
            HostStatus::Unknown => "UNKNOWN",
        }
    }
}

/// System metrics from Prometheus.
#[derive(Debug, Clone, Default)]
pub struct SystemMetrics {
    /// CPU usage percentage (0-100).
    pub cpu_percent: f32,
    /// Memory usage percentage (0-100).
    pub memory_percent: f32,
    /// Disk usage percentage (0-100).
    pub disk_percent: f32,
    /// 1-minute load average.
    pub load_1m: f32,
    /// Temperature in Celsius (if available).
    pub temperature: Option<f32>,
}

/// NixOS generation information.
#[derive(Debug, Clone)]
pub struct Generation {
    /// Generation number.
    pub number: u32,
    /// When this generation was created.
    pub date: DateTime<Utc>,
    /// NixOS version string.
    pub nixos_version: String,
    /// Whether this is the currently active generation.
    pub current: bool,
}

/// A deployment event.
#[derive(Debug, Clone)]
pub struct DeploymentEvent {
    /// When the event occurred.
    pub timestamp: DateTime<Utc>,
    /// Which host this event relates to.
    pub host: String,
    /// Event message.
    pub message: String,
    /// Event severity.
    pub severity: EventSeverity,
}

/// Severity of a deployment event.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum EventSeverity {
    Info,
    Success,
    Warning,
    Error,
}

impl EventSeverity {
    /// Get an icon for the severity.
    pub fn icon(&self) -> &'static str {
        match self {
            EventSeverity::Info => "ℹ",
            EventSeverity::Success => "✓",
            EventSeverity::Warning => "⚠",
            EventSeverity::Error => "✗",
        }
    }
}

/// Result of a Prometheus query.
#[derive(Debug, Clone, Deserialize)]
pub struct PrometheusResponse {
    pub status: String,
    pub data: PrometheusData,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PrometheusData {
    #[serde(rename = "resultType")]
    pub result_type: String,
    pub result: Vec<PrometheusResult>,
}

#[derive(Debug, Clone, Deserialize)]
pub struct PrometheusResult {
    pub metric: serde_json::Value,
    pub value: (f64, String),
}

/// Result of an SSH command execution.
#[derive(Debug, Clone)]
pub struct ExecResult {
    /// Exit code of the command.
    pub exit_code: i32,
    /// Standard output.
    pub stdout: String,
    /// Standard error.
    pub stderr: String,
}

impl ExecResult {
    /// Check if the command succeeded (exit code 0).
    pub fn success(&self) -> bool {
        self.exit_code == 0
    }
}

/// Status of a deployment operation.
#[derive(Debug, Clone)]
pub enum DeploymentStatus {
    /// Deployment not started.
    Idle,
    /// Building the configuration.
    Building,
    /// Activating the configuration.
    Activating,
    /// Deployment completed successfully.
    Success,
    /// Deployment failed.
    Failed { error: String },
}
