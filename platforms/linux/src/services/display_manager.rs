//! Display manager for Wayland
//!
//! Handles multi-display management and cursor position tracking on Wayland.

use anyhow::Result;
use gtk4::gdk;
use gtk4::prelude::*;

/// Represents a display/monitor
#[derive(Debug, Clone)]
pub struct Display {
    pub name: String,
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
    pub scale_factor: i32,
    pub is_primary: bool,
}

impl Display {
    /// Get the center point of this display
    pub fn center(&self) -> (i32, i32) {
        (self.x + self.width / 2, self.y + self.height / 2)
    }

    /// Check if a point is within this display
    pub fn contains(&self, x: i32, y: i32) -> bool {
        x >= self.x && x < self.x + self.width && y >= self.y && y < self.y + self.height
    }
}

/// Manages displays and cursor position
pub struct DisplayManager {
    displays: Vec<Display>,
}

impl DisplayManager {
    /// Create a new display manager
    pub fn new() -> Self {
        let mut manager = Self {
            displays: Vec::new(),
        };
        manager.refresh_displays();
        manager
    }

    /// Refresh the list of displays
    pub fn refresh_displays(&mut self) {
        self.displays.clear();

        let display = match gdk::Display::default() {
            Some(d) => d,
            None => {
                tracing::warn!("No default display available");
                return;
            }
        };

        let monitors = display.monitors();
        let n_monitors = monitors.n_items();

        for i in 0..n_monitors {
            if let Some(monitor) = monitors.item(i).and_then(|obj| obj.downcast::<gdk::Monitor>().ok()) {
                let geometry = monitor.geometry();
                let connector = monitor.connector().map(|s| s.to_string()).unwrap_or_else(|| format!("Monitor-{}", i));

                self.displays.push(Display {
                    name: connector,
                    x: geometry.x(),
                    y: geometry.y(),
                    width: geometry.width(),
                    height: geometry.height(),
                    scale_factor: monitor.scale_factor(),
                    is_primary: i == 0, // First monitor is usually primary
                });
            }
        }

        tracing::info!("Found {} displays", self.displays.len());
        for display in &self.displays {
            tracing::debug!(
                "  {}: {}x{} at ({}, {}), scale {}",
                display.name,
                display.width,
                display.height,
                display.x,
                display.y,
                display.scale_factor
            );
        }
    }

    /// Get all displays
    pub fn displays(&self) -> &[Display] {
        &self.displays
    }

    /// Get the primary display
    pub fn primary_display(&self) -> Option<&Display> {
        self.displays.iter().find(|d| d.is_primary).or(self.displays.first())
    }

    /// Find which display contains a point
    pub fn display_at(&self, x: i32, y: i32) -> Option<&Display> {
        self.displays.iter().find(|d| d.contains(x, y))
    }

    /// Get the total bounding box of all displays
    pub fn total_bounds(&self) -> (i32, i32, i32, i32) {
        if self.displays.is_empty() {
            return (0, 0, 1920, 1080);
        }

        let min_x = self.displays.iter().map(|d| d.x).min().unwrap_or(0);
        let min_y = self.displays.iter().map(|d| d.y).min().unwrap_or(0);
        let max_x = self.displays.iter().map(|d| d.x + d.width).max().unwrap_or(1920);
        let max_y = self.displays.iter().map(|d| d.y + d.height).max().unwrap_or(1080);

        (min_x, min_y, max_x - min_x, max_y - min_y)
    }
}

impl Default for DisplayManager {
    fn default() -> Self {
        Self::new()
    }
}

/// Get the current cursor position
///
/// Note: On Wayland, getting the global cursor position is restricted.
/// This function returns the cursor position relative to the focused surface,
/// or None if not available.
pub fn get_cursor_position() -> Option<(f64, f64)> {
    let display = gdk::Display::default()?;
    let seat = display.default_seat()?;
    let pointer = seat.pointer()?;

    // On Wayland, we can only get position relative to a surface
    // This is a limitation of the Wayland security model
    // For global position, we need to track pointer motion events

    // Return None to indicate we need to use event-based tracking
    None
}

/// Move cursor to a position (Wayland limitation)
///
/// Note: Wayland does not allow cursor warping for security reasons.
/// This function returns an error explaining the limitation.
pub fn move_cursor_to(_x: f64, _y: f64) -> Result<()> {
    anyhow::bail!(
        "Cursor warping is not supported on Wayland for security reasons. \
         Some compositors (GNOME, KDE) may support it through extensions."
    )
}
