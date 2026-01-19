import AppKit
import SwiftUI

final class StatusBarController {
    private var statusItem: NSStatusItem
    private let preferences = UserPreferences.shared
    private let cursorFinder = CursorFinderService.shared
    private var settingsWindow: NSWindow?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        setupStatusItem()
    }

    private func setupStatusItem() {
        guard let button = statusItem.button else { return }

        // Set icon
        let icon = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: "CursorHome")
        icon?.isTemplate = true
        button.image = icon

        // Handle option-click for quick toggle
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.action = #selector(handleClick(_:))
        button.target = self

        // Setup menu
        updateMenu()
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { return }

        if event.modifierFlags.contains(.option) {
            // Option-click: toggle enabled state
            preferences.enabled.toggle()
        } else {
            // Left-click or right-click: show menu
            statusItem.menu = createMenu()
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
        }
    }

    func updateMenu() {
        statusItem.menu = nil // Menu is shown on demand
    }

    private func createMenu() -> NSMenu {
        let menu = NSMenu()

        // Status header
        let statusTitle = preferences.enabled ? "CursorHome Active" : "CursorHome Disabled"
        let statusItem = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        menu.addItem(NSMenuItem.separator())

        // Find Cursor
        let findItem = NSMenuItem(
            title: "Find Cursor",
            action: #selector(findCursor),
            keyEquivalent: ""
        )
        findItem.target = self
        findItem.isEnabled = preferences.enabled
        menu.addItem(findItem)

        menu.addItem(NSMenuItem.separator())

        // Toggle Magnifier
        let magnifierItem = NSMenuItem(
            title: MagnifierService.shared.isActive ? "Hide Magnifier" : "Show Magnifier",
            action: #selector(toggleMagnifier),
            keyEquivalent: ""
        )
        magnifierItem.target = self
        magnifierItem.isEnabled = preferences.magnifierEnabled
        menu.addItem(magnifierItem)

        menu.addItem(NSMenuItem.separator())

        // Enable/Disable
        let toggleItem = NSMenuItem(
            title: preferences.enabled ? "Disable" : "Enable",
            action: #selector(toggleEnabled),
            keyEquivalent: ""
        )
        toggleItem.target = self
        menu.addItem(toggleItem)

        menu.addItem(NSMenuItem.separator())

        // Hotkey info
        let hotkeyItem = NSMenuItem(
            title: "Shortcut: \(preferences.hotkeyDescription)",
            action: nil,
            keyEquivalent: ""
        )
        hotkeyItem.isEnabled = false
        menu.addItem(hotkeyItem)

        menu.addItem(NSMenuItem.separator())

        // Settings
        let settingsItem = NSMenuItem(
            title: "Settings...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(
            title: "Quit CursorHome",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        return menu
    }

    @objc private func findCursor() {
        cursorFinder.findCursor()
    }

    @objc private func toggleMagnifier() {
        MagnifierService.shared.toggle()
    }

    @objc private func toggleEnabled() {
        preferences.enabled.toggle()
    }

    @objc private func openSettings() {
        if let window = settingsWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let settingsView = SettingsView()
        let hostingController = NSHostingController(rootView: settingsView)

        let window = NSWindow(contentViewController: hostingController)
        window.title = "CursorHome Settings"
        window.styleMask = [.titled, .closable]
        window.center()
        window.setFrameAutosaveName("SettingsWindow")
        window.isReleasedWhenClosed = false

        self.settingsWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

// MARK: - Menu Item Action Extension

private extension NSMenuItem {
    func performAction() {
        guard let action = action else { return }
        _ = target?.perform(action, with: self)
    }
}
