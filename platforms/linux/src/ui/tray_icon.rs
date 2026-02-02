//! System tray icon
//!
//! Provides a system tray icon for CursorHome using KSNI (KDE StatusNotifierItem).

use crate::app::AppState;
use std::rc::Rc;

/// System tray icon for CursorHome
pub struct TrayIcon {
    state: Rc<AppState>,
}

impl TrayIcon {
    /// Create a new tray icon
    pub fn new(state: Rc<AppState>) -> Self {
        Self { state }
    }

    /// Run the tray icon service
    pub async fn run(&self) {
        // Note: KSNI requires a running tokio runtime
        // In a full implementation, this would create the actual tray icon

        tracing::info!("System tray icon initialized");

        // For now, we'll use a placeholder implementation
        // A full implementation would use the ksni crate to create a StatusNotifierItem

        // Example of what the full implementation would look like:
        /*
        let service = ksni::TrayService::new(CursorHomeTray {
            state: self.state.clone(),
        });

        service.spawn().await.expect("Failed to spawn tray service");
        */

        // Keep the task alive
        loop {
            tokio::time::sleep(std::time::Duration::from_secs(3600)).await;
        }
    }
}

// Example KSNI tray implementation (would be used in full implementation)
/*
struct CursorHomeTray {
    state: Rc<AppState>,
}

impl ksni::Tray for CursorHomeTray {
    fn icon_name(&self) -> String {
        "find-location".into()
    }

    fn title(&self) -> String {
        "CursorHome".into()
    }

    fn menu(&self) -> Vec<ksni::MenuItem<Self>> {
        use ksni::menu::*;

        vec![
            StandardItem {
                label: "Find Cursor".into(),
                activate: Box::new(|this: &mut Self| {
                    this.state.cursor_finder.borrow_mut().find_cursor();
                }),
                ..Default::default()
            }
            .into(),
            MenuItem::Separator,
            CheckmarkItem {
                label: "Enabled".into(),
                checked: self.state.preferences.enabled,
                activate: Box::new(|this: &mut Self| {
                    // Toggle enabled state
                }),
                ..Default::default()
            }
            .into(),
            MenuItem::Separator,
            StandardItem {
                label: "Settings...".into(),
                activate: Box::new(|this: &mut Self| {
                    SettingsWindow::show(this.state.preferences.clone());
                }),
                ..Default::default()
            }
            .into(),
            MenuItem::Separator,
            StandardItem {
                label: "Quit".into(),
                activate: Box::new(|_| {
                    std::process::exit(0);
                }),
                ..Default::default()
            }
            .into(),
        ]
    }
}
*/
