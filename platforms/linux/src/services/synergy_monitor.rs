//! Synergy 3 monitoring service
//!
//! Monitors Synergy 3 for cursor transitions between machines.

use anyhow::Result;
use notify::{recommended_watcher, Event, EventKind, RecommendedWatcher, RecursiveMode, Watcher};
use std::fs::{self, File};
use std::io::{BufRead, BufReader, Seek, SeekFrom};
use std::path::PathBuf;
use std::sync::mpsc::{channel, Receiver};
use std::thread;
use std::time::Duration;

/// Event emitted when cursor transitions between machines
#[derive(Debug, Clone)]
pub struct CursorTransition {
    pub transition_type: TransitionType,
    pub screen_name: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TransitionType {
    /// Cursor left this machine to go to another
    Left,
    /// Cursor returned to this machine from another
    Returned,
}

/// Monitors Synergy 3 for cursor transitions
pub struct SynergyMonitor {
    watcher: Option<RecommendedWatcher>,
    on_cursor_left: Option<Box<dyn Fn(&str) + Send + 'static>>,
    on_cursor_returned: Option<Box<dyn Fn(&str) + Send + 'static>>,
    last_position: u64,
    log_path: Option<PathBuf>,
    cursor_is_remote: bool,
}

impl SynergyMonitor {
    /// Create a new Synergy monitor
    pub fn new() -> Self {
        Self {
            watcher: None,
            on_cursor_left: None,
            on_cursor_returned: None,
            last_position: 0,
            log_path: None,
            cursor_is_remote: false,
        }
    }

    /// Set callback for when cursor leaves this machine
    pub fn set_on_cursor_left(&mut self, callback: Box<dyn Fn(&str) + Send + 'static>) {
        self.on_cursor_left = Some(callback);
    }

    /// Set callback for when cursor returns to this machine
    pub fn set_on_cursor_returned(&mut self, callback: Box<dyn Fn(&str) + Send + 'static>) {
        self.on_cursor_returned = Some(callback);
    }

    /// Whether the cursor is currently on a remote machine
    pub fn is_cursor_remote(&self) -> bool {
        self.cursor_is_remote
    }

    /// Start monitoring Synergy
    pub fn start(&mut self) -> Result<()> {
        // Find Synergy log file
        let log_path = self.find_synergy_log()?;
        tracing::info!("Found Synergy log at {:?}", log_path);

        // Seek to end of file (we only want new entries)
        if let Ok(file) = File::open(&log_path) {
            self.last_position = file.metadata()?.len();
        }

        self.log_path = Some(log_path.clone());

        // Set up file watcher
        let (tx, rx) = channel();

        let mut watcher = recommended_watcher(move |res: Result<Event, notify::Error>| {
            if let Ok(event) = res {
                let _ = tx.send(event);
            }
        })?;

        watcher.watch(&log_path, RecursiveMode::NonRecursive)?;
        self.watcher = Some(watcher);

        // Spawn thread to process events
        let log_path_clone = log_path.clone();
        let last_position = self.last_position;

        // We can't easily pass callbacks across threads, so we'll use a different approach
        // In a real implementation, we'd use channels or an event system
        thread::spawn(move || {
            Self::event_loop(rx, log_path_clone, last_position);
        });

        Ok(())
    }

    /// Stop monitoring
    pub fn stop(&mut self) {
        self.watcher = None;
    }

    /// Find Synergy log file
    fn find_synergy_log(&self) -> Result<PathBuf> {
        let candidates = [
            // XDG data dir
            dirs::data_local_dir().map(|d| d.join("synergy/synergy.log")),
            // Home directory
            dirs::home_dir().map(|d| d.join(".synergy/synergy.log")),
            dirs::home_dir().map(|d| d.join(".local/share/synergy/synergy.log")),
            // System log
            Some(PathBuf::from("/var/log/synergy.log")),
            // Snap
            dirs::home_dir().map(|d| d.join("snap/synergy/current/.synergy/synergy.log")),
            // Flatpak
            dirs::home_dir()
                .map(|d| d.join(".var/app/com.symless.Synergy/data/synergy/synergy.log")),
        ];

        for candidate in candidates.into_iter().flatten() {
            if candidate.exists() {
                return Ok(candidate);
            }
        }

        anyhow::bail!("Synergy log file not found")
    }

    /// Event processing loop
    fn event_loop(rx: Receiver<Event>, log_path: PathBuf, mut last_position: u64) {
        for event in rx {
            if matches!(event.kind, EventKind::Modify(_)) {
                if let Some(transitions) = Self::process_new_entries(&log_path, &mut last_position)
                {
                    for transition in transitions {
                        tracing::info!(
                            "Synergy transition: {:?} -> {}",
                            transition.transition_type,
                            transition.screen_name
                        );
                        // In a real implementation, we'd emit events through a channel here
                    }
                }
            }
        }
    }

    /// Process new log entries
    fn process_new_entries(
        log_path: &PathBuf,
        last_position: &mut u64,
    ) -> Option<Vec<CursorTransition>> {
        let mut file = File::open(log_path).ok()?;
        let current_size = file.metadata().ok()?.len();

        if current_size <= *last_position {
            return None;
        }

        file.seek(SeekFrom::Start(*last_position)).ok()?;
        *last_position = current_size;

        let reader = BufReader::new(file);
        let mut transitions = Vec::new();

        for line in reader.lines().flatten() {
            if let Some(transition) = Self::parse_transition_event(&line) {
                transitions.push(transition);
            }
        }

        if transitions.is_empty() {
            None
        } else {
            Some(transitions)
        }
    }

    /// Parse a log line for transition events
    fn parse_transition_event(line: &str) -> Option<CursorTransition> {
        let lower = line.to_lowercase();

        // Detect cursor leaving this machine
        if lower.contains("leaving")
            || lower.contains("switch to")
            || lower.contains("switching to")
        {
            let screen_name = Self::extract_screen_name(line, true).unwrap_or("remote".to_string());
            return Some(CursorTransition {
                transition_type: TransitionType::Left,
                screen_name,
            });
        }

        // Detect cursor returning to this machine
        if lower.contains("entering")
            || lower.contains("switch from")
            || lower.contains("switching from")
        {
            let screen_name =
                Self::extract_screen_name(line, false).unwrap_or("remote".to_string());
            return Some(CursorTransition {
                transition_type: TransitionType::Returned,
                screen_name,
            });
        }

        None
    }

    /// Extract screen name from log line
    fn extract_screen_name(line: &str, leaving: bool) -> Option<String> {
        use regex::Regex;

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
            if let Ok(re) = Regex::new(pattern) {
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
