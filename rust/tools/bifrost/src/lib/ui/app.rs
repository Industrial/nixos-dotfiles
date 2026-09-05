//! Main Iced application for Bifröst.

use std::sync::Arc;
use std::time::Duration;

use chrono::Utc;
use iced::widget::{Space, column, container, row};
use iced::{Element, Length, Subscription, Task};

use crate::capabilities::{FleetDiscovery, NixOpsService, PrometheusService, SshService};
use crate::domain::{DeploymentEvent, DeploymentStatus, EventSeverity, Host, HostStatus};
use crate::providers::{
    LiveFleetDiscovery, LiveNixOpsService, LivePrometheusService, LiveSshService,
};
use crate::ui::widgets::{event_log_widget, node_card_widget, toolbar_widget};

/// Messages for the Bifröst application.
#[derive(Debug, Clone)]
pub enum Message {
    /// Refresh all host data.
    Refresh,
    /// Metrics tick — update Prometheus data.
    MetricsTick,
    /// Deploy to a specific host.
    DeployHost(String),
    /// Deploy to all hosts.
    DeployAll,
    /// Host metrics updated.
    MetricsUpdated(String, Result<crate::domain::SystemMetrics, String>),
    /// Host status updated.
    StatusUpdated(String, bool),
    /// Deployment completed.
    DeploymentComplete(String, DeploymentStatus),
    /// NixOS version fetched.
    VersionFetched(String, Result<String, String>),
}

/// The main Bifröst application state.
pub struct BifrostApp {
    /// Fleet discovery service (reserved for dynamic fleet updates).
    #[allow(dead_code)]
    fleet: Arc<LiveFleetDiscovery>,
    /// Prometheus service.
    prometheus: Arc<LivePrometheusService>,
    /// SSH service.
    ssh: Arc<LiveSshService>,
    /// NixOps service.
    nixops: Arc<LiveNixOpsService>,
    /// Current hosts state.
    hosts: Vec<Host>,
    /// Deployment events.
    events: Vec<DeploymentEvent>,
    /// Whether initial load is complete.
    initialized: bool,
}

impl BifrostApp {
    /// Create a new Bifröst application.
    pub fn new(
        fleet: Arc<LiveFleetDiscovery>,
        prometheus: Arc<LivePrometheusService>,
        ssh: Arc<LiveSshService>,
        nixops: Arc<LiveNixOpsService>,
    ) -> (Self, Task<Message>) {
        let hosts = fleet.get_hosts();

        let app = Self {
            fleet,
            prometheus,
            ssh,
            nixops,
            hosts,
            events: Vec::new(),
            initialized: false,
        };

        // Trigger initial refresh
        (app, Task::done(Message::Refresh))
    }

