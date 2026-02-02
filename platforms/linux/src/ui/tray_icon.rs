//! System tray icon
//!
//! Provides a system tray icon for CursorHome using KSNI (KDE StatusNotifierItem).

use crate::app::AppState;
use std::rc::Rc;

/// System tray icon for CursorHome
pub struct TrayIcon {
    #[allow(dead_code)]
    state: Rc<AppState>,
}

impl TrayIcon {
    /// Create a new tray icon
    pub fn new(state: Rc<AppState>) -> Self {
        Self { state }
    }

    /// Initialize the tray icon (non-async stub for now)
    pub fn init(&self) {
        tracing::info!("System tray icon initialized (stub)");
        // TODO: Implement actual KSNI tray icon
        // This requires running in a Tokio runtime context
        // For now, the app runs without a tray icon
    }
}
