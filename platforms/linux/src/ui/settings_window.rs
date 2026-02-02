//! Settings window UI

use crate::models::{AnimationType, CursorStyle, Preferences, Shape};
use gtk4::prelude::*;
use gtk4::{
    Adjustment, Box as GtkBox, Button, CheckButton, ColorButton, ComboBoxText, Grid, Label,
    Orientation, Scale, SpinButton, Window,
};
use libadwaita as adw;
use std::sync::Arc;

/// Settings window for CursorHome
pub struct SettingsWindow;

impl SettingsWindow {
    /// Show the settings window
    pub fn show(preferences: Arc<Preferences>) {
        let window = adw::Window::builder()
            .title("CursorHome Settings")
            .default_width(450)
            .default_height(550)
            .build();

        let content = GtkBox::new(Orientation::Vertical, 0);

        // Header bar
        let header = adw::HeaderBar::new();
        content.append(&header);

        // Main content with scrolling
        let scroll = gtk4::ScrolledWindow::builder()
            .hscrollbar_policy(gtk4::PolicyType::Never)
            .vscrollbar_policy(gtk4::PolicyType::Automatic)
            .build();

        let main_box = GtkBox::new(Orientation::Vertical, 24);
        main_box.set_margin_start(24);
        main_box.set_margin_end(24);
        main_box.set_margin_top(24);
        main_box.set_margin_bottom(24);

        // General section
        main_box.append(&Self::create_general_section(&preferences));

        // Appearance section
        main_box.append(&Self::create_appearance_section(&preferences));

        // Animation section
        main_box.append(&Self::create_animation_section(&preferences));

        // Shake detection section
        main_box.append(&Self::create_shake_section(&preferences));

        scroll.set_child(Some(&main_box));
        content.append(&scroll);

        window.set_content(Some(&content));
        window.present();
    }

    fn create_section(title: &str) -> (GtkBox, GtkBox) {
        let section = GtkBox::new(Orientation::Vertical, 12);

        let title_label = Label::new(Some(title));
        title_label.add_css_class("title-4");
        title_label.set_halign(gtk4::Align::Start);
        section.append(&title_label);

        let content = GtkBox::new(Orientation::Vertical, 8);
        content.add_css_class("card");
        content.set_margin_start(0);
        section.append(&content);

        (section, content)
    }

    fn create_general_section(preferences: &Arc<Preferences>) -> GtkBox {
        let (section, content) = Self::create_section("General");

        // Enabled toggle
        let enabled_row = Self::create_row("Enable CursorHome");
        let enabled_check = CheckButton::new();
        enabled_check.set_active(preferences.enabled);
        enabled_row.append(&enabled_check);
        content.append(&enabled_row);

        // Launch at login
        let launch_row = Self::create_row("Launch at login");
        let launch_check = CheckButton::new();
        launch_check.set_active(preferences.launch_at_login);
        launch_row.append(&launch_check);
        content.append(&launch_row);

        // Highlight duration
        let duration_row = Self::create_row("Highlight duration (seconds)");
        let duration_spin = SpinButton::with_range(1.0, 30.0, 0.5);
        duration_spin.set_value(preferences.highlight_duration);
        duration_row.append(&duration_spin);
        content.append(&duration_row);

        section
    }

