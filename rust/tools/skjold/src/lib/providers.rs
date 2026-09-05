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
    AudioService, BatteryService, BluetoothService, LauncherService, NetworkService,
    SessionService, SystemInfoService, TimeService, WorkspaceService,
};
use crate::domain::{
    AudioState, BatteryStatus, BluetoothState, CpuLoad, LauncherEntry, NetworkState, NetworkType,
    SessionAction, ThermalSensors, Workspace,
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

// === Launcher Providers (Wave 3) ===

/// Live implementation of LauncherService.
/// Parses .desktop files and provides fuzzy search.
pub struct LiveLauncherService {
    entries: Mutex<Vec<LauncherEntry>>,
}

impl LiveLauncherService {
    pub fn new() -> Self {
        let service = Self {
            entries: Mutex::new(Vec::new()),
        };
        service.refresh();
        service
    }

    fn parse_desktop_files() -> Vec<LauncherEntry> {
        use freedesktop_desktop_entry::{DesktopEntry, Iter, default_paths};

        let mut entries = Vec::new();
        let locales: &[&str] = &[];

        // Use default XDG paths - Iter::new takes the paths slice directly
        for entry_path in Iter::new(default_paths()) {
            let Ok(de) = DesktopEntry::from_path(&entry_path, None::<&[&str]>) else {
                continue;
            };

            // Skip hidden and NoDisplay entries
            if de.no_display() || de.hidden() {
                continue;
            }

            // Skip entries without Exec
            let Some(exec) = de.exec() else {
                continue;
            };

            entries.push(LauncherEntry {
                name: de.name(locales).map(|s| s.to_string()).unwrap_or_default(),
                generic_name: de.generic_name(locales).map(|s| s.to_string()),
                comment: de.comment(locales).map(|s| s.to_string()),
                exec: exec.to_string(),
                icon: de.icon().map(|s| s.to_string()),
                categories: de
                    .categories()
                    .map(|cats| cats.into_iter().map(|s| s.to_string()).collect())
                    .unwrap_or_default(),
                terminal: de.terminal(),
                desktop_path: entry_path.to_string_lossy().to_string(),
            });
        }

        // Sort by name and deduplicate
        entries.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
        entries.dedup_by(|a, b| a.name == b.name);
        entries
    }
}

impl Default for LiveLauncherService {
    fn default() -> Self {
        Self::new()
    }
}

impl LauncherService for LiveLauncherService {
    fn get_entries(&self) -> Vec<LauncherEntry> {
        self.entries.lock().unwrap().clone()
    }

    fn search(&self, query: &str) -> Vec<usize> {
        use fuzzy_matcher::FuzzyMatcher;
        use fuzzy_matcher::skim::SkimMatcherV2;

        if query.is_empty() {
            // Return all indices
            return (0..self.entries.lock().unwrap().len()).collect();
        }

        let entries = self.entries.lock().unwrap();
        let matcher = SkimMatcherV2::default();

        let mut scored: Vec<(usize, i64)> = entries
            .iter()
            .enumerate()
            .filter_map(|(i, entry)| {
                // Match against name and generic name
                let name_score = matcher.fuzzy_match(&entry.name, query).unwrap_or(0);
                let generic_score = entry
                    .generic_name
                    .as_ref()
                    .and_then(|g| matcher.fuzzy_match(g, query))
                    .unwrap_or(0);

                let best_score = name_score.max(generic_score);
                if best_score > 0 {
                    Some((i, best_score))
                } else {
                    None
                }
            })
            .collect();

        // Sort by score descending
        scored.sort_by(|a, b| b.1.cmp(&a.1));
        scored.into_iter().map(|(i, _)| i).collect()
    }

    fn launch(&self, index: usize) {
        let entries = self.entries.lock().unwrap();
        let Some(entry) = entries.get(index) else {
            return;
        };

        // Parse exec command, removing field codes like %f, %u, etc.
        let exec = entry
            .exec
            .split_whitespace()
            .filter(|s| !s.starts_with('%'))
            .collect::<Vec<_>>()
            .join(" ");

        if entry.terminal {
            // Launch in terminal
            let _ = std::process::Command::new("foot")
                .args(["-e", "sh", "-c", &exec])
                .spawn();
        } else {
            // Launch directly via shell
            let _ = std::process::Command::new("sh").args(["-c", &exec]).spawn();
        }
    }

    fn refresh(&self) {
        let new_entries = Self::parse_desktop_files();
        *self.entries.lock().unwrap() = new_entries;
    }
}

// === Workspace Providers (Wave 4) ===

/// Live implementation of WorkspaceService using Hyprland IPC.
pub struct LiveWorkspaceService {
    workspaces: Mutex<Vec<Workspace>>,
    active_id: Mutex<Option<i32>>,
}

impl LiveWorkspaceService {
    pub fn new() -> Self {
        let service = Self {
            workspaces: Mutex::new(Vec::new()),
            active_id: Mutex::new(None),
        };
        service.refresh();
        service
    }
}

impl Default for LiveWorkspaceService {
    fn default() -> Self {
        Self::new()
    }
}

impl WorkspaceService for LiveWorkspaceService {
    fn get_workspaces(&self) -> Vec<Workspace> {
        self.workspaces.lock().unwrap().clone()
    }

    fn get_active(&self) -> Option<Workspace> {
        let active_id = *self.active_id.lock().unwrap();
        let workspaces = self.workspaces.lock().unwrap();
        active_id.and_then(|id| workspaces.iter().find(|w| w.id == id).cloned())
    }

    fn switch_to(&self, id: i32) {
        let _ = Dispatch::call(DispatchType::Workspace(WorkspaceIdentifierWithSpecial::Id(
            id,
        )));
        // Refresh after switch
        self.refresh();
    }

    fn refresh(&self) {
        // Get all workspaces
        if let Ok(ws_list) = Workspaces::get() {
            let workspaces: Vec<Workspace> = ws_list
                .iter()
                .map(|ws| Workspace {
                    id: ws.id,
                    name: ws.name.clone(),
                    monitor: ws.monitor.clone(),
                    windows: ws.windows as u32,
                    has_fullscreen: ws.fullscreen,
                    last_window_title: ws.last_window_title.clone(),
                })
                .collect();
            *self.workspaces.lock().unwrap() = workspaces;
        }

        // Get active workspace
        if let Ok(active) = HyprWorkspace::get_active() {
            *self.active_id.lock().unwrap() = Some(active.id);
        }
    }
}

// === Audio Service (Wave 5) ===

/// Live implementation of AudioService using PulseAudio.
pub struct LiveAudioService {
    state: Mutex<AudioState>,
}

impl LiveAudioService {
    pub fn new() -> Self {
        let state = Self::query_audio_state();
        Self {
            state: Mutex::new(state),
        }
    }

    fn query_audio_state() -> AudioState {
        use libpulse_binding::context::Context;
        use libpulse_binding::mainloop::standard::Mainloop;
        use libpulse_binding::proplist::Proplist;
        use std::cell::RefCell;
        use std::rc::Rc;

        let mut proplist = Proplist::new().unwrap();
        proplist
            .set_str(
                libpulse_binding::proplist::properties::APPLICATION_NAME,
                "skjold",
            )
            .ok();

        let mainloop = Rc::new(RefCell::new(
            Mainloop::new().expect("Failed to create PulseAudio mainloop"),
        ));
        let context = Rc::new(RefCell::new(
            Context::new_with_proplist(&*mainloop.borrow(), "skjold", &proplist)
                .expect("Failed to create PulseAudio context"),
        ));

        // Connect to PulseAudio
        context
            .borrow_mut()
            .connect(None, libpulse_binding::context::FlagSet::NOFLAGS, None)
            .expect("Failed to connect to PulseAudio");

        // Wait for connection
        loop {
            mainloop.borrow_mut().iterate(true);
            match context.borrow().get_state() {
                libpulse_binding::context::State::Ready => break,
                libpulse_binding::context::State::Failed
                | libpulse_binding::context::State::Terminated => {
                    return AudioState::default();
                }
                _ => {}
            }
        }

        // Get default sink info
        let result = Rc::new(RefCell::new(AudioState::default()));
        let result_clone = result.clone();
        let mainloop_clone = mainloop.clone();

        let introspect = context.borrow().introspect();
        let _op = introspect.get_server_info(move |info| {
            if let Some(sink_name) = &info.default_sink_name {
                result_clone.borrow_mut().sink_name = Some(sink_name.to_string());
            }
            mainloop_clone
                .borrow_mut()
                .quit(libpulse_binding::def::Retval(0));
        });

        mainloop.borrow_mut().run().ok();

        // Get sink volume info
        let result_clone = result.clone();
        let mainloop_clone = mainloop.clone();
        let sink_name = result.borrow().sink_name.clone();

        if let Some(name) = sink_name {
            let introspect = context.borrow().introspect();
            let _op = introspect.get_sink_info_by_name(&name, move |list| {
                if let libpulse_binding::callbacks::ListResult::Item(info) = list {
                    let volume = info.volume.avg();
                    let percent = (volume.0 as f64
                        / libpulse_binding::volume::Volume::NORMAL.0 as f64
                        * 100.0) as u32;
                    result_clone.borrow_mut().volume = percent.min(100);
                    result_clone.borrow_mut().muted = info.mute;
                    mainloop_clone
                        .borrow_mut()
                        .quit(libpulse_binding::def::Retval(0));
                }
            });

            mainloop.borrow_mut().run().ok();
        }

        // Return the result
        Rc::try_unwrap(result)
            .unwrap_or_else(|rc| RefCell::new(rc.borrow().clone()))
            .into_inner()
    }

    fn set_sink_volume(volume: u32) {
        use libpulse_binding::context::Context;
        use libpulse_binding::mainloop::standard::Mainloop;
        use libpulse_binding::proplist::Proplist;
        use libpulse_binding::volume::{ChannelVolumes, Volume};
        use std::cell::RefCell;
        use std::rc::Rc;

        let mut proplist = Proplist::new().unwrap();
        proplist
            .set_str(
                libpulse_binding::proplist::properties::APPLICATION_NAME,
                "skjold",
            )
            .ok();

        let mainloop = Rc::new(RefCell::new(Mainloop::new().unwrap()));
        let context = Rc::new(RefCell::new(
            Context::new_with_proplist(&*mainloop.borrow(), "skjold", &proplist).unwrap(),
        ));

        context
            .borrow_mut()
            .connect(None, libpulse_binding::context::FlagSet::NOFLAGS, None)
            .ok();

        loop {
            mainloop.borrow_mut().iterate(true);
            match context.borrow().get_state() {
                libpulse_binding::context::State::Ready => break,
                libpulse_binding::context::State::Failed
                | libpulse_binding::context::State::Terminated => return,
                _ => {}
            }
        }

        // Get default sink and set volume
        let mainloop_clone = mainloop.clone();
        let context_clone = context.clone();
        let volume_level = volume.min(100);

        let introspect = context.borrow().introspect();
        let _op = introspect.get_server_info(move |info| {
            if let Some(sink_name) = &info.default_sink_name {
                let name = sink_name.to_string();
                let mut introspect = context_clone.borrow().introspect();

                // Calculate volume
                let vol = Volume((Volume::NORMAL.0 as f64 * volume_level as f64 / 100.0) as u32);
                let mut cv = ChannelVolumes::default();
                cv.set_len(2);
                cv.set(2, vol);

                introspect.set_sink_volume_by_name(&name, &cv, None);
            }
            mainloop_clone
                .borrow_mut()
                .quit(libpulse_binding::def::Retval(0));
        });

        mainloop.borrow_mut().run().ok();
    }

    fn toggle_sink_mute() {
        use libpulse_binding::context::Context;
        use libpulse_binding::mainloop::standard::Mainloop;
        use libpulse_binding::proplist::Proplist;
        use std::cell::RefCell;
        use std::rc::Rc;

        let mut proplist = Proplist::new().unwrap();
        proplist
            .set_str(
                libpulse_binding::proplist::properties::APPLICATION_NAME,
                "skjold",
            )
            .ok();

        let mainloop = Rc::new(RefCell::new(Mainloop::new().unwrap()));
        let context = Rc::new(RefCell::new(
            Context::new_with_proplist(&*mainloop.borrow(), "skjold", &proplist).unwrap(),
        ));

        context
            .borrow_mut()
            .connect(None, libpulse_binding::context::FlagSet::NOFLAGS, None)
            .ok();

        loop {
            mainloop.borrow_mut().iterate(true);
            match context.borrow().get_state() {
                libpulse_binding::context::State::Ready => break,
                libpulse_binding::context::State::Failed
                | libpulse_binding::context::State::Terminated => return,
                _ => {}
            }
        }

        // Get current mute state and toggle
        let mainloop_clone = mainloop.clone();
        let context_clone = context.clone();

        let introspect = context.borrow().introspect();
        let _op = introspect.get_server_info(move |info| {
            if let Some(sink_name) = &info.default_sink_name {
                let name = sink_name.to_string();
                let name_inner = name.clone();
                let mainloop_inner = mainloop_clone.clone();
                let context_inner = context_clone.clone();

                let introspect = context_clone.borrow().introspect();
                let _op = introspect.get_sink_info_by_name(&name, move |list| {
                    if let libpulse_binding::callbacks::ListResult::Item(sink_info) = list {
                        let new_mute = !sink_info.mute;
                        let mut introspect = context_inner.borrow().introspect();
                        introspect.set_sink_mute_by_name(&name_inner, new_mute, None);
                        mainloop_inner
                            .borrow_mut()
                            .quit(libpulse_binding::def::Retval(0));
                    }
                });
            }
        });

        mainloop.borrow_mut().run().ok();
    }
}

impl Default for LiveAudioService {
    fn default() -> Self {
        Self::new()
    }
}

impl AudioService for LiveAudioService {
    fn get_state(&self) -> AudioState {
        self.state.lock().unwrap().clone()
    }

    fn set_volume(&self, volume: u32) {
        Self::set_sink_volume(volume);
        self.refresh();
    }

    fn toggle_mute(&self) {
        Self::toggle_sink_mute();
        self.refresh();
    }

    fn refresh(&self) {
        let state = Self::query_audio_state();
        *self.state.lock().unwrap() = state;
    }
}

// === Network Service (Wave 6) ===

/// Live implementation of NetworkService using NetworkManager D-Bus.
pub struct LiveNetworkService {
    state: Mutex<NetworkState>,
}

impl LiveNetworkService {
    pub fn new() -> Self {
        let state = Self::query_network_state();
        Self {
            state: Mutex::new(state),
        }
    }

    fn query_network_state() -> NetworkState {
        // Try to get NetworkManager state via D-Bus
        let connection = match zbus::blocking::Connection::system() {
            Ok(conn) => conn,
            Err(_) => return NetworkState::default(),
        };

        // Get NetworkManager proxy
        let nm_proxy = match connection.call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop/NetworkManager",
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager", "State"),
        ) {
            Ok(reply) => reply,
            Err(_) => return NetworkState::default(),
        };

        // Parse state (NM_STATE values: 0=unknown, 10=asleep, 20=disconnected,
        // 30=disconnecting, 40=connecting, 50=connected_local, 60=connected_site, 70=connected_global)
        let state_variant: zbus::zvariant::OwnedValue = match nm_proxy.body().deserialize() {
            Ok(v) => v,
            Err(_) => return NetworkState::default(),
        };

        let nm_state: u32 = match state_variant.downcast_ref::<u32>() {
            Ok(s) => s,
            Err(_) => return NetworkState::default(),
        };

        let connected = nm_state >= 60; // connected_site or connected_global

        // Get primary connection
        let conn_reply = match connection.call_method(
            Some("org.freedesktop.NetworkManager"),
            "/org/freedesktop/NetworkManager",
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager", "PrimaryConnection"),
        ) {
            Ok(reply) => reply,
            Err(_) => {
                return NetworkState {
                    connected,
                    network_type: if connected {
                        NetworkType::Wired
                    } else {
                        NetworkType::Disconnected
                    },
                    ..Default::default()
                };
            }
        };

        let conn_path_variant: zbus::zvariant::OwnedValue = match conn_reply.body().deserialize() {
            Ok(v) => v,
            Err(_) => {
                return NetworkState {
                    connected,
                    network_type: if connected {
                        NetworkType::Wired
                    } else {
                        NetworkType::Disconnected
                    },
                    ..Default::default()
                };
            }
        };

        let conn_path: &zbus::zvariant::ObjectPath = match conn_path_variant.downcast_ref() {
            Ok(p) => p,
            Err(_) => {
                return NetworkState {
                    connected,
                    network_type: if connected {
                        NetworkType::Wired
                    } else {
                        NetworkType::Disconnected
                    },
                    ..Default::default()
                };
            }
        };

        if conn_path.as_str() == "/" {
            return NetworkState {
                connected: false,
                network_type: NetworkType::Disconnected,
                ..Default::default()
            };
        }

        // Get connection type
        let type_reply = match connection.call_method(
            Some("org.freedesktop.NetworkManager"),
            conn_path.as_str(),
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager.Connection.Active", "Type"),
        ) {
            Ok(reply) => reply,
            Err(_) => {
                return NetworkState {
                    connected,
                    network_type: NetworkType::Wired,
                    ..Default::default()
                };
            }
        };

        let type_variant: zbus::zvariant::OwnedValue = match type_reply.body().deserialize() {
            Ok(v) => v,
            Err(_) => {
                return NetworkState {
                    connected,
                    network_type: NetworkType::Wired,
                    ..Default::default()
                };
            }
        };

        let conn_type: String = match type_variant.downcast_ref::<String>() {
            Ok(t) => t.clone(),
            Err(_) => "unknown".to_string(),
        };

        let network_type = match conn_type.as_str() {
            "802-11-wireless" => NetworkType::Wireless,
            "802-3-ethernet" => NetworkType::Wired,
            "vpn" | "wireguard" => NetworkType::Vpn,
            _ => NetworkType::Wired,
        };

        // Get connection ID (name)
        let id_reply = connection.call_method(
            Some("org.freedesktop.NetworkManager"),
            conn_path.as_str(),
            Some("org.freedesktop.DBus.Properties"),
            "Get",
            &("org.freedesktop.NetworkManager.Connection.Active", "Id"),
        );

        let connection_name = id_reply.ok().and_then(|reply| {
            let id_variant: zbus::zvariant::OwnedValue = reply.body().deserialize().ok()?;
            id_variant.downcast_ref::<String>().ok().map(|s| s.clone())
        });

        // TODO: Get signal strength for wireless connections
        let signal_strength = if network_type == NetworkType::Wireless {
            Some(75u8) // Placeholder - would need to query AccessPoint
        } else {
            None
        };

        NetworkState {
            network_type,
            connected,
            connection_name,
            signal_strength,
        }
    }
}

impl Default for LiveNetworkService {
    fn default() -> Self {
        Self::new()
    }
}

impl NetworkService for LiveNetworkService {
    fn get_state(&self) -> NetworkState {
        self.state.lock().unwrap().clone()
    }

    fn refresh(&self) {
        let state = Self::query_network_state();
        *self.state.lock().unwrap() = state;
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
    Arc<LiveLauncherService>,
    Arc<LiveWorkspaceService>,
    Arc<LiveAudioService>,
    Arc<LiveNetworkService>,
) {
    (
        Arc::new(LiveHyprlandIpc),
        Arc::new(LiveTimeService),
        Arc::new(LiveSystemInfoService::new()),
        Arc::new(LiveBatteryService),
        Arc::new(LiveBluetoothService::new()),
        Arc::new(LiveSessionService),
        Arc::new(LiveLauncherService::new()),
        Arc::new(LiveWorkspaceService::new()),
        Arc::new(LiveAudioService::new()),
        Arc::new(LiveNetworkService::new()),
    )
}
