//! Live implementations of capabilities.
//!
//! For MVP, we use direct hyprland-rs calls rather than id_effect wrappers
//! to simplify Iced integration. Full id_effect integration comes in Wave 2.

use std::sync::Arc;

use chrono::Local;
use hyprland::data::{Workspace as HyprWorkspace, Workspaces};
use hyprland::dispatch::{Dispatch, DispatchType, WorkspaceIdentifierWithSpecial};
use hyprland::shared::{HyprData, HyprDataActive};

use crate::capabilities::TimeService;
use crate::domain::Workspace;

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

/// Create the live provider set.
pub fn live_providers() -> (Arc<LiveHyprlandIpc>, Arc<LiveTimeService>) {
    (Arc::new(LiveHyprlandIpc), Arc::new(LiveTimeService))
}
