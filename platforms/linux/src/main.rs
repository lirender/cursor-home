//! CursorHome - Linux (Wayland) Implementation
//!
//! A cursor highlighting utility that integrates with Synergy 3 for
//! cross-machine cursor tracking.

mod app;
mod models;
mod services;
mod ui;

use anyhow::Result;
use tracing_subscriber::{layer::SubscriberExt, util::SubscriberInitExt, EnvFilter};

fn main() -> Result<()> {
    // Initialize logging
    tracing_subscriber::registry()
        .with(EnvFilter::try_from_default_env().unwrap_or_else(|_| EnvFilter::new("info")))
        .with(tracing_subscriber::fmt::layer())
        .init();

    tracing::info!("Starting CursorHome for Linux");

    // Run the GTK application
    app::run()
}
