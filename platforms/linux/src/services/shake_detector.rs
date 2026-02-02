//! Mouse shake detection
//!
//! Detects rapid back-and-forth mouse movement to trigger cursor highlighting.

use anyhow::Result;
use gtk4::glib;
use std::collections::VecDeque;
use std::time::{Duration, Instant};

/// A recorded mouse position with timestamp
#[derive(Debug, Clone, Copy)]
struct PositionSample {
    x: f64,
    y: f64,
    time: Instant,
}

/// Detects mouse shaking gestures
pub struct ShakeDetector {
    samples: VecDeque<PositionSample>,
    on_shake: Option<Box<dyn Fn() + 'static>>,
    sensitivity: f64,
    is_running: bool,

    // Detection parameters
    window_duration: Duration,
    min_direction_changes: usize,
}

impl ShakeDetector {
    /// Create a new shake detector
    ///
    /// # Arguments
    /// * `sensitivity` - Detection sensitivity from 0.0 (least) to 1.0 (most)
    pub fn new(sensitivity: f64) -> Self {
        Self {
            samples: VecDeque::with_capacity(100),
            on_shake: None,
            sensitivity: sensitivity.clamp(0.0, 1.0),
            is_running: false,
            window_duration: Duration::from_millis(400),
            min_direction_changes: 4,
        }
    }

    /// Set the callback for when a shake is detected
    pub fn set_on_shake(&mut self, callback: Box<dyn Fn() + 'static>) {
        self.on_shake = Some(callback);
    }

    /// Set the detection sensitivity
    pub fn set_sensitivity(&mut self, sensitivity: f64) {
        self.sensitivity = sensitivity.clamp(0.0, 1.0);
    }

    /// Start monitoring for shakes
    pub fn start(&mut self) -> Result<()> {
        if self.is_running {
            return Ok(());
        }

        self.is_running = true;
        self.samples.clear();

        tracing::info!("Shake detection started with sensitivity {}", self.sensitivity);
        Ok(())
    }

    /// Stop monitoring
    pub fn stop(&mut self) {
        self.is_running = false;
        self.samples.clear();
    }

    /// Record a new mouse position
    ///
    /// Call this method from pointer motion events.
    pub fn record_position(&mut self, x: f64, y: f64) {
        if !self.is_running {
            return;
        }

        let now = Instant::now();

        // Add new sample
        self.samples.push_back(PositionSample { x, y, time: now });

        // Remove old samples outside the time window
        while let Some(front) = self.samples.front() {
            if now.duration_since(front.time) > self.window_duration {
                self.samples.pop_front();
            } else {
                break;
            }
        }

        // Check for shake pattern
        if self.detect_shake() {
            self.samples.clear();
            if let Some(callback) = &self.on_shake {
                callback();
            }
        }
    }

    /// Detect if current samples indicate a shake
    fn detect_shake(&self) -> bool {
        if self.samples.len() < 4 {
            return false;
        }

        let samples: Vec<_> = self.samples.iter().collect();
        let mut direction_changes = 0;
        let mut total_distance: f64 = 0.0;

        for i in 1..samples.len() {
            let prev = samples[i - 1];
            let curr = samples[i];

            let dx = curr.x - prev.x;
            let distance = dx.abs();
            total_distance += distance;

            // Check for direction change in X axis (horizontal shake)
            if i >= 2 {
                let prev_dx = samples[i - 1].x - samples[i - 2].x;
                if (dx > 0.0 && prev_dx < 0.0) || (dx < 0.0 && prev_dx > 0.0) {
                    direction_changes += 1;
                }
            }
        }

        // Calculate velocity
        let time_span = samples
            .last()
            .unwrap()
            .time
            .duration_since(samples.first().unwrap().time);

        if time_span.as_secs_f64() <= 0.0 {
            return false;
        }

        let velocity = total_distance / time_span.as_secs_f64();

        // Threshold based on sensitivity
        // Higher sensitivity = lower threshold (easier to trigger)
        let min_threshold = 300.0;
        let max_threshold = 900.0;
        let threshold = max_threshold - self.sensitivity * (max_threshold - min_threshold);

        direction_changes >= self.min_direction_changes && velocity > threshold
    }
}

impl Default for ShakeDetector {
    fn default() -> Self {
        Self::new(0.5)
    }
}
