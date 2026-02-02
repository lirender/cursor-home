//! User preferences storage

use super::{AnimationStyle, CursorStyle};
use directories::ProjectDirs;
use serde::{Deserialize, Serialize};
use std::fs;
use std::path::PathBuf;

/// User preferences for CursorHome
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Preferences {
    /// Whether CursorHome is enabled
    pub enabled: bool,

    /// Cursor highlight style
    pub cursor_style: CursorStyle,

    /// Animation style
    pub animation_style: AnimationStyle,

    /// Duration to show highlight (seconds)
    pub highlight_duration: f64,

    /// Enable shake-to-find
    pub shake_enabled: bool,

    /// Shake detection sensitivity (0.0 to 1.0)
    pub shake_sensitivity: f64,

    /// Magnifier zoom level
    pub magnifier_zoom: f64,

    /// Magnifier window size
    pub magnifier_size: f64,

    /// Launch at login
    pub launch_at_login: bool,
}

impl Default for Preferences {
    fn default() -> Self {
        Self {
            enabled: true,
            cursor_style: CursorStyle::default(),
            animation_style: AnimationStyle::default(),
            highlight_duration: 5.0,
            shake_enabled: true,
            shake_sensitivity: 0.5,
            magnifier_zoom: 2.0,
            magnifier_size: 150.0,
            launch_at_login: false,
        }
    }
}

impl Preferences {
    /// Get the configuration directory path
    fn config_dir() -> Option<PathBuf> {
        ProjectDirs::from("com", "cursorhome", "CursorHome")
            .map(|dirs| dirs.config_dir().to_path_buf())
    }

    /// Get the configuration file path
    fn config_file() -> Option<PathBuf> {
        Self::config_dir().map(|dir| dir.join("preferences.json"))
    }

    /// Load preferences from disk, or return defaults
    pub fn load() -> Self {
        let Some(path) = Self::config_file() else {
            tracing::warn!("Could not determine config directory");
            return Self::default();
        };

        match fs::read_to_string(&path) {
            Ok(content) => match serde_json::from_str(&content) {
                Ok(prefs) => {
                    tracing::info!("Loaded preferences from {:?}", path);
                    prefs
                }
                Err(e) => {
                    tracing::warn!("Failed to parse preferences: {}", e);
                    Self::default()
                }
            },
            Err(_) => {
                tracing::info!("No existing preferences, using defaults");
                let prefs = Self::default();
                prefs.save();
                prefs
            }
        }
    }

    /// Save preferences to disk
    pub fn save(&self) {
        let Some(dir) = Self::config_dir() else {
            tracing::warn!("Could not determine config directory");
            return;
        };

        if let Err(e) = fs::create_dir_all(&dir) {
            tracing::error!("Failed to create config directory: {}", e);
            return;
        }

        let Some(path) = Self::config_file() else {
            return;
        };

        match serde_json::to_string_pretty(self) {
            Ok(content) => {
                if let Err(e) = fs::write(&path, content) {
                    tracing::error!("Failed to write preferences: {}", e);
                } else {
                    tracing::debug!("Saved preferences to {:?}", path);
                }
            }
            Err(e) => {
                tracing::error!("Failed to serialize preferences: {}", e);
            }
        }
    }
}
