import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private let cursorFinder = CursorFinderService.shared
    private let hotkeyManager = HotkeyManager.shared
    private let magnifierService = MagnifierService.shared
    private let preferences = UserPreferences.shared

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon by default (menu bar app)
        if !preferences.showInDock {
            NSApp.setActivationPolicy(.accessory)
        }

        // Setup status bar
        statusBarController = StatusBarController()

        // Check accessibility permissions
        if !HotkeyManager.hasAccessibilityPermission {
            HotkeyManager.requestAccessibilityPermission()
        }

        // Setup hotkeys
        setupHotkeys()

        // Setup cursor finder (shake detection)
        cursorFinder.setup()

        // Apply launch at login setting
        if preferences.launchAtLogin != LaunchAtLoginManager.isEnabled {
            LaunchAtLoginManager.setEnabled(preferences.launchAtLogin)
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        cursorFinder.hideAllHighlights()
        magnifierService.hide()
    }

    private func setupHotkeys() {
        hotkeyManager.onFindCursor = { [weak self] in
            self?.handleFindCursor()
        }

        hotkeyManager.onMagnifierToggle = { [weak self] in
            self?.magnifierService.toggle()
        }

        hotkeyManager.setup()
    }

    private func handleFindCursor() {
        cursorFinder.findCursor()
    }
}
