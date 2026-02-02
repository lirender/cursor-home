//! Cursor highlight style definitions

use serde::{Deserialize, Serialize};

/// Shape of the cursor highlight
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum Shape {
    Circle,
    #[default]
    Ring,
    Crosshair,
    Spotlight,
}

impl Shape {
    pub fn all() -> &'static [Shape] {
        &[Shape::Circle, Shape::Ring, Shape::Crosshair, Shape::Spotlight]
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            Shape::Circle => "Filled Circle",
            Shape::Ring => "Ring",
            Shape::Crosshair => "Crosshair",
            Shape::Spotlight => "Spotlight",
        }
    }
}

/// RGBA color
#[derive(Debug, Clone, Copy, PartialEq, Serialize, Deserialize)]
pub struct Color {
    pub r: u8,
    pub g: u8,
    pub b: u8,
    pub a: f32,
}

impl Default for Color {
    fn default() -> Self {
        // Orange color (macOS default)
        Self {
            r: 255,
            g: 149,
            b: 0,
            a: 1.0,
        }
    }
}

impl Color {
    pub fn new(r: u8, g: u8, b: u8, a: f32) -> Self {
        Self { r, g, b, a }
    }

    /// Convert to GTK RGBA format
    pub fn to_gdk_rgba(&self) -> gtk4::gdk::RGBA {
        gtk4::gdk::RGBA::new(
            self.r as f32 / 255.0,
            self.g as f32 / 255.0,
            self.b as f32 / 255.0,
            self.a,
        )
    }

    /// Convert to Cairo RGB format (0.0-1.0)
    pub fn to_cairo_rgb(&self) -> (f64, f64, f64) {
        (
            self.r as f64 / 255.0,
            self.g as f64 / 255.0,
            self.b as f64 / 255.0,
        )
    }

    /// Convert to Cairo RGBA format (0.0-1.0)
    pub fn to_cairo_rgba(&self) -> (f64, f64, f64, f64) {
        (
            self.r as f64 / 255.0,
            self.g as f64 / 255.0,
            self.b as f64 / 255.0,
            self.a as f64,
        )
    }
}

/// Border style for ring and crosshair shapes
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum BorderStyle {
    #[default]
    Solid,
    Dashed,
    Dotted,
}

/// Cursor highlight style configuration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct CursorStyle {
    pub shape: Shape,
    pub size: f64,
    pub color: Color,
    pub border_weight: f64,
    pub border_style: BorderStyle,
    pub glow_enabled: bool,
    pub glow_intensity: f64,
    pub glow_radius: f64,
}

impl Default for CursorStyle {
    fn default() -> Self {
        Self {
            shape: Shape::Ring,
            size: 60.0,
            color: Color::default(),
            border_weight: 4.0,
            border_style: BorderStyle::Solid,
            glow_enabled: true,
            glow_intensity: 0.5,
            glow_radius: 10.0,
        }
    }
}

/// Animation type
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "lowercase")]
pub enum AnimationType {
    None,
    #[default]
    Pulse,
    Ripple,
    Fade,
    Scale,
}

impl AnimationType {
    pub fn all() -> &'static [AnimationType] {
        &[
            AnimationType::None,
            AnimationType::Pulse,
            AnimationType::Ripple,
            AnimationType::Fade,
            AnimationType::Scale,
        ]
    }

    pub fn display_name(&self) -> &'static str {
        match self {
            AnimationType::None => "None",
            AnimationType::Pulse => "Pulse",
            AnimationType::Ripple => "Ripple",
            AnimationType::Fade => "Fade",
            AnimationType::Scale => "Scale",
        }
    }
}

/// Animation easing function
#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize, Deserialize, Default)]
#[serde(rename_all = "snake_case")]
pub enum Easing {
    Linear,
    EaseIn,
    EaseOut,
    #[default]
    EaseInOut,
}

impl Easing {
    /// Apply easing function to a progress value (0.0 to 1.0)
    pub fn apply(&self, t: f64) -> f64 {
        match self {
            Easing::Linear => t,
            Easing::EaseIn => t * t,
            Easing::EaseOut => 1.0 - (1.0 - t) * (1.0 - t),
            Easing::EaseInOut => {
                if t < 0.5 {
                    2.0 * t * t
                } else {
                    1.0 - (-2.0 * t + 2.0).powi(2) / 2.0
                }
            }
        }
    }
}

/// Animation style configuration
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
pub struct AnimationStyle {
    pub animation_type: AnimationType,
    pub duration: f64,
    pub easing: Easing,
    pub repeat_count: u32,
    pub auto_reverse: bool,
}

impl Default for AnimationStyle {
    fn default() -> Self {
        Self {
            animation_type: AnimationType::Pulse,
            duration: 0.8,
            easing: Easing::EaseInOut,
            repeat_count: 3,
            auto_reverse: true,
        }
    }
}
