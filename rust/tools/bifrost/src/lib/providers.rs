//! Live provider implementations for Bifröst.
//!
//! Concrete implementations of capability traits.

use std::collections::HashMap;
use std::process::Command;
use std::sync::{Arc, Mutex};
use std::time::Duration;

use chrono::Utc;

use crate::capabilities::{
    FleetDiscovery, NixOpsError, NixOpsService, PrometheusError, PrometheusService, SshError,
    SshService,
};
use crate::domain::{
    DeploymentStatus, ExecResult, Generation, Host, HostStatus, PrometheusResponse, SystemMetrics,
};

// =============================================================================
// Fleet Discovery
// =============================================================================

/// Live implementation of fleet discovery.
pub struct LiveFleetDiscovery {
    /// Known hosts (hardcoded for now).
    hosts: Mutex<Vec<Host>>,
}

impl LiveFleetDiscovery {
    /// Create a new fleet discovery with hardcoded hosts.
    pub fn new() -> Self {
        let hosts = vec![
            Host::new("drakkar"),
            Host::new("huginn"),
            Host::new("mimir"),
        ];
        Self {
            hosts: Mutex::new(hosts),
        }
    }
}

impl Default for LiveFleetDiscovery {
    fn default() -> Self {
        Self::new()
    }
}

impl FleetDiscovery for LiveFleetDiscovery {
    fn get_hosts(&self) -> Vec<Host> {
        self.hosts.lock().unwrap().clone()
    }

    fn get_host_status(&self, host: &str) -> HostStatus {
        self.hosts
            .lock()
            .unwrap()
            .iter()
            .find(|h| h.name == host)
            .map(|h| h.status.clone())
            .unwrap_or(HostStatus::Unknown)
    }

    fn refresh(&self) {
        // Will be implemented to update host status via SSH/Prometheus
    }
}

// =============================================================================
// Prometheus Service (Node Exporter)
// =============================================================================

/// Live implementation that queries node exporters directly on each host.
///
/// Each host runs a node exporter on port 9002, exposing metrics at /metrics
/// in Prometheus text format.
pub struct LivePrometheusService {
    /// Node exporter port.
    port: u16,
    /// HTTP client.
    client: reqwest::blocking::Client,
    /// Cached metrics per host.
    cache: Mutex<HashMap<String, SystemMetrics>>,
}

impl LivePrometheusService {
    /// Create a new Prometheus service querying node exporters on port 9002.
    pub fn new(_url: String) -> Self {
        Self {
            port: 9002,
            client: reqwest::blocking::Client::builder()
                .timeout(Duration::from_secs(5))
                .build()
                .unwrap(),
            cache: Mutex::new(HashMap::new()),
        }
    }

    /// Fetch and parse metrics from a host's node exporter.
    fn fetch_metrics_text(&self, host: &str) -> Result<String, PrometheusError> {
        let url = format!("http://{}:{}/metrics", host, self.port);
        let response = self.client.get(&url).send()?.text()?;
        Ok(response)
    }

    /// Extract a metric value from Prometheus text format.
    fn extract_metric(&self, text: &str, metric_name: &str, labels: Option<&str>) -> Option<f32> {
        for line in text.lines() {
            if line.starts_with('#') || line.is_empty() {
                continue;
            }

            // Check if line starts with metric name
            if !line.starts_with(metric_name) {
                continue;
            }

            // If labels specified, check they're present
            if let Some(label_filter) = labels {
                if !line.contains(label_filter) {
                    continue;
                }
            }

            // Extract value (last space-separated token)
            if let Some(value_str) = line.split_whitespace().last() {
                if let Ok(value) = value_str.parse::<f32>() {
                    return Some(value);
                }
            }
        }
        None
    }
}

impl PrometheusService for LivePrometheusService {
    fn query(&self, _query: &str) -> Result<PrometheusResponse, PrometheusError> {
        // Not used - we query node exporters directly
        Err(PrometheusError::Query(
            "Direct PromQL queries not supported; use get_metrics()".to_string(),
        ))
    }

