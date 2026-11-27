//! The GTK edge: the only Rust in vwebbrowser that names a widget.
//!
//! The seam (`.maestro/specs/vwebbrowser.md`): id_effect owns the program;
//! GTK owns one thread. The root fiber (`app::program`) runs on
//! `id_effect_tokio`; the main thread runs `gtk::Application::run` and
//! nothing else.
//!
//! - Effects -> GTK: [`GtkUi`] is the live `UiPort`. `send(cmd)` is an
//!   effect that hands the plain-data command to the main context with
//!   `MainContext::invoke`; [`apply`] runs it on the GTK thread against the
//!   thread-local [`Registry`], where the widgets live keyed by `TabId`.
//! - GTK -> effects: signal handlers offer a `UiEvent` to the `UiEvents`
//!   queue with `try_offer`, a synchronous node that `Runtime::try_block_on`
//!   settles inline (the GTK thread is outside any tokio context, so the
//!   call is allowed, and it never parks).
//!
//! No widget ever crosses: the `.vlt` modules see `Ui`, `UiEvents`, `TabId`,
//! `UiCmd` and `UiEvent` only.

use std::cell::RefCell;
use std::collections::HashMap;
use std::path::PathBuf;
use std::process::ExitCode;
use std::sync::Arc;

use gtk::gio::ApplicationHoldGuard;
use gtk::glib;
use gtk4 as gtk;
use id_effect::{Effect, Exit, sync};
use id_effect_process::{NodeName, ProcessNode};
use id_effect_tokio::TokioRuntime;
use webkit6::prelude::*;
use webkit6::{NetworkSession, WebView};

use crate::app;
use crate::error::UiError;
use crate::ui::{self, TabId, Ui, UiCmd, UiEvent, UiEvents, UiPort};

/// The application id (GApplication, the desktop entry, the Wayland app id).
pub const APP_ID: &str = "org.industrial.vwebbrowser";

/// The live window as a `UiPort`: every command goes to the GTK thread.
#[derive(Debug, Clone, Copy, Default)]
pub struct GtkUi;

impl UiPort for GtkUi {
    fn send(&self, cmd: UiCmd) -> Effect<(), UiError> {
        sync(move || glib::MainContext::default().invoke(move || apply(cmd)))
    }
}

/// How signal handlers reach the effect world: the queue, and a runtime to
/// settle the (synchronous) offer with.
#[derive(Clone)]
struct Outbox {
    events: UiEvents,
    runtime: TokioRuntime,
}

impl Outbox {
    fn emit(&self, event: UiEvent) {
        match self
            .runtime
            .runtime()
            .try_block_on(ui::offer(&self.events, event))
        {
            Ok(Exit::Success(_)) => {}
            Ok(Exit::Failure(cause)) => {
                eprintln!("vwebbrowser: dropping a window event: {cause:?}")
            }
            Err(e) => eprintln!("vwebbrowser: dropping a window event: {e}"),
        }
    }
}

/// The GTK thread's state. Only [`apply`] and the `activate` handler touch
/// it, both on the main thread.
struct Registry {
    app: gtk::Application,
    outbox: Outbox,
    window: Option<gtk::ApplicationWindow>,
    session: Option<NetworkSession>,
    tabs: HashMap<TabId, WebView>,
    /// Commands that arrived before the window existed, replayed on activate
    /// (the view settings, the first tab, its selection, the first tree).
    pending: Vec<UiCmd>,
    /// Keeps the application running after its window closes, until the
    /// root has finished and sent `Quit`.
    hold: Option<ApplicationHoldGuard>,
}

thread_local! {
    static REGISTRY: RefCell<Option<Registry>> = const { RefCell::new(None) };
}

fn with_registry(f: impl FnOnce(&mut Registry)) {
    REGISTRY.with(|cell| match cell.borrow_mut().as_mut() {
        Some(reg) => f(reg),
        None => eprintln!("vwebbrowser: a window command arrived with no window registry"),
    });
}

/// One command, on the GTK thread. Commands that arrive before the window
/// exists (the root starts before `activate`) wait in `pending`.
fn apply(cmd: UiCmd) {
    with_registry(|reg| match cmd {
        UiCmd::Quit => {
            reg.hold = None;
            reg.app.quit();
        }
        cmd if reg.window.is_none() => reg.pending.push(cmd),
        UiCmd::OpenTab { id, url } => open_url(reg, id, &url),
        UiCmd::Navigate(tab, url) => {
            if let Some(view) = reg.tabs.get(&tab) {
                view.load_uri(&url);
            }
        }
        UiCmd::Select(tab) => show(reg, tab),
        UiCmd::CloseTab(tab) => {
            if let Some(view) = reg.tabs.remove(&tab)
                && let Some(window) = &reg.window
                && window.child().as_ref() == Some(view.upcast_ref())
            {
                window.set_child(None::<&gtk::Widget>);
            }
        }
        // gtk-shell leaf: the related view stashed for ChildRequested.
        UiCmd::AdoptChild { .. } => {}
        // gtk-shell leaf: the web view's own navigation.
        UiCmd::Reload(_) | UiCmd::Stop(_) | UiCmd::GoBack(_) | UiCmd::GoForward(_) => {}
        // gtk-shell leaf: the sidebar, the address bar and the load bar.
        UiCmd::RenderTree(_)
        | UiCmd::SetAddress(..)
        | UiCmd::SetProgress(..)
        | UiCmd::FocusAddress => {}
        // gtk-shell leaf: WebKit settings per view.
        UiCmd::Configure(_) => {}
    });
}

