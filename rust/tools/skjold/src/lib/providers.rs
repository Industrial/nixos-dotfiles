//! Live implementations of capabilities.
//!
//! For MVP, we use direct hyprland-rs calls rather than id_effect wrappers
//! to simplify Iced integration. Full id_effect integration comes in Wave 2.

use std::sync::{Arc, Mutex};

use chrono::Local;
use hyprland::data::{Workspace as HyprWorkspace, Workspaces};
use hyprland::dispatch::{Dispatch, DispatchType, WorkspaceIdentifierWithSpecial};
use hyprland::shared::{HyprData, HyprDataActive};
use sysinfo::{Components, System};

use crate::capabilities::{BatteryService, SystemInfoService, TimeService};
use crate::domain::{BatteryStatus, CpuLoad, ThermalSensors, Workspace};

/// Live implementation of TimeService.
pub struct LiveTimeService;

impl TimeService for LiveTimeService {
    fn now(&self) -> chrono::DateTime<Local> {
        Local::now()
    }
}

/// Live implementation of HyprlandIpc using hyprland-rs.
pub struct LiveHyprlandIpc;

impl LiveHyprlandIpc {
    /// Get all workspaces.
    pub fn get_workspaces(&self) -> Result<Vec<Workspace>, String> {
        let workspaces = Workspaces::get().map_err(|e| e.to_string())?;

        Ok(workspaces
            .iter()
            .map(|ws| Workspace {
                id: ws.id,
                name: ws.name.clone(),
                monitor: ws.monitor.clone(),
                windows: ws.windows as u32,
                has_fullscreen: ws.fullscreen,
                last_window_title: ws.last_window_title.clone(),
            })
            .collect())
    }

    /// Get the currently active workspace.
    pub fn get_active_workspace(&self) -> Result<Workspace, String> {
        let ws = HyprWorkspace::get_active().map_err(|e| e.to_string())?;

        Ok(Workspace {
            id: ws.id,
            name: ws.name,
            monitor: ws.monitor,
            windows: ws.windows as u32,
            has_fullscreen: ws.fullscreen,
            last_window_title: ws.last_window_title,
        })
    }

    /// Switch to a workspace by ID.
    pub fn switch_workspace(&self, id: i32) -> Result<(), String> {
        Dispatch::call(DispatchType::Workspace(WorkspaceIdentifierWithSpecial::Id(
            id,
        )))
        .map_err(|e| e.to_string())
    }
}

// === System Info Providers (Wave 1) ===

/// Live implementation of SystemInfoService using sysinfo crate.
pub struct LiveSystemInfoService {
    system: Mutex<System>,
    components: Mutex<Components>,
}

impl LiveSystemInfoService {
    pub fn new() -> Self {
        let mut system = System::new_all();
        system.refresh_all();
        Self {
            system: Mutex::new(system),
            components: Mutex::new(Components::new_with_refreshed_list()),
        }
    }
}

impl Default for LiveSystemInfoService {
    fn default() -> Self {
        Self::new()
    }
}

impl SystemInfoService for LiveSystemInfoService {
    fn get_cpu_load(&self) -> CpuLoad {
        let system = self.system.lock().unwrap();
        let usage = system.global_cpu_usage();
        CpuLoad {
            usage_percent: usage,
        }
    }

    fn get_thermal(&self) -> ThermalSensors {
        let components = self.components.lock().unwrap();
        // Look for CPU temperature sensor
        let cpu_temp = components
            .iter()
            .find(|c| {
                let label = c.label().to_lowercase();
                label.contains("cpu") || label.contains("core") || label.contains("package")
            })
            .map(|c| c.temperature());

        ThermalSensors {
            cpu_temp_celsius: cpu_temp.flatten(),
        }
    }

    fn refresh(&self) {
        let mut system = self.system.lock().unwrap();
        system.refresh_cpu_all();
        drop(system);

        let mut components = self.components.lock().unwrap();
        components.refresh(true);
    }
}

/// Live implementation of BatteryService.
/// Reads from /sys/class/power_supply/BAT*/
pub struct LiveBatteryService;

impl BatteryService for LiveBatteryService {
    fn get_status(&self) -> BatteryStatus {
        // Try common battery paths
        for bat in &["BAT0", "BAT1", "BATT"] {
            let base = format!("/sys/class/power_supply/{}", bat);
            if let Ok(capacity) = std::fs::read_to_string(format!("{}/capacity", base)) {
                let percentage = capacity.trim().parse().unwrap_or(0);
                let status =
                    std::fs::read_to_string(format!("{}/status", base)).unwrap_or_default();
                let charging = status.trim().eq_ignore_ascii_case("charging");

                return BatteryStatus {
                    percentage,
                    charging,
                    present: true,
                };
            }
        }

        // No battery found
        BatteryStatus::default()
    }
}

/// Create the live provider set.
pub fn live_providers() -> (
    Arc<LiveHyprlandIpc>,
    Arc<LiveTimeService>,
    Arc<LiveSystemInfoService>,
    Arc<LiveBatteryService>,
) {
    (
        Arc::new(LiveHyprlandIpc),
        Arc::new(LiveTimeService),
        Arc::new(LiveSystemInfoService::new()),
        Arc::new(LiveBatteryService),
    )
}
