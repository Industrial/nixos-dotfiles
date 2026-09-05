//! UI widgets for system status display.

mod battery;
mod bluetooth;
mod cpu;
mod launcher;
mod session;
mod thermal;
mod workspaces;

pub use battery::battery_widget;
pub use bluetooth::bluetooth_widget;
pub use cpu::cpu_widget;
pub use launcher::launcher_widget;
pub use session::session_widget;
pub use thermal::thermal_widget;
pub use workspaces::workspaces_widget;
