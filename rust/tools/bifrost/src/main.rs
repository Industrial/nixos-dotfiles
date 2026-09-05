//! Bifröst — NixOS fleet command center.
//!
//! A Lattice-inspired UI for managing NixOS machines over Tailscale.

use std::sync::Arc;

use iced::{Element, Subscription, Task, Theme};

use bifrost::providers::{
    LiveFleetDiscovery, LiveNixOpsService, LivePrometheusService, LiveSshService,
};
use bifrost::ui::{BifrostApp, Message};

fn main() -> iced::Result {
    iced::application(
        BifrostWrapper::new,
        BifrostWrapper::update,
        BifrostWrapper::view,
    )
    .title("Bifröst")
    .subscription(BifrostWrapper::subscription)
    .theme(BifrostWrapper::theme)
    .run()
}

/// Wrapper to handle initialization with providers.
struct BifrostWrapper {
    app: BifrostApp,
}

impl BifrostWrapper {
    fn new() -> (Self, Task<Message>) {
        // Initialize providers
        let fleet = Arc::new(LiveFleetDiscovery::new());
        let prometheus = Arc::new(LivePrometheusService::new("http://mimir:9001".to_string()));
        let ssh = Arc::new(LiveSshService::new());
        let nixops = Arc::new(LiveNixOpsService::new(ssh.clone()));

        let (app, task) = BifrostApp::new(fleet, prometheus, ssh, nixops);
        (Self { app }, task)
    }

    fn update(&mut self, message: Message) -> Task<Message> {
        self.app.update(message)
    }

    fn view(&self) -> Element<'_, Message> {
        self.app.view()
    }

    fn subscription(&self) -> Subscription<Message> {
        self.app.subscription()
    }

    fn theme(&self) -> Theme {
        Theme::Dark
    }
}
