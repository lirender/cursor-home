import AppKit
import QuartzCore

@Observable
final class CursorFinderService {
    static let shared = CursorFinderService()

    private let displayManager = DisplayManager.shared
    private let preferences = UserPreferences.shared

    private var highlightWindows: [NSScreen: HighlightWindow] = [:]
    private var shakeDetector: MouseShakeDetector?
    private var isHighlightActive = false

    private init() {}

    func setup() {
        setupShakeDetection()
    }

    // MARK: - Public API

    func findCursor() {
        guard preferences.enabled else { return }

        let currentLocation = displayManager.cursorLocation

        // If cursor is not on any local screen (e.g., on another computer via Synergy),
        // do nothing - don't highlight or teleport
        guard let currentScreen = displayManager.currentCursorScreen else {
            return
        }

        // If highlight is already active, teleport to center of main display
        if isHighlightActive {
            teleportToMainDisplayCenter()
            return
        }

        showHighlight(at: currentLocation, on: currentScreen)
    }

    func showHighlight(at point: CGPoint, on screen: NSScreen) {
        isHighlightActive = true

        // Hide any existing highlights on other screens
        for (existingScreen, window) in highlightWindows where existingScreen != screen {
            window.hideHighlight()
        }

        let window = getOrCreateHighlightWindow(for: screen)
        window.showHighlight(
            at: point,
            style: preferences.cursorStyle,
            animation: preferences.animationStyle,
            duration: preferences.highlightDuration,
            onHide: { [weak self] in
                self?.isHighlightActive = false
            },
            onScreenChanged: { [weak self] newScreen in
                guard let self = self else { return }
                // Transfer highlight to the new screen
                let newLocation = self.displayManager.cursorLocation
                self.showHighlight(at: newLocation, on: newScreen)
            }
        )
    }

    func hideAllHighlights() {
        highlightWindows.values.forEach { $0.hideHighlight() }
        isHighlightActive = false
    }

    // MARK: - Teleport to Center

    private func teleportToMainDisplayCenter() {
        guard let mainScreen = displayManager.mainScreen else { return }

        // Convert to CG coordinates for CGWarpMouseCursorPosition
        let centerCG = displayManager.centerPointInCGCoordinates(of: mainScreen)

        // Synergy 3 compatibility: Disassociate mouse from cursor position before warping
        // This allows Synergy to properly track the programmatic cursor movement
        CGAssociateMouseAndMouseCursorPosition(0)

        CGWarpMouseCursorPosition(centerCG)

        // Post a mouse moved event to notify Synergy and other software of the position change
        if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: centerCG, mouseButton: .left) {
            moveEvent.post(tap: .cghidEventTap)
        }

        // Re-associate mouse with cursor position
        CGAssociateMouseAndMouseCursorPosition(1)

        // Show highlight at new position
        let centerNS = displayManager.centerPoint(of: mainScreen)
        showHighlight(at: centerNS, on: mainScreen)
    }

    // MARK: - Shake Detection

    private func setupShakeDetection() {
        shakeDetector = MouseShakeDetector(sensitivity: preferences.shakeSensitivity) { [weak self] in
            guard let self = self,
                  self.preferences.enabled,
                  self.preferences.autoHighlightOnShake else { return }
            self.findCursor()
        }
        shakeDetector?.start()
    }

    func updateShakeDetection() {
        if preferences.autoHighlightOnShake {
            shakeDetector?.start()
        } else {
            shakeDetector?.stop()
        }
    }

    func updateShakeSensitivity() {
        shakeDetector?.sensitivity = preferences.shakeSensitivity
    }

    // MARK: - Window Management

    private func getOrCreateHighlightWindow(for screen: NSScreen) -> HighlightWindow {
        if let existing = highlightWindows[screen] {
            return existing
        }

        let window = HighlightWindow(screen: screen)
        highlightWindows[screen] = window
        return window
    }
}

// MARK: - Mouse Shake Detector
// Detects rapid horizontal mouse shaking by monitoring global mouse move events,
// tracking direction changes and velocity within a short time window.

final class MouseShakeDetector {
    private var eventMonitor: Any?
    private var previousLocations: [(point: CGPoint, time: TimeInterval)] = []
    private let onShakeDetected: () -> Void

    private let shakeWindowDuration: TimeInterval = 0.4
    private let minimumDirectionChanges = 4

    /// Sensitivity from 0.0 (least sensitive) to 1.0 (most sensitive)
    var sensitivity: Double = 0.5

    /// Computed threshold based on sensitivity
    /// Higher sensitivity = lower threshold (easier to trigger)
    private var shakeThreshold: CGFloat {
        let minThreshold: CGFloat = 300
        let maxThreshold: CGFloat = 900
        return maxThreshold - CGFloat(sensitivity) * (maxThreshold - minThreshold)
    }

    init(sensitivity: Double = 0.5, onShakeDetected: @escaping () -> Void) {
        self.sensitivity = sensitivity
        self.onShakeDetected = onShakeDetected
    }

    func start() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            self?.handleMouseMove(event)
        }
    }

    func stop() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        previousLocations.removeAll()
    }

    private func handleMouseMove(_ event: NSEvent) {
        let currentLocation = NSEvent.mouseLocation
        let currentTime = Date().timeIntervalSince1970

        previousLocations.append((currentLocation, currentTime))

        // Remove old locations outside the time window
        previousLocations.removeAll { currentTime - $0.time > shakeWindowDuration }

        guard previousLocations.count >= 4 else { return }

        if detectShake() {
            previousLocations.removeAll()
            DispatchQueue.main.async {
                self.onShakeDetected()
            }
        }
    }

    private func detectShake() -> Bool {
        guard previousLocations.count >= 4 else { return false }

        var directionChanges = 0
        var totalDistance: CGFloat = 0

        for i in 1..<previousLocations.count {
            let prev = previousLocations[i - 1]
            let curr = previousLocations[i]

            let dx = curr.point.x - prev.point.x
            totalDistance += abs(dx)

            if i >= 2 {
                let prevDx = previousLocations[i - 1].point.x - previousLocations[i - 2].point.x
                if (dx > 0 && prevDx < 0) || (dx < 0 && prevDx > 0) {
                    directionChanges += 1
                }
            }
        }

        let timeSpan = previousLocations.last!.time - previousLocations.first!.time
        guard timeSpan > 0 else { return false }

        let velocity = totalDistance / CGFloat(timeSpan)

        return directionChanges >= minimumDirectionChanges && velocity > shakeThreshold
    }

    deinit {
        stop()
    }
}