    fn get_metrics(&self, host: &str) -> Result<SystemMetrics, PrometheusError> {
        let text = self.fetch_metrics_text(host)?;

        // Memory: (1 - available/total) * 100
        let mem_available = self
            .extract_metric(&text, "node_memory_MemAvailable_bytes", None)
            .unwrap_or(0.0);
        let mem_total = self
            .extract_metric(&text, "node_memory_MemTotal_bytes", None)
            .unwrap_or(1.0);
        let memory = if mem_total > 0.0 {
            (1.0 - mem_available / mem_total) * 100.0
        } else {
            0.0
        };

        // Disk: (1 - available/size) * 100 for root filesystem
        let disk_avail = self
            .extract_metric(
                &text,
                "node_filesystem_avail_bytes",
                Some("mountpoint=\"/\""),
            )
            .unwrap_or(0.0);
        let disk_size = self
            .extract_metric(
                &text,
                "node_filesystem_size_bytes",
                Some("mountpoint=\"/\""),
            )
            .unwrap_or(1.0);
        let disk = if disk_size > 0.0 {
            (1.0 - disk_avail / disk_size) * 100.0
        } else {
            0.0
        };

        // Load average (1 minute)
        let load = self
            .extract_metric(&text, "node_load1", None)
            .unwrap_or(0.0);

        // CPU: Use load average normalized by CPU count as approximation
        let cpu_count = self
            .extract_metric(&text, "node_cpu_seconds_total", Some("cpu=\"0\""))
            .map(|_| {
                // Count how many CPUs we have
                text.lines()
                    .filter(|l| {
                        l.starts_with("node_cpu_seconds_total") && l.contains("mode=\"idle\"")
                    })
                    .count() as f32
            })
            .unwrap_or(1.0);
        let cpu = (load / cpu_count.max(1.0) * 100.0).min(100.0);

        // Temperature (thermal zone 0)
        let temperature = self.extract_metric(&text, "node_thermal_zone_temp", Some("zone=\"0\""));

        let metrics = SystemMetrics {
            cpu_percent: cpu,
            memory_percent: memory,
            disk_percent: disk,
            load_1m: load,
            temperature,
        };

        // Cache the result
        self.cache
            .lock()
            .unwrap()
            .insert(host.to_string(), metrics.clone());

        Ok(metrics)
    }

    fn is_available(&self) -> bool {
        // Check if any host's node exporter is reachable
        self.client
            .get(&format!("http://drakkar:{}/metrics", self.port))
            .send()
            .map(|r| r.status().is_success())
            .unwrap_or(false)
    }
}

// =============================================================================
// SSH Service
// =============================================================================

/// Live implementation of SSH operations.
///
/// Uses subprocess calls to ssh for simplicity. russh integration can be added later
/// for more control and better async support.
pub struct LiveSshService {
    /// SSH user.
    user: String,
    /// SSH key path.
    key_path: String,
    /// Connection timeout in seconds.
    timeout: u64,
}

impl LiveSshService {
    /// Create a new SSH service.
    pub fn new() -> Self {
        let home = dirs::home_dir().unwrap_or_default();
        Self {
            user: "tom".to_string(),
            key_path: home.join(".ssh/id_ed25519").to_string_lossy().to_string(),
            timeout: 5,
        }
    }

    /// Build SSH command arguments.
    fn ssh_args(&self, host: &str) -> Vec<String> {
        vec![
            "-o".to_string(),
            format!("ConnectTimeout={}", self.timeout),
            "-o".to_string(),
            "BatchMode=yes".to_string(),
            "-o".to_string(),
            "StrictHostKeyChecking=accept-new".to_string(),
            "-i".to_string(),
            self.key_path.clone(),
            format!("{}@{}", self.user, host),
        ]
    }
}

impl Default for LiveSshService {
    fn default() -> Self {
        Self::new()
    }
}

impl SshService for LiveSshService {
    fn is_reachable(&self, host: &str) -> bool {
        let mut args = self.ssh_args(host);
        args.push("true".to_string());

        Command::new("ssh")
            .args(&args)
            .output()
            .map(|o| o.status.success())
            .unwrap_or(false)
    }

