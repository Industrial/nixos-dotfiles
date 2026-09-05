//! UI widgets for system status display.

mod battery;
mod cpu;
mod thermal;

pub use battery::battery_widget;
pub use cpu::cpu_widget;
pub use thermal::thermal_widget;
