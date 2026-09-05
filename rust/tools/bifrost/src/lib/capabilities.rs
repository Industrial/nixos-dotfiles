//! Capability traits for Bifröst.
//!
//! Following Skjold's pattern: traits define interfaces, providers implement them.

use crate::domain::{
    DeploymentStatus, ExecResult, Generation, Host, HostStatus, PrometheusResponse, SystemMetrics,
};

/// Capability for fleet discovery and status.
pub trait FleetDiscovery: Send + Sync {
    /// Get all known hosts in the fleet.
    fn get_hosts(&self) -> Vec<Host>;

    /// Get the status of a specific host.
    fn get_host_status(&self, host: &str) -> HostStatus;

    /// Refresh the fleet state.
    fn refresh(&self);
}

/// Capability for Prometheus queries.
pub trait PrometheusService: Send + Sync {
    /// Execute an instant query.
    fn query(&self, query: &str) -> Result<PrometheusResponse, PrometheusError>;

    /// Get system metrics for a host.
    fn get_metrics(&self, host: &str) -> Result<SystemMetrics, PrometheusError>;

    /// Check if Prometheus is reachable.
    fn is_available(&self) -> bool;
}

/// Errors from Prometheus operations.
#[derive(Debug, thiserror::Error)]
pub enum PrometheusError {
    #[error("HTTP request failed: {0}")]
    Http(#[from] reqwest::Error),

    #[error("Failed to parse response: {0}")]
    Parse(String),

    #[error("Query failed: {0}")]
    Query(String),

    #[error("Prometheus unavailable")]
    Unavailable,
}

/// Capability for SSH operations.
pub trait SshService: Send + Sync {
    /// Check if a host is reachable via SSH.
    fn is_reachable(&self, host: &str) -> bool;

    /// Execute a command on a remote host.
    fn exec(&self, host: &str, command: &str) -> Result<ExecResult, SshError>;

    /// Execute a command with sudo.
    fn exec_sudo(&self, host: &str, command: &str) -> Result<ExecResult, SshError>;
}

/// Errors from SSH operations.
#[derive(Debug, thiserror::Error)]
pub enum SshError {
    #[error("Connection failed: {0}")]
    Connection(String),

    #[error("Authentication failed: {0}")]
    Auth(String),

    #[error("Command execution failed: {0}")]
    Exec(String),

    #[error("Key loading failed: {0}")]
    Key(String),

    #[error("Host unreachable: {0}")]
    Unreachable(String),
}

/// Capability for NixOS operations.
pub trait NixOpsService: Send + Sync {
    /// Get the current generation info for a host.
    fn get_generation(&self, host: &str) -> Result<Generation, NixOpsError>;

    /// List all generations for a host.
    fn list_generations(&self, host: &str) -> Result<Vec<Generation>, NixOpsError>;

    /// Get the NixOS version string for a host.
    fn get_version(&self, host: &str) -> Result<String, NixOpsError>;

    /// Deploy to a host (runs bin/fleet deploy).
    fn deploy(&self, host: &str) -> Result<DeploymentStatus, NixOpsError>;

    /// Rollback to a previous generation.
    fn rollback(&self, host: &str, generation: u32) -> Result<(), NixOpsError>;
}

/// Errors from NixOS operations.
#[derive(Debug, thiserror::Error)]
pub enum NixOpsError {
    #[error("SSH error: {0}")]
    Ssh(#[from] SshError),

    #[error("Failed to parse generation info: {0}")]
    Parse(String),

    #[error("Deployment failed: {0}")]
    Deploy(String),

    #[error("Rollback failed: {0}")]
    Rollback(String),
}