    fn create_appearance_section(preferences: &Arc<Preferences>) -> GtkBox {
        let (section, content) = Self::create_section("Appearance");

        // Shape selector
        let shape_row = Self::create_row("Shape");
        let shape_combo = ComboBoxText::new();
        for shape in Shape::all() {
            shape_combo.append_text(shape.display_name());
        }
        shape_combo.set_active(Some(match preferences.cursor_style.shape {
            Shape::Circle => 0,
            Shape::Ring => 1,
            Shape::Crosshair => 2,
            Shape::Spotlight => 3,
        }));
        shape_row.append(&shape_combo);
        content.append(&shape_row);

        // Size slider
        let size_row = Self::create_row("Size");
        let size_scale = Scale::with_range(Orientation::Horizontal, 20.0, 200.0, 5.0);
        size_scale.set_value(preferences.cursor_style.size);
        size_scale.set_hexpand(true);
        size_row.append(&size_scale);
        content.append(&size_row);

        // Color picker
        let color_row = Self::create_row("Color");
        let color_button = ColorButton::new();
        color_button.set_rgba(&preferences.cursor_style.color.to_gdk_rgba());
        color_row.append(&color_button);
        content.append(&color_row);

        // Border weight
        let border_row = Self::create_row("Border weight");
        let border_spin = SpinButton::with_range(1.0, 10.0, 1.0);
        border_spin.set_value(preferences.cursor_style.border_weight);
        border_row.append(&border_spin);
        content.append(&border_row);

        // Glow effect
        let glow_row = Self::create_row("Glow effect");
        let glow_check = CheckButton::new();
        glow_check.set_active(preferences.cursor_style.glow_enabled);
        glow_row.append(&glow_check);
        content.append(&glow_row);

        section
    }

    fn create_animation_section(preferences: &Arc<Preferences>) -> GtkBox {
        let (section, content) = Self::create_section("Animation");

        // Animation type
        let type_row = Self::create_row("Animation type");
        let type_combo = ComboBoxText::new();
        for anim in AnimationType::all() {
            type_combo.append_text(anim.display_name());
        }
        type_combo.set_active(Some(match preferences.animation_style.animation_type {
            AnimationType::None => 0,
            AnimationType::Pulse => 1,
            AnimationType::Ripple => 2,
            AnimationType::Fade => 3,
            AnimationType::Scale => 4,
        }));
        type_row.append(&type_combo);
        content.append(&type_row);

        // Duration
        let duration_row = Self::create_row("Animation duration");
        let duration_scale = Scale::with_range(Orientation::Horizontal, 0.1, 2.0, 0.1);
        duration_scale.set_value(preferences.animation_style.duration);
        duration_scale.set_hexpand(true);
        duration_row.append(&duration_scale);
        content.append(&duration_row);

        // Repeat count
        let repeat_row = Self::create_row("Repeat count (0 = infinite)");
        let repeat_spin = SpinButton::with_range(0.0, 10.0, 1.0);
        repeat_spin.set_value(preferences.animation_style.repeat_count as f64);
        repeat_row.append(&repeat_spin);
        content.append(&repeat_row);

        section
    }

    fn create_shake_section(preferences: &Arc<Preferences>) -> GtkBox {
        let (section, content) = Self::create_section("Shake Detection");

        // Enable shake
        let enabled_row = Self::create_row("Shake to find cursor");
        let enabled_check = CheckButton::new();
        enabled_check.set_active(preferences.shake_enabled);
        enabled_row.append(&enabled_check);
        content.append(&enabled_row);

        // Sensitivity
        let sensitivity_row = Self::create_row("Sensitivity");
        let sensitivity_scale = Scale::with_range(Orientation::Horizontal, 0.0, 1.0, 0.05);
        sensitivity_scale.set_value(preferences.shake_sensitivity);
        sensitivity_scale.set_hexpand(true);

        // Add marks
        sensitivity_scale.add_mark(0.0, gtk4::PositionType::Bottom, Some("Low"));
        sensitivity_scale.add_mark(0.5, gtk4::PositionType::Bottom, Some("Medium"));
        sensitivity_scale.add_mark(1.0, gtk4::PositionType::Bottom, Some("High"));

        sensitivity_row.append(&sensitivity_scale);
        content.append(&sensitivity_row);

        section
    }

    fn create_row(label: &str) -> GtkBox {
        let row = GtkBox::new(Orientation::Horizontal, 12);
        row.set_margin_start(12);
        row.set_margin_end(12);
        row.set_margin_top(8);
        row.set_margin_bottom(8);

        let label_widget = Label::new(Some(label));
        label_widget.set_hexpand(true);
        label_widget.set_halign(gtk4::Align::Start);
        row.append(&label_widget);

        row
    }
}
