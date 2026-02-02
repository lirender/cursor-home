//! Application lifecycle and GTK setup

use crate::models::Preferences;
use crate::services::{CursorFinderService, ShakeDetector, SynergyMonitor};
use crate::ui::{HighlightOverlay, SettingsWindow, TrayIcon};
use anyhow::Result;
use gtk4::prelude::*;
use gtk4::{gio, glib, Application};
use libadwaita as adw;
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;
use tokio::sync::mpsc;

const APP_ID: &str = "com.cursorhome.linux";

/// Main application state
pub struct AppState {
    pub preferences: Arc<Preferences>,
    pub cursor_finder: Rc<RefCell<CursorFinderService>>,
    pub synergy_monitor: Rc<RefCell<SynergyMonitor>>,
    pub shake_detector: Rc<RefCell<ShakeDetector>>,
    pub highlight_overlay: Rc<RefCell<Option<HighlightOverlay>>>,
}

impl AppState {
    pub fn new() -> Self {
        let preferences = Arc::new(Preferences::load());

        Self {
            preferences: preferences.clone(),
            cursor_finder: Rc::new(RefCell::new(CursorFinderService::new(preferences.clone()))),
            synergy_monitor: Rc::new(RefCell::new(SynergyMonitor::new())),
            shake_detector: Rc::new(RefCell::new(ShakeDetector::new(
                preferences.shake_sensitivity,
            ))),
            highlight_overlay: Rc::new(RefCell::new(None)),
        }
    }
}

/// Run the GTK application
pub fn run() -> Result<()> {
    // Initialize GTK
    gtk4::init()?;

    // Initialize libadwaita
    adw::init()?;

    // Create application as a service (stays running without windows)
    let app = Application::builder()
        .application_id(APP_ID)
        .flags(gio::ApplicationFlags::IS_SERVICE)
        .build();

    // Connect startup signal
    app.connect_startup(|app| {
        tracing::info!("Application startup");
        setup_app(app);
    });

    // Hold the application to prevent exit (for background/tray apps)
    let _hold_guard = app.hold();

    // Connect activate signal
    app.connect_activate(|_app| {
        tracing::info!("Application activated");
    });

    // Run the application
    let exit_code = app.run();

    if exit_code != glib::ExitCode::SUCCESS {
        anyhow::bail!("Application exited with error code");
    }

    Ok(())
}

fn setup_app(app: &Application) {
    let state = Rc::new(AppState::new());

    // Setup system tray icon
    setup_tray_icon(app, state.clone());

    // Setup Synergy monitoring
    setup_synergy_monitoring(state.clone());

    // Setup shake detection
    setup_shake_detection(state.clone());

    // Setup keyboard shortcuts
    setup_shortcuts(app, state.clone());

    tracing::info!("CursorHome initialized successfully");
}

fn setup_tray_icon(_app: &Application, state: Rc<AppState>) {
    let tray = TrayIcon::new(state.clone());
    tray.init();
}

fn setup_synergy_monitoring(state: Rc<AppState>) {
    let state_clone = state.clone();

    // Start monitoring Synergy with callback
    let mut monitor = state.synergy_monitor.borrow_mut();
    let result = monitor.start_with_callback(move |screen_name| {
        tracing::info!("Cursor returned from {} - triggering highlight", screen_name);
        if state_clone.preferences.enabled {
            state_clone.cursor_finder.borrow_mut().find_cursor();
        }
    });

    if let Err(e) = result {
        tracing::warn!("Failed to start Synergy monitoring: {}", e);
    }
}

fn setup_shake_detection(state: Rc<AppState>) {
    let state_clone = state.clone();

    let mut detector = state.shake_detector.borrow_mut();
    detector.set_on_shake(Box::new(move || {
        tracing::debug!("Shake detected");

        let state = state_clone.clone();
        glib::idle_add_local_once(move || {
            if state.preferences.enabled && state.preferences.shake_enabled {
                state.cursor_finder.borrow_mut().find_cursor();
            }
        });
    }));

    if let Err(e) = detector.start() {
        tracing::warn!("Failed to start shake detection: {}", e);
    }
}

fn setup_shortcuts(app: &Application, state: Rc<AppState>) {
    // Add application actions for keyboard shortcuts
    let find_action = gio::SimpleAction::new("find-cursor", None);
    let state_clone = state.clone();
    find_action.connect_activate(move |_, _| {
        tracing::debug!("Find cursor action triggered");
        state_clone.cursor_finder.borrow_mut().find_cursor();
    });
    app.add_action(&find_action);

    let settings_action = gio::SimpleAction::new("show-settings", None);
    let state_clone = state.clone();
    settings_action.connect_activate(move |_, _| {
        tracing::debug!("Show settings action triggered");
        SettingsWindow::show(state_clone.preferences.clone());
    });
    app.add_action(&settings_action);

    let quit_action = gio::SimpleAction::new("quit", None);
    let app_clone = app.clone();
    quit_action.connect_activate(move |_, _| {
        tracing::info!("Quit action triggered");
        app_clone.quit();
    });
    app.add_action(&quit_action);

    // Set accelerators
    app.set_accels_for_action("app.find-cursor", &["<Primary><Shift>f"]);
    app.set_accels_for_action("app.show-settings", &["<Primary>comma"]);
    app.set_accels_for_action("app.quit", &["<Primary>q"]);
}
