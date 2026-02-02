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

        // If highlight is already active, teleport to center of main display
        if isHighlightActive {
            teleportToMainDisplayCenter()
            return
        }

        let currentLocation = displayManager.cursorLocation

        // Synergy 3 compatibility: If cursor is not on any local screen
        // (e.g., it's on another computer via Synergy), bring it back to main display
        guard let currentScreen = displayManager.currentCursorScreen else {
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
        shakeDetector = MouseShakeDetector { [weak self] in
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

final class MouseShakeDetector {
    private var eventMonitor: Any?
    private var previousLocations: [(point: CGPoint, time: TimeInterval)] = []
    private let onShakeDetected: () -> Void

    private let shakeThreshold: CGFloat = 600 // pixels per second
    private let shakeWindowDuration: TimeInterval = 0.4
    private let minimumDirectionChanges = 4

    init(onShakeDetected: @escaping () -> Void) {
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

        // Add current location
        previousLocations.append((currentLocation, currentTime))

        // Remove old locations outside the time window
        previousLocations.removeAll { currentTime - $0.time > shakeWindowDuration }

        // Need at least a few points to detect shake
        guard previousLocations.count >= 4 else { return }

        // Check for shake pattern (rapid direction changes with high velocity)
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
            let distance = abs(dx)
            totalDistance += distance

            // Check for direction change in X axis (horizontal shake)
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
