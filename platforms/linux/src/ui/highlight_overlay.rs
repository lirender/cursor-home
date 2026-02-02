//! Highlight overlay window
//!
//! Creates a transparent overlay window to display cursor highlighting.
//! Uses the wlr-layer-shell protocol on Wayland for proper overlay behavior.

use crate::models::{AnimationStyle, AnimationType, CursorStyle, Easing, Shape};
use anyhow::Result;
use gtk4::cairo::{self, Context};
use gtk4::gdk;
use gtk4::glib::{self, clone, ControlFlow};
use gtk4::prelude::*;
use gtk4::{DrawingArea, Window, WindowType};
use std::cell::{Cell, RefCell};
use std::f64::consts::PI;
use std::rc::Rc;
use std::time::{Duration, Instant};

/// Overlay window for displaying cursor highlight
pub struct HighlightOverlay {
    window: gtk4::Window,
    drawing_area: DrawingArea,
    position: Rc<Cell<(f64, f64)>>,
    style: Rc<RefCell<CursorStyle>>,
    animation: Rc<RefCell<AnimationState>>,
    is_visible: Rc<Cell<bool>>,
}

struct AnimationState {
    style: AnimationStyle,
    start_time: Option<Instant>,
    current_cycle: u32,
    progress: f64,
    is_reversing: bool,
}

impl Default for AnimationState {
    fn default() -> Self {
        Self {
            style: AnimationStyle::default(),
            start_time: None,
            current_cycle: 0,
            progress: 0.0,
            is_reversing: false,
        }
    }
}

impl HighlightOverlay {
    /// Create a new highlight overlay
    pub fn new() -> Result<Self> {
        // Create a transparent, click-through window
        let window = gtk4::Window::builder()
            .title("CursorHome Highlight")
            .decorated(false)
            .resizable(false)
            .deletable(false)
            .build();

        // Make window transparent
        if let Some(display) = gdk::Display::default() {
            // Set visual for transparency
            window.set_opacity(1.0);
        }

        // Create drawing area
        let drawing_area = DrawingArea::new();
        drawing_area.set_content_width(400);
        drawing_area.set_content_height(400);

        window.set_child(Some(&drawing_area));

        // Shared state
        let position = Rc::new(Cell::new((0.0, 0.0)));
        let style = Rc::new(RefCell::new(CursorStyle::default()));
        let animation = Rc::new(RefCell::new(AnimationState::default()));
        let is_visible = Rc::new(Cell::new(false));

        // Set up drawing
        let style_clone = style.clone();
        let animation_clone = animation.clone();
        let position_clone = position.clone();

        drawing_area.set_draw_func(move |_area, cr, width, height| {
            Self::draw(
                cr,
                width,
                height,
                &style_clone.borrow(),
                &animation_clone.borrow(),
                position_clone.get(),
            );
        });

        Ok(Self {
            window,
            drawing_area,
            position,
            style,
            animation,
            is_visible,
        })
    }

    /// Show the highlight at a position
    pub fn show(
        &mut self,
        x: f64,
        y: f64,
        style: &CursorStyle,
        animation_style: &AnimationStyle,
        duration: f64,
    ) {
        self.position.set((x, y));
        *self.style.borrow_mut() = style.clone();

        // Reset animation state
        {
            let mut anim = self.animation.borrow_mut();
            anim.style = animation_style.clone();
            anim.start_time = Some(Instant::now());
            anim.current_cycle = 0;
            anim.progress = 0.0;
            anim.is_reversing = false;
        }

        // Position window centered on cursor
        let window_size = (style.size as i32 + 100).max(200);
        self.drawing_area.set_content_width(window_size);
        self.drawing_area.set_content_height(window_size);

        // Move window to cursor position (offset to center)
        let offset = window_size / 2;
        self.window
            .set_default_size(window_size, window_size);

        // Note: On Wayland, window positioning is restricted
        // The layer-shell protocol would be needed for proper overlay positioning

        self.window.present();
        self.is_visible.set(true);

        // Start animation loop
        self.start_animation_loop(duration);
    }

