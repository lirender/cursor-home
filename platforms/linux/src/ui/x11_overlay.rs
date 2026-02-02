//! X11 ARGB overlay for transparent cursor highlighting
//!
//! Creates a true transparent overlay window using X11's 32-bit ARGB visual.

use crate::models::{AnimationStyle, AnimationType, CursorStyle, Shape};
use anyhow::{Context, Result};
use std::time::{Duration, Instant};
use x11rb::connection::Connection;
use x11rb::protocol::render::{ConnectionExt as RenderConnectionExt, PictType};
use x11rb::protocol::shape::{ConnectionExt as ShapeConnectionExt, SK};
use x11rb::protocol::xproto::*;
use x11rb::rust_connection::RustConnection;
use x11rb::wrapper::ConnectionExt as _;

/// X11 ARGB overlay window for cursor highlighting
pub struct X11Overlay {
    conn: RustConnection,
    screen_num: usize,
    window: Window,
    width: u16,
    height: u16,
    visual_id: Visualid,
    depth: u8,
    is_visible: bool,
}

impl X11Overlay {
    /// Create a new X11 ARGB overlay
    pub fn new() -> Result<Self> {
        let (conn, screen_num) = x11rb::connect(None).context("Failed to connect to X11")?;

        let screen = &conn.setup().roots[screen_num];
        let width = screen.width_in_pixels;
        let height = screen.height_in_pixels;

        // Find 32-bit ARGB visual
        let (visual_id, depth) = find_argb_visual(&conn, screen_num)?;

        tracing::info!(
            "Found ARGB visual: id={}, depth={}, screen={}x{}",
            visual_id,
            depth,
            width,
            height
        );

        // Create colormap for the ARGB visual
        let colormap = conn.generate_id()?;
        conn.create_colormap(ColormapAlloc::NONE, colormap, screen.root, visual_id)?;

        // Create the overlay window
        let window = conn.generate_id()?;
        let win_aux = CreateWindowAux::new()
            .background_pixel(0) // Transparent
            .border_pixel(0)
            .override_redirect(1) // No window manager decoration
            .colormap(colormap)
            .event_mask(EventMask::EXPOSURE);

        conn.create_window(
            depth,
            window,
            screen.root,
            0,
            0,
            width,
            height,
            0,
            WindowClass::INPUT_OUTPUT,
            visual_id,
            &win_aux,
        )?;

        // Set window type hint to utility/overlay
        let wm_window_type = conn
            .intern_atom(false, b"_NET_WM_WINDOW_TYPE")?
            .reply()?
            .atom;
        let wm_window_type_dock = conn
            .intern_atom(false, b"_NET_WM_WINDOW_TYPE_DOCK")?
            .reply()?
            .atom;

        conn.change_property32(
            PropMode::REPLACE,
            window,
            wm_window_type,
            AtomEnum::ATOM,
            &[wm_window_type_dock],
        )?;

        // Make window click-through (input passthrough)
        set_click_through(&conn, window)?;

        conn.flush()?;

        Ok(Self {
            conn,
            screen_num,
            window,
            width,
            height,
            visual_id,
            depth,
            is_visible: false,
        })
    }

