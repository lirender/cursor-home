//! Cursor finder service
//!
//! Handles cursor highlighting using X11 ARGB overlay.

use crate::models::{AnimationStyle, CursorStyle, Preferences};
use crate::services::DisplayManager;
use crate::ui::X11Overlay;
use anyhow::Result;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::Arc;
use std::thread;

/// Service for finding and highlighting the cursor
pub struct CursorFinderService {
    preferences: Arc<Preferences>,
    display_manager: DisplayManager,
    is_highlighting: Arc<AtomicBool>,
}

impl CursorFinderService {
    /// Create a new cursor finder service
    pub fn new(preferences: Arc<Preferences>) -> Self {
        Self {
            preferences,
            display_manager: DisplayManager::new(),
            is_highlighting: Arc::new(AtomicBool::new(false)),
        }
    }

    /// Find and highlight the cursor
    pub fn find_cursor(&mut self) {
        if !self.preferences.enabled {
            return;
        }

        // Don't start a new highlight if one is already running
        if self.is_highlighting.load(Ordering::SeqCst) {
            tracing::debug!("Highlight already in progress, skipping");
            return;
        }

        // Clone values for the thread
        let is_highlighting = self.is_highlighting.clone();
        let cursor_style = self.preferences.cursor_style.clone();
        let animation_style = self.preferences.animation_style.clone();
        let duration = self.preferences.highlight_duration;

        // Run the highlight in a separate thread (X11 overlay has blocking animation)
        thread::spawn(move || {
            is_highlighting.store(true, Ordering::SeqCst);

            match X11Overlay::new() {
                Ok(mut overlay) => {
                    tracing::info!("X11 overlay created, starting highlight");
                    if let Err(e) = overlay.show_highlight(&cursor_style, &animation_style, duration)
                    {
                        tracing::error!("Error during highlight: {}", e);
                    }
                }
                Err(e) => {
                    tracing::error!("Failed to create X11 overlay: {}", e);
                }
            }

            is_highlighting.store(false, Ordering::SeqCst);
            tracing::info!("Highlight complete");
        });
    }

    /// Refresh display information
    pub fn refresh_displays(&mut self) {
        self.display_manager.refresh_displays();
    }
}