/// One window, one visible WebView: the selected tab's.
fn show(reg: &mut Registry, tab: TabId) {
    if let (Some(window), Some(view)) = (&reg.window, reg.tabs.get(&tab))
        && window.child().as_ref() != Some(view.upcast_ref())
    {
        window.set_child(Some(view));
    }
}

fn open_url(reg: &mut Registry, tab: TabId, url: &str) {
    let view = match reg.tabs.get(&tab) {
        Some(view) => view.clone(),
        None => {
            let view = new_view(reg, tab);
            reg.tabs.insert(tab, view.clone());
            view
        }
    };
    // One window, one WebView for now: the newest tab is shown until the
    // program selects another.
    show(reg, tab);
    view.load_uri(url);
}

fn new_view(reg: &mut Registry, tab: TabId) -> WebView {
    let session = reg.session.get_or_insert_with(persistent_session).clone();
    let view = WebView::builder().network_session(&session).build();
    let window = reg.window.clone();
    let outbox = reg.outbox.clone();
    view.connect_title_notify(move |view| {
        let title = view.title().map(|t| t.to_string()).unwrap_or_default();
        if let Some(window) = &window {
            window.set_title(Some(if title.is_empty() {
                "vwebbrowser"
            } else {
                &title
            }));
        }
        outbox.emit(UiEvent::TitleChanged(tab, title));
    });
    let outbox = reg.outbox.clone();
    view.connect_uri_notify(move |view| {
        let uri = view.uri().map(|u| u.to_string()).unwrap_or_default();
        outbox.emit(UiEvent::UriChanged(tab, uri));
    });
    view
}

fn app_dir(base: PathBuf) -> String {
    base.join("vwebbrowser").to_string_lossy().into_owned()
}

/// Cookies, local storage and the HTTP cache under the XDG data and cache
/// directories, so they persist between runs.
fn persistent_session() -> NetworkSession {
    let data = app_dir(glib::user_data_dir());
    let cache = app_dir(glib::user_cache_dir());
    NetworkSession::new(Some(&data), Some(&cache))
}

fn activate(app: &gtk::Application) {
    let window = gtk::ApplicationWindow::builder()
        .application(app)
        .title("vwebbrowser")
        .default_width(1280)
        .default_height(800)
        .build();
    let pending = REGISTRY.with(|cell| {
        let mut guard = cell.borrow_mut();
        let Some(reg) = guard.as_mut() else {
            return Vec::new();
        };
        let outbox = reg.outbox.clone();
        window.connect_close_request(move |_| {
            outbox.emit(UiEvent::WindowClosed);
            glib::Propagation::Proceed
        });
        reg.window = Some(window.clone());
        std::mem::take(&mut reg.pending)
    });
    for cmd in pending {
        apply(cmd);
    }
    window.present();
}

/// The program: the root on tokio, GTK on this (the main) thread, and the
/// root's exit as the process's (id_effect_cli's contract: 0 / 1 / 101 / 130).
pub fn run(address: Option<String>) -> ExitCode {
    let runtime = match TokioRuntime::new_multi_thread() {
        Ok(rt) => rt,
        Err(e) => {
            eprintln!("vwebbrowser: cannot start the effect runtime: {e}");
            return ExitCode::from(1);
        }
    };
    let events = ui::new_events();
    let live = Ui(Arc::new(GtkUi));

    let app = gtk::Application::builder()
        .application_id(APP_ID)
        .flags(gtk::gio::ApplicationFlags::NON_UNIQUE)
        .build();
    app.connect_activate(activate);
    let hold = app.hold();
    REGISTRY.with(|cell| {
        *cell.borrow_mut() = Some(Registry {
            app: app.clone(),
            outbox: Outbox {
                events: events.clone(),
                runtime: runtime.clone(),
            },
            window: None,
            session: None,
            tabs: HashMap::new(),
            pending: Vec::new(),
            hold: Some(hold),
        })
    });

    // A daemon root fiber on the tokio executor (so it runs inside tokio's
    // context), with its handle kept: if GTK stops on its own, the root is
    // interrupted and its finalizers run.
    // Tab machines run as processes on the same tokio executor.
    let node = ProcessNode::on_runtime(NodeName::new("vwebbrowser"), runtime.runtime().clone());
    let root = app::program(address).provide_layer(app::live_layer(live, events, node));
    let fiber = runtime.fork(root);

    // GApplication must not see the URL: it would treat it as a file to open.
    app.run_with_args::<&str>(&[]);

    if !fiber.is_done() {
        fiber.interrupt_now();
    }
    let exit = runtime.block_on(fiber.join_future());
    REGISTRY.with(|cell| cell.borrow_mut().take());
    if let Exit::Failure(cause) = &exit {
        eprintln!("vwebbrowser: {cause:?}");
    }
    id_effect_cli::exit_code_for_exit(exit)
}
