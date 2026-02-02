//! Highlight overlay window using X11 cursor tracking
//!
//! Creates a transparent fullscreen overlay that tracks pointer position
//! and draws the cursor highlight.

use crate::models::{AnimationStyle, AnimationType, CursorStyle, Shape};
use anyhow::Result;
use gtk4::cairo::{self, Context};
use gtk4::gdk;
use gtk4::glib::{self, ControlFlow};
use gtk4::prelude::*;
use gtk4::DrawingArea;
use std::cell::{Cell, RefCell};
use std::f64::consts::PI;
use std::rc::Rc;
use std::time::{Duration, Instant};

/// Overlay window for displaying cursor highlight
pub struct HighlightOverlay {
    window: gtk4::Window,
    drawing_area: DrawingArea,
    cursor_position: Rc<Cell<(f64, f64)>>,
    style: Rc<RefCell<CursorStyle>>,
    animation: Rc<RefCell<AnimationState>>,
    is_visible: Rc<Cell<bool>>,
}

struct AnimationState {
    style: AnimationStyle,
    start_time: Option<Instant>,
    progress: f64,
    is_reversing: bool,
}

impl Default for AnimationState {
    fn default() -> Self {
        Self {
            style: AnimationStyle::default(),
            start_time: None,
            progress: 0.0,
            is_reversing: false,
        }
    }
}

/// Query the current cursor position using X11
fn get_x11_cursor_position() -> Option<(f64, f64)> {
    use x11rb::connection::Connection;
    use x11rb::protocol::xproto::*;

    // Connect to X11
    let (conn, screen_num) = match x11rb::connect(None) {
        Ok(c) => c,
        Err(e) => {
            tracing::debug!("Failed to connect to X11: {}", e);
            return None;
        }
    };

    let screen = &conn.setup().roots[screen_num];
    let root = screen.root;

    // Query pointer position - get the reply immediately to avoid lifetime issues
    let result = query_pointer(&conn, root)
        .ok()
        .and_then(|cookie| cookie.reply().ok())
        .map(|reply| (reply.root_x as f64, reply.root_y as f64));

    result
}

impl HighlightOverlay {
    /// Create a new highlight overlay
    pub fn new() -> Result<Self> {
        // Create a fullscreen transparent window
        let window = gtk4::Window::builder()
            .title("CursorHome Highlight")
            .decorated(false)
            .resizable(false)
            .build();

        // Try to make it fullscreen and transparent
        window.set_opacity(0.0); // Start invisible

        // Get screen dimensions
        let (screen_width, screen_height) = if let Some(display) = gdk::Display::default() {
            if let Some(monitor) = display
                .monitors()
                .item(0)
                .and_then(|m| m.downcast::<gdk::Monitor>().ok())
            {
                let geom = monitor.geometry();
                (geom.width(), geom.height())
            } else {
                (2160, 3840)
            }
        } else {
            (2160, 3840)
        };

        window.set_default_size(screen_width, screen_height);

        // Create drawing area that fills the window
        let drawing_area = DrawingArea::new();
        drawing_area.set_hexpand(true);
        drawing_area.set_vexpand(true);

        window.set_child(Some(&drawing_area));

        // Shared state
        let cursor_position = Rc::new(Cell::new((screen_width as f64 / 2.0, screen_height as f64 / 2.0)));
        let style = Rc::new(RefCell::new(CursorStyle::default()));
        let animation = Rc::new(RefCell::new(AnimationState::default()));
        let is_visible = Rc::new(Cell::new(false));

        // Set up drawing
        let style_clone = style.clone();
        let animation_clone = animation.clone();
        let cursor_pos_draw = cursor_position.clone();
        let is_visible_draw = is_visible.clone();

        drawing_area.set_draw_func(move |_area, cr, _width, _height| {
            // Clear to transparent
            cr.set_operator(cairo::Operator::Clear);
            cr.paint().ok();
            cr.set_operator(cairo::Operator::Over);

            if !is_visible_draw.get() {
                return;
            }

            let (cursor_x, cursor_y) = cursor_pos_draw.get();
            Self::draw_highlight(
                cr,
                cursor_x,
                cursor_y,
                &style_clone.borrow(),
                &animation_clone.borrow(),
            );
        });

        Ok(Self {
            window,
            drawing_area,
            cursor_position,
            style,
            animation,
            is_visible,
        })
    }

    /// Show the highlight
    pub fn show(
        &mut self,
        x: f64,
        y: f64,
        style: &CursorStyle,
        animation_style: &AnimationStyle,
        duration: f64,
    ) {
        self.cursor_position.set((x, y));
        *self.style.borrow_mut() = style.clone();

        // Reset animation state
        {
            let mut anim = self.animation.borrow_mut();
            anim.style = animation_style.clone();
            anim.start_time = Some(Instant::now());
            anim.progress = 0.0;
            anim.is_reversing = false;
        }

        self.is_visible.set(true);
        self.window.set_opacity(1.0);
        self.window.fullscreen();
        self.window.present();

        tracing::info!("Presenting fullscreen highlight overlay");

        // Start animation loop with X11 cursor tracking
        self.start_animation_loop(duration);
    }

    /// Hide the highlight
    pub fn hide(&mut self) {
        self.is_visible.set(false);
        self.window.set_opacity(0.0);
        self.window.set_visible(false);
    }

    /// Update position while visible
    pub fn update_position(&mut self, x: f64, y: f64) {
        self.cursor_position.set((x, y));
        if self.is_visible.get() {
            self.drawing_area.queue_draw();
        }
    }