    /// Show the overlay and start the highlight animation
    pub fn show_highlight(
        &mut self,
        style: &CursorStyle,
        animation_style: &AnimationStyle,
        duration_secs: f64,
    ) -> Result<()> {
        // Map the window
        self.conn.map_window(self.window)?;
        self.conn.flush()?;
        self.is_visible = true;

        tracing::info!("X11 overlay mapped, starting animation");

        // Run animation loop
        let start = Instant::now();
        let duration = Duration::from_secs_f64(duration_secs);
        let frame_duration = Duration::from_millis(16); // ~60fps

        while start.elapsed() < duration {
            let frame_start = Instant::now();

            // Get current cursor position
            let (cursor_x, cursor_y) = self.get_cursor_position()?;

            // Calculate animation progress
            let elapsed = start.elapsed().as_secs_f64();
            let progress = self.calculate_animation_progress(elapsed, animation_style);

            // Draw the highlight
            self.draw_highlight(cursor_x, cursor_y, style, animation_style, progress)?;

            // Handle X11 events (exposure, etc.)
            while let Some(event) = self.conn.poll_for_event()? {
                if let x11rb::protocol::Event::Expose(_) = event {
                    // Redraw on expose
                    self.draw_highlight(cursor_x, cursor_y, style, animation_style, progress)?;
                }
            }

            // Frame timing
            let frame_elapsed = frame_start.elapsed();
            if frame_elapsed < frame_duration {
                std::thread::sleep(frame_duration - frame_elapsed);
            }
        }

        // Hide the overlay
        self.hide()?;

        Ok(())
    }

    /// Hide the overlay
    pub fn hide(&mut self) -> Result<()> {
        if self.is_visible {
            self.conn.unmap_window(self.window)?;
            self.conn.flush()?;
            self.is_visible = false;
            tracing::info!("X11 overlay hidden");
        }
        Ok(())
    }

    /// Get current cursor position
    fn get_cursor_position(&self) -> Result<(i16, i16)> {
        let screen = &self.conn.setup().roots[self.screen_num];
        let reply = self
            .conn
            .query_pointer(screen.root)?
            .reply()
            .context("Failed to query pointer")?;
        Ok((reply.root_x, reply.root_y))
    }

    /// Calculate animation progress based on style
    fn calculate_animation_progress(&self, elapsed: f64, style: &AnimationStyle) -> f64 {
        if style.duration <= 0.0 {
            return 1.0;
        }

        let raw_progress = (elapsed % style.duration) / style.duration;

        let progress = if style.auto_reverse {
            let cycle = (elapsed / style.duration) as u32;
            if cycle % 2 == 1 {
                1.0 - raw_progress
            } else {
                raw_progress
            }
        } else {
            raw_progress
        };

        style.easing.apply(progress)
    }

