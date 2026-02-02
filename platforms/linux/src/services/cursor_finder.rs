//! Cursor finder service
//!
//! Handles cursor highlighting on Wayland.

use crate::models::Preferences;
use crate::services::DisplayManager;
use crate::ui::HighlightOverlay;
use anyhow::Result;
use std::cell::RefCell;
use std::rc::Rc;
use std::sync::Arc;

/// Service for finding and highlighting the cursor
pub struct CursorFinderService {
    preferences: Arc<Preferences>,
    display_manager: DisplayManager,
    overlay: Option<HighlightOverlay>,
    last_known_position: Option<(f64, f64)>,
}

impl CursorFinderService {
    /// Create a new cursor finder service
    pub fn new(preferences: Arc<Preferences>) -> Self {
        Self {
            preferences,
            display_manager: DisplayManager::new(),
            overlay: None,
            last_known_position: None,
        }
    }

    /// Find and highlight the cursor
    pub fn find_cursor(&mut self) {
        if !self.preferences.enabled {
            return;
        }

        // On Wayland, we can't get the global cursor position directly
        // We rely on pointer motion events to track position
        let position = self.last_known_position.unwrap_or_else(|| {
            // Fall back to center of primary display
            if let Some(display) = self.display_manager.primary_display() {
                let (cx, cy) = display.center();
                (cx as f64, cy as f64)
            } else {
                (960.0, 540.0)
            }
        });

        self.show_highlight_at(position.0, position.1);
    }

    /// Update the tracked cursor position
    pub fn update_cursor_position(&mut self, x: f64, y: f64) {
        self.last_known_position = Some((x, y));

        // If overlay is visible, update its position
        if let Some(overlay) = &mut self.overlay {
            overlay.update_position(x, y);
        }
    }

    /// Show highlight at a specific position
    pub fn show_highlight_at(&mut self, x: f64, y: f64) {
        tracing::debug!("Showing highlight at ({}, {})", x, y);

        // Create or update overlay
        if self.overlay.is_none() {
            match HighlightOverlay::new() {
                Ok(overlay) => {
                    self.overlay = Some(overlay);
                }
                Err(e) => {
                    tracing::error!("Failed to create highlight overlay: {}", e);
                    return;
                }
            }
        }

        if let Some(overlay) = &mut self.overlay {
            overlay.show(
                x,
                y,
                &self.preferences.cursor_style,
                &self.preferences.animation_style,
                self.preferences.highlight_duration,
            );
        }
    }

    /// Hide any active highlight
    pub fn hide_highlight(&mut self) {
        if let Some(overlay) = &mut self.overlay {
            overlay.hide();
        }
    }

    /// Center cursor on primary display (Wayland limitation)
    pub fn center_on_primary(&mut self) -> Result<()> {
        let display = self
            .display_manager
            .primary_display()
            .ok_or_else(|| anyhow::anyhow!("No primary display found"))?;

        let (cx, cy) = display.center();

        // On Wayland, we can't actually move the cursor
        // Instead, we just show the highlight at the center
        tracing::warn!(
            "Cursor warping is not supported on Wayland. Showing highlight at center instead."
        );

        self.show_highlight_at(cx as f64, cy as f64);
        Ok(())
    }

    /// Refresh display information
    pub fn refresh_displays(&mut self) {
        self.display_manager.refresh_displays();
    }
}