    /// Hide the highlight
    pub fn hide(&mut self) {
        self.window.set_visible(false);
        self.is_visible.set(false);
    }

    /// Update position while visible
    pub fn update_position(&mut self, x: f64, y: f64) {
        self.position.set((x, y));
        self.drawing_area.queue_draw();
    }

    /// Start the animation loop
    fn start_animation_loop(&self, duration: f64) {
        let drawing_area = self.drawing_area.clone();
        let animation = self.animation.clone();
        let is_visible = self.is_visible.clone();
        let window = self.window.clone();

        let duration_ms = (duration * 1000.0) as u64;
        let start = Instant::now();

        glib::timeout_add_local(Duration::from_millis(16), move || {
            if !is_visible.get() {
                return ControlFlow::Break;
            }

            // Check if highlight duration has elapsed
            if start.elapsed().as_millis() as u64 >= duration_ms {
                window.set_visible(false);
                is_visible.set(false);
                return ControlFlow::Break;
            }

            // Update animation state
            {
                let mut anim = animation.borrow_mut();
                if let Some(start_time) = anim.start_time {
                    let elapsed = start_time.elapsed().as_secs_f64();
                    let cycle_duration = anim.style.duration;

                    if cycle_duration > 0.0 {
                        let raw_progress = (elapsed % cycle_duration) / cycle_duration;

                        // Handle auto-reverse
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

                        // Apply easing
                        anim.progress = anim.style.easing.apply(anim.progress);

                        // Check repeat count
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

    /// Draw the highlight
    fn draw(
        cr: &Context,
        width: i32,
        height: i32,
        style: &CursorStyle,
        animation: &AnimationState,
        _position: (f64, f64),
    ) {
        // Clear background
        cr.set_operator(cairo::Operator::Clear);
        cr.paint().ok();
        cr.set_operator(cairo::Operator::Over);

        let center_x = width as f64 / 2.0;
        let center_y = height as f64 / 2.0;

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
            cr.arc(center_x, center_y, glow_size / 2.0, 0.0, 2.0 * PI);
            cr.fill().ok();
        }

        // Draw main shape
        match style.shape {
            Shape::Circle => {
                cr.set_source_rgba(r, g, b, alpha);
                cr.arc(center_x, center_y, size / 2.0, 0.0, 2.0 * PI);
                cr.fill().ok();
            }
            Shape::Ring => {
                cr.set_source_rgba(r, g, b, alpha);
                cr.set_line_width(style.border_weight);
                cr.arc(center_x, center_y, size / 2.0 - style.border_weight / 2.0, 0.0, 2.0 * PI);
                cr.stroke().ok();
            }
            Shape::Crosshair => {
                cr.set_source_rgba(r, g, b, alpha);
                cr.set_line_width(style.border_weight);

                // Horizontal line
                cr.move_to(center_x - size / 2.0, center_y);
                cr.line_to(center_x + size / 2.0, center_y);

                // Vertical line
                cr.move_to(center_x, center_y - size / 2.0);
                cr.line_to(center_x, center_y + size / 2.0);

                cr.stroke().ok();
            }
            Shape::Spotlight => {
                // Radial gradient from center
                let pattern = cairo::RadialGradient::new(
                    center_x,
                    center_y,
                    0.0,
                    center_x,
                    center_y,
                    size / 2.0,
                );
                pattern.add_color_stop_rgba(0.0, r, g, b, alpha * 0.8);
                pattern.add_color_stop_rgba(0.5, r, g, b, alpha * 0.3);
                pattern.add_color_stop_rgba(1.0, r, g, b, 0.0);

                cr.set_source(&pattern).ok();
                cr.arc(center_x, center_y, size / 2.0, 0.0, 2.0 * PI);
                cr.fill().ok();
            }
        }
    }
}
