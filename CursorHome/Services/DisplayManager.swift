import AppKit

@Observable
final class DisplayManager {
    static let shared = DisplayManager()

    private(set) var screens: [NSScreen] = []
    private(set) var mainScreen: NSScreen?

    private init() {
        updateScreens()
        setupNotifications()
    }

    // MARK: - Screen Management

    func updateScreens() {
        screens = NSScreen.screens
        mainScreen = NSScreen.main ?? screens.first
    }

    var currentCursorScreen: NSScreen? {
        let cursorLocation = NSEvent.mouseLocation
        return screens.first { $0.frame.contains(cursorLocation) }
    }

    var cursorLocation: CGPoint {
        NSEvent.mouseLocation
    }

    func centerPoint(of screen: NSScreen) -> CGPoint {
        CGPoint(
            x: screen.frame.midX,
            y: screen.frame.midY
        )
    }

    func centerPointInCGCoordinates(of screen: NSScreen) -> CGPoint {
        // Use CGDisplayBounds which gives us coordinates in the CG coordinate system directly
        let displayID = screen.displayID
        let displayBounds = CGDisplayBounds(displayID)

        // Center of the display in CG coordinates
        return CGPoint(
            x: displayBounds.midX,
            y: displayBounds.midY
        )
    }

    // MARK: - Notifications

    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateScreens()
        }
    }
}

// MARK: - NSScreen Extensions

extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }

    var isMainDisplay: Bool {
        self == NSScreen.main
    }

    var displayName: String {
        localizedName
    }
}