    /// Handle messages.
    pub fn update(&mut self, message: Message) -> Task<Message> {
        match message {
            Message::Refresh => {
                // Spawn tasks to check each host
                let tasks: Vec<Task<Message>> = self
                    .hosts
                    .iter()
                    .map(|host| {
                        let name = host.name.clone();
                        let name2 = name.clone();
                        let ssh = self.ssh.clone();

                        Task::perform(
                            async move {
                                // Run SSH check in blocking task
                                tokio::task::spawn_blocking(move || ssh.is_reachable(&name))
                                    .await
                                    .unwrap_or(false)
                            },
                            move |reachable| Message::StatusUpdated(name2, reachable),
                        )
                    })
                    .collect();

                Task::batch(tasks)
            }

            Message::MetricsTick => {
                // Update metrics for each host
                let tasks: Vec<Task<Message>> = self
                    .hosts
                    .iter()
                    .filter(|h| h.status.is_healthy())
                    .map(|host| {
                        let name = host.name.clone();
                        let name2 = name.clone();
                        let prometheus = self.prometheus.clone();

                        Task::perform(
                            async move {
                                tokio::task::spawn_blocking(move || prometheus.get_metrics(&name))
                                    .await
                                    .map_err(|e| e.to_string())
                                    .and_then(|r| r.map_err(|e| e.to_string()))
                            },
                            move |result| Message::MetricsUpdated(name2, result),
                        )
                    })
                    .collect();

                Task::batch(tasks)
            }

            Message::StatusUpdated(name, reachable) => {
                if let Some(host) = self.hosts.iter_mut().find(|h| h.name == name) {
                    host.status = if reachable {
                        HostStatus::Online {
                            uptime: Duration::from_secs(0),
                        }
                    } else {
                        HostStatus::Unreachable
                    };
                }

                // If host is online, fetch its NixOS version
                if reachable {
                    let nixops = self.nixops.clone();
                    let host_name = name.clone();
                    let host_name2 = name.clone();

                    return Task::perform(
                        async move {
                            tokio::task::spawn_blocking(move || nixops.get_version(&host_name))
                                .await
                                .map_err(|e| e.to_string())
                                .and_then(|r| r.map_err(|e| e.to_string()))
                        },
                        move |result| Message::VersionFetched(host_name2, result),
                    );
                }

                Task::none()
            }

            Message::MetricsUpdated(name, result) => {
                if let Some(host) = self.hosts.iter_mut().find(|h| h.name == name) {
                    match result {
                        Ok(metrics) => host.metrics = Some(metrics),
                        Err(_) => {} // Keep existing metrics on error
                    }
                }
                Task::none()
            }

            Message::VersionFetched(name, result) => {
                if let Some(host) = self.hosts.iter_mut().find(|h| h.name == name) {
                    if let Ok(version) = result {
                        host.nixos_generation = Some(crate::domain::Generation {
                            number: 0, // Will be updated separately
                            date: Utc::now(),
                            nixos_version: version,
                            current: true,
                        });
                    }
                }
                self.initialized = true;
                Task::none()
            }

            Message::DeployHost(name) => {
                // Mark host as deploying
                if let Some(host) = self.hosts.iter_mut().find(|h| h.name == name) {
                    host.status = HostStatus::Deploying;
                }

                // Add event
                self.events.push(DeploymentEvent {
                    timestamp: Utc::now(),
                    host: name.clone(),
                    message: "Deployment started".to_string(),
                    severity: EventSeverity::Info,
                });

                // Run deployment
                let nixops = self.nixops.clone();
                let host_name = name.clone();

                Task::perform(
                    async move {
                        tokio::task::spawn_blocking(move || nixops.deploy(&host_name))
                            .await
                            .unwrap_or(Ok(DeploymentStatus::Failed {
                                error: "Task failed".to_string(),
                            }))
                            .unwrap_or(DeploymentStatus::Failed {
                                error: "Unknown error".to_string(),
                            })
                    },
                    move |status| Message::DeploymentComplete(name, status),
                )
            }

            Message::DeployAll => {
                let tasks: Vec<Task<Message>> = self
                    .hosts
                    .iter()
                    .filter(|h| h.status.is_healthy())
                    .map(|h| Task::done(Message::DeployHost(h.name.clone())))
                    .collect();

                Task::batch(tasks)
            }

            Message::DeploymentComplete(name, status) => {
                // Update host status
                if let Some(host) = self.hosts.iter_mut().find(|h| h.name == name) {
                    host.status = HostStatus::Online {
                        uptime: Duration::from_secs(0),
                    };
                }

                // Add event
                let (message, severity) = match &status {
                    DeploymentStatus::Success => {
                        ("Deployment completed".to_string(), EventSeverity::Success)
                    }
                    DeploymentStatus::Failed { error } => (
                        format!("Deployment failed: {}", error),
                        EventSeverity::Error,
                    ),
                    _ => (
                        "Deployment status unknown".to_string(),
                        EventSeverity::Warning,
                    ),
                };

                self.events.push(DeploymentEvent {
                    timestamp: Utc::now(),
                    host: name,
                    message,
                    severity,
                });

                Task::none()
            }
        }
    }

    /// Render the application.
    pub fn view(&self) -> Element<'_, Message> {
        // Count online hosts
        let hosts_online = self.hosts.iter().filter(|h| h.status.is_healthy()).count();
        let hosts_total = self.hosts.len();

        // Toolbar
        let toolbar = toolbar_widget(
            hosts_online,
            hosts_total,
            Message::DeployAll,
            Message::Refresh,
        );

        // Node cards
        let cards: Vec<Element<'_, Message>> = self
            .hosts
            .iter()
            .map(|host| node_card_widget(host, Message::DeployHost(host.name.clone())))
            .collect();

        let cards_row = row(cards).spacing(16).padding(16);

        // Event log
        let event_log = event_log_widget(&self.events);

        // Main layout
        let content = column![
            toolbar,
            container(cards_row).width(Length::Fill),
            Space::new().height(Length::Fill),
            event_log,
        ];

        container(content)
            .width(Length::Fill)
            .height(Length::Fill)
            .into()
    }

    /// Get the number of hosts.
    pub fn host_count(&self) -> usize {
        self.hosts.len()
    }

    /// Background subscriptions.
    pub fn subscription(&self) -> Subscription<Message> {
        // Refresh metrics every 5 seconds
        iced::time::every(Duration::from_secs(5)).map(|_| Message::MetricsTick)
    }
}