    /// Start the animation loop with X11 cursor position tracking
    fn start_animation_loop(&self, duration: f64) {
        let drawing_area = self.drawing_area.clone();
        let animation = self.animation.clone();
        let is_visible = self.is_visible.clone();
        let window = self.window.clone();
        let cursor_position = self.cursor_position.clone();

        let duration_ms = (duration * 1000.0) as u64;
        let start = Instant::now();

        glib::timeout_add_local(Duration::from_millis(16), move || {
            if !is_visible.get() {
                return ControlFlow::Break;
            }

            // Check if highlight duration has elapsed
            if start.elapsed().as_millis() as u64 >= duration_ms {
                window.set_visible(false);
                window.set_opacity(0.0);
                is_visible.set(false);
                return ControlFlow::Break;
            }

            // Query current cursor position from X11
            if let Some((x, y)) = get_x11_cursor_position() {
                cursor_position.set((x, y));
            }

            // Update animation state
            {
                let mut anim = animation.borrow_mut();
                if let Some(start_time) = anim.start_time {
                    let elapsed = start_time.elapsed().as_secs_f64();
                    let cycle_duration = anim.style.duration;

                    if cycle_duration > 0.0 {
                        let raw_progress = (elapsed % cycle_duration) / cycle_duration;

                        if anim.style.auto_reverse {
                            let cycle = (elapsed / cycle_duration) as u32;
                            anim.is_reversing = cycle % 2 == 1;
                            anim.progress = if anim.is_reversing {
                                1.0 - raw_progress
                            } else {
                                raw_progress
                            };
                        } else {
                            anim.progress = raw_progress;
                        }

                        anim.progress = anim.style.easing.apply(anim.progress);

                        let cycle = (elapsed / cycle_duration) as u32;
                        if anim.style.repeat_count > 0 && cycle >= anim.style.repeat_count {
                            anim.progress = 1.0;
                        }
                    }
                }
            }

            drawing_area.queue_draw();
            ControlFlow::Continue
        });
    }

    /// Draw the highlight at cursor position
    fn draw_highlight(
        cr: &Context,
        cursor_x: f64,
        cursor_y: f64,
        style: &CursorStyle,
        animation: &AnimationState,
    ) {
        // Apply animation
        let (alpha, scale) = match animation.style.animation_type {
            AnimationType::None => (style.color.a as f64, 1.0),
            AnimationType::Pulse => {
                let alpha = 0.3 + 0.7 * (1.0 - animation.progress);
                (alpha * style.color.a as f64, 1.0)
            }
            AnimationType::Fade => {
                let alpha = 1.0 - animation.progress * 0.7;
                (alpha * style.color.a as f64, 1.0)
            }
            AnimationType::Scale => {
                let scale = 0.8 + 0.4 * (1.0 - animation.progress);
                (style.color.a as f64, scale)
            }
            AnimationType::Ripple => {
                let alpha = 1.0 - animation.progress;
                let scale = 1.0 + animation.progress * 0.5;
                (alpha * style.color.a as f64, scale)
            }
        };

        let size = style.size * scale;
        let (r, g, b) = style.color.to_cairo_rgb();

        // Draw glow if enabled
        if style.glow_enabled && style.glow_intensity > 0.0 {
            let glow_alpha = alpha * style.glow_intensity * 0.5;
            let glow_size = size + style.glow_radius * 2.0;

            cr.set_source_rgba(r, g, b, glow_alpha);
            cr.arc(cursor_x, cursor_y, glow_size / 2.0, 0.0, 2.0 * PI);
            cr.fill().ok();
        }

        // Draw main shape
        match style.shape {
            Shape::Circle => {
                cr.set_source_rgba(r, g, b, alpha);
                cr.arc(cursor_x, cursor_y, size / 2.0, 0.0, 2.0 * PI);
                cr.fill().ok();
            }
            Shape::Ring => {
                cr.set_source_rgba(r, g, b, alpha);
                cr.set_line_width(style.border_weight);
                cr.arc(
                    cursor_x,
                    cursor_y,
                    size / 2.0 - style.border_weight / 2.0,
                    0.0,
                    2.0 * PI,
                );
                cr.stroke().ok();
            }
            Shape::Crosshair => {
                cr.set_source_rgba(r, g, b, alpha);
                cr.set_line_width(style.border_weight);

                // Horizontal line
                cr.move_to(cursor_x - size / 2.0, cursor_y);
                cr.line_to(cursor_x + size / 2.0, cursor_y);

                // Vertical line
                cr.move_to(cursor_x, cursor_y - size / 2.0);
                cr.line_to(cursor_x, cursor_y + size / 2.0);

                cr.stroke().ok();
            }
            Shape::Spotlight => {
                let pattern = cairo::RadialGradient::new(
                    cursor_x,
                    cursor_y,
                    0.0,
                    cursor_x,
                    cursor_y,
                    size / 2.0,
                );
                pattern.add_color_stop_rgba(0.0, r, g, b, alpha * 0.8);
                pattern.add_color_stop_rgba(0.5, r, g, b, alpha * 0.3);
                pattern.add_color_stop_rgba(1.0, r, g, b, 0.0);

                cr.set_source(&pattern).ok();
                cr.arc(cursor_x, cursor_y, size / 2.0, 0.0, 2.0 * PI);
                cr.fill().ok();
            }
        }
    }
}
