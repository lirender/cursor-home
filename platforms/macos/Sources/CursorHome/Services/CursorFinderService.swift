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
// Uses macOS private CGSGetCursorScale API to detect when the system's
// built-in "Shake mouse pointer to locate" feature activates. This ensures
// perfect synchronization with macOS's own shake detection.

@_silgen_name("CGSMainConnectionID")
private func CGSMainConnectionID() -> UInt32

@_silgen_name("CGSGetCursorScale")
private func CGSGetCursorScale(_ cid: UInt32, _ outScale: UnsafeMutablePointer<CGFloat>) -> Int32

final class MouseShakeDetector {
    private var pollTimer: DispatchSourceTimer?
    private let onShakeDetected: () -> Void
    private var wasShaking = false
    private let connectionID: UInt32

    /// Sensitivity is kept for API compatibility but is unused —
    /// we rely on macOS's own detection which respects system preferences.
    var sensitivity: Double = 0.5

    init(sensitivity: Double = 0.5, onShakeDetected: @escaping () -> Void) {
        self.sensitivity = sensitivity
        self.onShakeDetected = onShakeDetected
        self.connectionID = CGSMainConnectionID()
    }

    func start() {
        guard pollTimer == nil else { return }

        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.schedule(deadline: .now(), repeating: .milliseconds(16)) // ~60 Hz
        timer.setEventHandler { [weak self] in
            self?.poll()
        }
        timer.resume()
        pollTimer = timer
    }

    func stop() {
        pollTimer?.cancel()
        pollTimer = nil
        wasShaking = false
    }

    private func poll() {
        var scale: CGFloat = 0
        let result = CGSGetCursorScale(connectionID, &scale)
        guard result == 0 else { return }

        let isShaking = scale > 1.0

        // Fire once on the rising edge (transition from not-shaking to shaking)
        if isShaking && !wasShaking {
            onShakeDetected()
        }
        wasShaking = isShaking
    }

    deinit {
        stop()
    }
}
