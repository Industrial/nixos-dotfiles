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

use crate::capabilities::{
    BatteryService, BluetoothService, SessionService, SystemInfoService, TimeService,
};
use crate::domain::{
    BatteryStatus, BluetoothState, CpuLoad, SessionAction, ThermalSensors, Workspace,
};

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

// === D-Bus Providers (Wave 2) ===

/// Live implementation of BluetoothService using D-Bus (bluez).
pub struct LiveBluetoothService {
    state: Mutex<BluetoothState>,
}

impl LiveBluetoothService {
    pub fn new() -> Self {
        let service = Self {
            state: Mutex::new(BluetoothState::default()),
        };
        service.refresh();
        service
    }

    fn query_bluetooth_state() -> BluetoothState {
        // Try to connect to system bus and query bluez
        let Ok(connection) = zbus::blocking::Connection::system() else {
            return BluetoothState::default();
        };

        // Query adapter properties via D-Bus
        let Some(proxy) = zbus::blocking::fdo::PropertiesProxy::builder(&connection)
            .destination("org.bluez")
            .ok()
            .and_then(|b| b.path("/org/bluez/hci0").ok())
            .and_then(|b| b.build().ok())
        else {
            return BluetoothState::default();
        };

        let powered = proxy
            .get(
                "org.bluez.Adapter1".try_into().unwrap(),
                "Powered".try_into().unwrap(),
            )
            .ok()
            .and_then(|v| <bool>::try_from(v).ok())
            .unwrap_or(false);

        // Get connected devices by querying object manager
        let connected_devices = Self::get_connected_devices(&connection);

        BluetoothState {
            powered,
            available: true,
            connected_devices,
        }
    }

    fn get_connected_devices(connection: &zbus::blocking::Connection) -> Vec<String> {
        let mut devices = Vec::new();

        // Query ObjectManager for all bluez objects
        let Some(proxy) = zbus::blocking::fdo::ObjectManagerProxy::builder(connection)
            .destination("org.bluez")
            .ok()
            .and_then(|b| b.path("/").ok())
            .and_then(|b| b.build().ok())
        else {
            return devices;
        };

        let Ok(objects) = proxy.get_managed_objects() else {
            return devices;
        };

        // Look for Device1 interfaces with Connected=true
        for (path, interfaces) in objects {
            if let Some(device_props) = interfaces.get("org.bluez.Device1") {
                let connected = device_props
                    .get("Connected")
                    .and_then(|v| <bool>::try_from(v.clone()).ok())
                    .unwrap_or(false);

                if connected {
                    let name = device_props
                        .get("Name")
                        .and_then(|v| <String>::try_from(v.clone()).ok())
                        .unwrap_or_else(|| path.to_string());
                    devices.push(name);
                }
            }
        }

        devices
    }
}

impl Default for LiveBluetoothService {
    fn default() -> Self {
        Self::new()
    }
}

impl BluetoothService for LiveBluetoothService {
    fn get_state(&self) -> BluetoothState {
        self.state.lock().unwrap().clone()
    }

    fn toggle_power(&self) {
        let current = self.state.lock().unwrap().powered;

        // Toggle via D-Bus
        if let Ok(connection) = zbus::blocking::Connection::system() {
            if let Some(proxy) = zbus::blocking::fdo::PropertiesProxy::builder(&connection)
                .destination("org.bluez")
                .ok()
                .and_then(|b| b.path("/org/bluez/hci0").ok())
                .and_then(|b| b.build().ok())
            {
                let _ = proxy.set(
                    "org.bluez.Adapter1".try_into().unwrap(),
                    "Powered",
                    zbus::zvariant::Value::from(!current).try_into().unwrap(),
                );
            }
        }

        // Refresh state after toggle
        self.refresh();
    }

    fn refresh(&self) {
        let new_state = Self::query_bluetooth_state();
        *self.state.lock().unwrap() = new_state;
    }
}

/// Live implementation of SessionService using D-Bus (logind).
pub struct LiveSessionService;

impl SessionService for LiveSessionService {
    fn execute(&self, action: SessionAction) {
        match action {
            SessionAction::Lock => {
                // Use loginctl lock-session
                let _ = std::process::Command::new("loginctl")
                    .arg("lock-session")
                    .spawn();
            }
            SessionAction::Logout => {
                // Use hyprctl dispatch exit
                let _ = std::process::Command::new("hyprctl")
                    .args(["dispatch", "exit"])
                    .spawn();
            }
            SessionAction::Suspend => {
                // Use systemctl suspend
                let _ = std::process::Command::new("systemctl")
                    .arg("suspend")
                    .spawn();
            }
            SessionAction::Reboot => {
                // Use systemctl reboot
                let _ = std::process::Command::new("systemctl")
                    .arg("reboot")
                    .spawn();
            }
            SessionAction::Shutdown => {
                // Use systemctl poweroff
                let _ = std::process::Command::new("systemctl")
                    .arg("poweroff")
                    .spawn();
            }
        }
    }

    fn is_available(&self, _action: SessionAction) -> bool {
        // All actions are available on a standard systemd system
        true
    }
}

/// Create the live provider set.
pub fn live_providers() -> (
    Arc<LiveHyprlandIpc>,
    Arc<LiveTimeService>,
    Arc<LiveSystemInfoService>,
    Arc<LiveBatteryService>,
    Arc<LiveBluetoothService>,
    Arc<LiveSessionService>,
) {
    (
        Arc::new(LiveHyprlandIpc),
        Arc::new(LiveTimeService),
        Arc::new(LiveSystemInfoService::new()),
        Arc::new(LiveBatteryService),
        Arc::new(LiveBluetoothService::new()),
        Arc::new(LiveSessionService),
    )
}