    /// Draw the highlight at cursor position using XRender
    fn draw_highlight(
        &self,
        cursor_x: i16,
        cursor_y: i16,
        style: &CursorStyle,
        animation_style: &AnimationStyle,
        progress: f64,
    ) -> Result<()> {
        // Create a GC for drawing
        let gc = self.conn.generate_id()?;
        self.conn.create_gc(
            gc,
            self.window,
            &CreateGCAux::new().foreground(0).background(0),
        )?;

        // Clear to transparent
        self.conn.poly_fill_rectangle(
            self.window,
            gc,
            &[Rectangle {
                x: 0,
                y: 0,
                width: self.width,
                height: self.height,
            }],
        )?;

        // Calculate alpha and scale based on animation
        let (alpha, scale) = match animation_style.animation_type {
            AnimationType::None => (style.color.a as f64, 1.0),
            AnimationType::Pulse => {
                let alpha = 0.3 + 0.7 * (1.0 - progress);
                (alpha * style.color.a as f64, 1.0)
            }
            AnimationType::Fade => {
                let alpha = 1.0 - progress * 0.7;
                (alpha * style.color.a as f64, 1.0)
            }
            AnimationType::Scale => {
                let scale = 0.8 + 0.4 * (1.0 - progress);
                (style.color.a as f64, scale)
            }
            AnimationType::Ripple => {
                let alpha = 1.0 - progress;
                let scale = 1.0 + progress * 0.5;
                (alpha * style.color.a as f64, scale)
            }
        };

        let size = (style.size * scale) as i16;
        let half_size = size / 2;

        // Convert color to X11 format (ARGB)
        let a = (alpha * 255.0).clamp(0.0, 255.0) as u32;
        let r = style.color.r as u32;
        let g = style.color.g as u32;
        let b = style.color.b as u32;
        let color = (a << 24) | (r << 16) | (g << 8) | b;

        // Update GC with the color
        self.conn
            .change_gc(gc, &ChangeGCAux::new().foreground(color))?;

        // Draw based on shape
        match style.shape {
            Shape::Circle | Shape::Spotlight => {
                // Draw filled circle using arcs
                self.conn.poly_fill_arc(
                    self.window,
                    gc,
                    &[Arc {
                        x: cursor_x - half_size,
                        y: cursor_y - half_size,
                        width: size as u16,
                        height: size as u16,
                        angle1: 0,
                        angle2: 360 * 64, // Full circle (in 1/64 degrees)
                    }],
                )?;
            }
            Shape::Ring => {
                // Draw ring (arc outline)
                let line_width = style.border_weight as u16;
                self.conn
                    .change_gc(gc, &ChangeGCAux::new().line_width(line_width as u32))?;
                self.conn.poly_arc(
                    self.window,
                    gc,
                    &[Arc {
                        x: cursor_x - half_size,
                        y: cursor_y - half_size,
                        width: size as u16,
                        height: size as u16,
                        angle1: 0,
                        angle2: 360 * 64,
                    }],
                )?;
            }
            Shape::Crosshair => {
                // Draw crosshair lines
                let line_width = style.border_weight as u16;
                self.conn
                    .change_gc(gc, &ChangeGCAux::new().line_width(line_width as u32))?;
                self.conn.poly_segment(
                    self.window,
                    gc,
                    &[
                        // Horizontal line
                        Segment {
                            x1: cursor_x - half_size,
                            y1: cursor_y,
                            x2: cursor_x + half_size,
                            y2: cursor_y,
                        },
                        // Vertical line
                        Segment {
                            x1: cursor_x,
                            y1: cursor_y - half_size,
                            x2: cursor_x,
                            y2: cursor_y + half_size,
                        },
                    ],
                )?;
            }
        }

        // Free the GC
        self.conn.free_gc(gc)?;
        self.conn.flush()?;

        Ok(())
    }
}

impl Drop for X11Overlay {
    fn drop(&mut self) {
        let _ = self.conn.destroy_window(self.window);
        let _ = self.conn.flush();
    }
}

/// Find a 32-bit ARGB visual
fn find_argb_visual(conn: &RustConnection, screen_num: usize) -> Result<(Visualid, u8)> {
    let screen = &conn.setup().roots[screen_num];

    // Query render extension for picture formats
    let formats = conn.render_query_pict_formats()?.reply()?;

    // Find a 32-bit format with alpha
    for format in &formats.formats {
        if format.depth == 32 && format.type_ == PictType::DIRECT {
            let direct = &format.direct;
            // Check if this format has alpha
            if direct.alpha_mask > 0 {
                // Find a visual that uses this format
                for screen_info in &formats.screens {
                    for depth_info in &screen_info.depths {
                        if depth_info.depth == 32 {
                            for visual in &depth_info.visuals {
                                if visual.format == format.id {
                                    return Ok((visual.visual, 32));
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Fallback: search through screen's depths
    for depth_info in &screen.allowed_depths {
        if depth_info.depth == 32 {
            if let Some(visual) = depth_info.visuals.first() {
                return Ok((visual.visual_id, 32));
            }
        }
    }

    anyhow::bail!("No 32-bit ARGB visual found")
}

/// Make window click-through using shape extension
fn set_click_through(conn: &RustConnection, window: Window) -> Result<()> {
    use x11rb::protocol::shape::SO;

    // Check if shape extension is available
    if conn.shape_query_version().is_ok() {
        // Set input shape to empty rectangle (no input region)
        conn.shape_rectangles(
            SO::SET,
            SK::INPUT,
            ClipOrdering::UNSORTED,
            window,
            0,
            0,
            &[], // Empty - no input region
        )?;
    }

    Ok(())
}
