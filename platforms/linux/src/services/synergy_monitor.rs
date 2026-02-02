//! Synergy 3 monitoring service
//!
//! Monitors Synergy 3 for cursor transitions between machines.

use anyhow::Result;
use gtk4::glib;
use notify::{recommended_watcher, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::fs::File;
use std::io::{BufRead, BufReader, Seek, SeekFrom};
use std::path::PathBuf;
use std::sync::mpsc::{channel, Sender};
use std::thread;

/// Event emitted when cursor transitions between machines
#[derive(Debug, Clone)]
pub enum SynergyEvent {
    CursorLeft(String),
    CursorReturned(String),
}

/// Monitors Synergy 3 for cursor transitions
pub struct SynergyMonitor {
    watcher: Option<RecommendedWatcher>,
    event_sender: Option<glib::Sender<SynergyEvent>>,
}

impl SynergyMonitor {
    /// Create a new Synergy monitor
    pub fn new() -> Self {
        Self {
            watcher: None,
            event_sender: None,
        }
    }

    /// Start monitoring Synergy with a callback for cursor returned events
    pub fn start_with_callback<F>(&mut self, on_cursor_returned: F) -> Result<()>
    where
        F: Fn(String) + 'static,
    {
        // Find Synergy log file
        let log_path = self.find_synergy_log()?;
        tracing::info!("Found Synergy log at {:?}", log_path);

        // Get initial file position (end of file)
        let initial_position = if let Ok(file) = File::open(&log_path) {
            file.metadata()?.len()
        } else {
            0
        };

        // Create glib channel for thread-safe communication
        let (sender, receiver) = glib::MainContext::channel(glib::Priority::DEFAULT);
        self.event_sender = Some(sender.clone());

        // Handle events on the main thread
        receiver.attach(None, move |event| {
            match event {
                SynergyEvent::CursorReturned(screen_name) => {
                    on_cursor_returned(screen_name);
                }
                SynergyEvent::CursorLeft(_) => {
                    // Could handle this too if needed
                }
            }
            glib::ControlFlow::Continue
        });

        // Set up file watcher
        let (tx, rx) = channel();
        let mut watcher = recommended_watcher(move |res: Result<Event, notify::Error>| {
            if let Ok(event) = res {
                let _ = tx.send(event);
            }
        })?;

        watcher.watch(&log_path, RecursiveMode::NonRecursive)?;
        self.watcher = Some(watcher);

        // Spawn thread to process file changes
        thread::spawn(move || {
            let mut last_position = initial_position;

            for event in rx {
                if matches!(event.kind, EventKind::Modify(_)) {
                    if let Some(events) = Self::process_new_entries(&log_path, &mut last_position) {
                        for synergy_event in events {
                            tracing::info!("Synergy transition: {:?}", synergy_event);
                            if sender.send(synergy_event).is_err() {
                                break;
                            }
                        }
                    }
                }
            }
        });

        Ok(())
    }

    /// Find Synergy log file
    fn find_synergy_log(&self) -> Result<PathBuf> {
        let candidates = [
            // Flatpak (Synergy 3)
            dirs::home_dir()
                .map(|d| d.join(".var/app/com.symless.synergy/.local/state/Synergy/synergy.log")),
            // XDG data dir
            dirs::data_local_dir().map(|d| d.join("synergy/synergy.log")),
            dirs::data_local_dir().map(|d| d.join("Synergy/synergy.log")),
            // Home directory
            dirs::home_dir().map(|d| d.join(".synergy/synergy.log")),
            dirs::home_dir().map(|d| d.join(".local/share/synergy/synergy.log")),
            dirs::home_dir().map(|d| d.join(".local/state/Synergy/synergy.log")),
            // System log
            Some(PathBuf::from("/var/log/synergy.log")),
            // Snap
            dirs::home_dir().map(|d| d.join("snap/synergy/current/.synergy/synergy.log")),
        ];

        for candidate in candidates.into_iter().flatten() {
            if candidate.exists() {
                return Ok(candidate);
            }
        }

        anyhow::bail!("Synergy log file not found")
    }

    /// Process new log entries
    fn process_new_entries(log_path: &PathBuf, last_position: &mut u64) -> Option<Vec<SynergyEvent>> {
        let mut file = File::open(log_path).ok()?;
        let current_size = file.metadata().ok()?.len();

        if current_size <= *last_position {
            return None;
        }

        file.seek(SeekFrom::Start(*last_position)).ok()?;
        *last_position = current_size;

        let reader = BufReader::new(file);
        let mut events = Vec::new();

        for line in reader.lines().flatten() {
            if let Some(event) = Self::parse_transition_event(&line) {
                events.push(event);
            }
        }

        if events.is_empty() {
            None
        } else {
            Some(events)
        }
    }

    /// Parse a log line for transition events
    fn parse_transition_event(line: &str) -> Option<SynergyEvent> {
        let lower = line.to_lowercase();

        // Detect cursor leaving this machine
        if lower.contains("leaving")
            || lower.contains("switch to")
            || lower.contains("switching to")
        {
            let screen_name = Self::extract_screen_name(line, true).unwrap_or("remote".to_string());
            return Some(SynergyEvent::CursorLeft(screen_name));
        }

        // Detect cursor returning to this machine
        if lower.contains("entering")
            || lower.contains("switch from")
            || lower.contains("switching from")
        {
            let screen_name = Self::extract_screen_name(line, false).unwrap_or("remote".to_string());
            return Some(SynergyEvent::CursorReturned(screen_name));
        }

        None
    }

    /// Extract screen name from log line
    fn extract_screen_name(line: &str, leaving: bool) -> Option<String> {
        let patterns: &[&str] = if leaving {
            &[
                r"switching to ([\w\-\.]+)",
                r"switch to ([\w\-\.]+)",
                r"leaving .*?to ([\w\-\.]+)",
                r"-> ([\w\-\.]+)",
            ]
        } else {
            &[
                r"switching from ([\w\-\.]+)",
                r"switch from ([\w\-\.]+)",
                r"entering .*?from ([\w\-\.]+)",
                r"<- ([\w\-\.]+)",
            ]
        };

        for pattern in patterns {
            if let Ok(re) = regex::Regex::new(pattern) {
                if let Some(captures) = re.captures(line) {
                    if let Some(name) = captures.get(1) {
                        return Some(name.as_str().to_string());
                    }
                }
            }
        }

        None
    }
}

impl Default for SynergyMonitor {
    fn default() -> Self {
        Self::new()
    }
}