    fn exec(&self, host: &str, command: &str) -> Result<ExecResult, SshError> {
        let mut args = self.ssh_args(host);
        args.push(command.to_string());

        let output = Command::new("ssh")
            .args(&args)
            .output()
            .map_err(|e| SshError::Exec(e.to_string()))?;

        Ok(ExecResult {
            exit_code: output.status.code().unwrap_or(-1),
            stdout: String::from_utf8_lossy(&output.stdout).to_string(),
            stderr: String::from_utf8_lossy(&output.stderr).to_string(),
        })
    }

    fn exec_sudo(&self, host: &str, command: &str) -> Result<ExecResult, SshError> {
        self.exec(host, &format!("sudo {}", command))
    }
}

// =============================================================================
// NixOps Service
// =============================================================================

/// Live implementation of NixOS operations.
pub struct LiveNixOpsService {
    /// SSH service for remote commands.
    ssh: Arc<LiveSshService>,
}

impl LiveNixOpsService {
    /// Create a new NixOps service.
    pub fn new(ssh: Arc<LiveSshService>) -> Self {
        Self { ssh }
    }
}

impl NixOpsService for LiveNixOpsService {
    fn get_generation(&self, host: &str) -> Result<Generation, NixOpsError> {
        // Get current system link
        let result = self.ssh.exec(host, "readlink /run/current-system")?;
        if !result.success() {
            return Err(NixOpsError::Parse(
                "Failed to read current system".to_string(),
            ));
        }

        // Extract generation number from path (e.g., /nix/store/...-nixos-system-hostname-24.11...)
        let version = self.get_version(host)?;

        // Get generation number
        let gen_result = self.ssh.exec(
            host,
            "nix-env --list-generations -p /nix/var/nix/profiles/system | tail -1 | awk '{print $1}'",
        )?;

        let number = gen_result.stdout.trim().parse::<u32>().unwrap_or(0);

        Ok(Generation {
            number,
            date: Utc::now(), // Approximate - could parse from generation output
            nixos_version: version,
            current: true,
        })
    }

    fn list_generations(&self, host: &str) -> Result<Vec<Generation>, NixOpsError> {
        let result = self.ssh.exec(
            host,
            "nix-env --list-generations -p /nix/var/nix/profiles/system",
        )?;

        if !result.success() {
            return Err(NixOpsError::Parse("Failed to list generations".to_string()));
        }

        // Parse output: "  42   2024-01-15 10:30:00   (current)"
        let generations = result
            .stdout
            .lines()
            .filter_map(|line| {
                let parts: Vec<&str> = line.split_whitespace().collect();
                if parts.is_empty() {
                    return None;
                }

                let number = parts[0].parse::<u32>().ok()?;
                let current = line.contains("(current)");

                Some(Generation {
                    number,
                    date: Utc::now(), // Simplified - could parse date from output
                    nixos_version: String::new(),
                    current,
                })
            })
            .collect();

        Ok(generations)
    }

    fn get_version(&self, host: &str) -> Result<String, NixOpsError> {
        let result = self.ssh.exec(host, "nixos-version")?;
        if result.success() {
            Ok(result.stdout.trim().to_string())
        } else {
            Err(NixOpsError::Parse(
                "Failed to get NixOS version".to_string(),
            ))
        }
    }

    fn deploy(&self, host: &str) -> Result<DeploymentStatus, NixOpsError> {
        // Use the fleet deploy script
        let output = Command::new("bash")
            .args([
                "-c",
                &format!("cd ~/.dotfiles && bin/fleet deploy {}", host),
            ])
            .output()
            .map_err(|e| NixOpsError::Deploy(e.to_string()))?;

        if output.status.success() {
            Ok(DeploymentStatus::Success)
        } else {
            let error = String::from_utf8_lossy(&output.stderr).to_string();
            Ok(DeploymentStatus::Failed { error })
        }
    }

    fn rollback(&self, host: &str, generation: u32) -> Result<(), NixOpsError> {
        let cmd = format!(
            "sudo nix-env -p /nix/var/nix/profiles/system --switch-generation {} && sudo /nix/var/nix/profiles/system/bin/switch-to-configuration switch",
            generation
        );

        let result = self.ssh.exec(host, &cmd)?;
        if result.success() {
            Ok(())
        } else {
            Err(NixOpsError::Rollback(result.stderr))
        }
    }
}
