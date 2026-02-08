import SwiftUI
import Carbon.HIToolbox

@Observable
final class UserPreferences {
    static let shared = UserPreferences()

    // MARK: - Appearance
    var cursorStyle: CursorStyle {
        didSet { save() }
    }

    var animationStyle: AnimationStyle {
        didSet { save() }
    }

    var movementStyle: CursorMovementStyle {
        didSet { save() }
    }

    // MARK: - Magnifier
    var magnifierEnabled: Bool {
        didSet { save() }
    }

    var magnifierZoom: CGFloat {
        didSet { save() }
    }

    var magnifierSize: CGFloat {
        didSet { save() }
    }

    var magnifierHighQuality: Bool {
        didSet { save() }
    }

    // MARK: - Hotkey
    var hotkeyKeyCode: UInt32 {
        didSet { save() }
    }

    var hotkeyModifiers: UInt32 {
        didSet { save() }
    }

    var magnifierHotkeyKeyCode: UInt32 {
        didSet { save() }
    }

    var magnifierHotkeyModifiers: UInt32 {
        didSet { save() }
    }

    // MARK: - Behavior
    var highlightDuration: Double {
        didSet { save() }
    }

    var autoHighlightOnShake: Bool {
        didSet { save() }
    }

    /// Shake sensitivity: 0.0 (least sensitive) to 1.0 (most sensitive)
    var shakeSensitivity: Double {
        didSet { save() }
    }

    // MARK: - General
    var launchAtLogin: Bool {
        didSet {
            save()
            LaunchAtLoginManager.setEnabled(launchAtLogin)
        }
    }

    var showInDock: Bool {
        didSet { save() }
    }

    var enabled: Bool {
        didSet { save() }
    }

    // MARK: - Initialization

    private init() {
        let defaults = UserDefaults.standard

        // Load cursor style
        if let data = defaults.data(forKey: "cursorStyle"),
           let style = try? JSONDecoder().decode(CursorStyle.self, from: data) {
            self.cursorStyle = style
        } else {
            self.cursorStyle = .default
        }

        // Load animation style
        if let data = defaults.data(forKey: "animationStyle"),
           let style = try? JSONDecoder().decode(AnimationStyle.self, from: data) {
            self.animationStyle = style
        } else {
            self.animationStyle = .default
        }

        // Load movement style
        if let data = defaults.data(forKey: "movementStyle"),
           let style = try? JSONDecoder().decode(CursorMovementStyle.self, from: data) {
            self.movementStyle = style
        } else {
            self.movementStyle = .default
        }

        // Magnifier
        self.magnifierEnabled = defaults.bool(forKey: "magnifierEnabled")
        self.magnifierZoom = defaults.double(forKey: "magnifierZoom").nonZero ?? 2.0
        self.magnifierSize = defaults.double(forKey: "magnifierSize").nonZero ?? 150.0
        self.magnifierHighQuality = defaults.object(forKey: "magnifierHighQuality") as? Bool ?? true

        // Hotkey - Default: Cmd+Shift+F
        self.hotkeyKeyCode = UInt32(defaults.integer(forKey: "hotkeyKeyCode")).nonZero ?? UInt32(kVK_ANSI_F)
        self.hotkeyModifiers = UInt32(defaults.integer(forKey: "hotkeyModifiers")).nonZero ?? UInt32(cmdKey | shiftKey)

        // Magnifier hotkey - Default: Cmd+Shift+M
        self.magnifierHotkeyKeyCode = UInt32(defaults.integer(forKey: "magnifierHotkeyKeyCode")).nonZero ?? UInt32(kVK_ANSI_M)
        self.magnifierHotkeyModifiers = UInt32(defaults.integer(forKey: "magnifierHotkeyModifiers")).nonZero ?? UInt32(cmdKey | shiftKey)

        // Behavior
        self.highlightDuration = defaults.double(forKey: "highlightDuration").nonZero ?? 5.0
        self.autoHighlightOnShake = defaults.object(forKey: "autoHighlightOnShake") as? Bool ?? true
        self.shakeSensitivity = defaults.object(forKey: "shakeSensitivity") as? Double ?? 0.7

        // General - sync with actual system state for launch at login
        // Enable by default on first launch
        let isFirstLaunch = !defaults.bool(forKey: "hasLaunchedBefore")
        if isFirstLaunch {
            defaults.set(true, forKey: "hasLaunchedBefore")
            LaunchAtLoginManager.setEnabled(true)
            self.launchAtLogin = true
        } else {
            self.launchAtLogin = LaunchAtLoginManager.isEnabled
        }
        self.showInDock = defaults.bool(forKey: "showInDock")
        self.enabled = defaults.object(forKey: "enabled") as? Bool ?? true
    }

    // MARK: - Persistence

    private func save() {
        let defaults = UserDefaults.standard

        if let data = try? JSONEncoder().encode(cursorStyle) {
            defaults.set(data, forKey: "cursorStyle")
        }
        if let data = try? JSONEncoder().encode(animationStyle) {
            defaults.set(data, forKey: "animationStyle")
        }
        if let data = try? JSONEncoder().encode(movementStyle) {
            defaults.set(data, forKey: "movementStyle")
        }

        defaults.set(magnifierEnabled, forKey: "magnifierEnabled")
        defaults.set(magnifierZoom, forKey: "magnifierZoom")
        defaults.set(magnifierSize, forKey: "magnifierSize")
        defaults.set(magnifierHighQuality, forKey: "magnifierHighQuality")

        defaults.set(hotkeyKeyCode, forKey: "hotkeyKeyCode")
        defaults.set(hotkeyModifiers, forKey: "hotkeyModifiers")
        defaults.set(magnifierHotkeyKeyCode, forKey: "magnifierHotkeyKeyCode")
        defaults.set(magnifierHotkeyModifiers, forKey: "magnifierHotkeyModifiers")

        defaults.set(highlightDuration, forKey: "highlightDuration")
        defaults.set(autoHighlightOnShake, forKey: "autoHighlightOnShake")
        defaults.set(shakeSensitivity, forKey: "shakeSensitivity")

        defaults.set(launchAtLogin, forKey: "launchAtLogin")
        defaults.set(showInDock, forKey: "showInDock")
        defaults.set(enabled, forKey: "enabled")
    }

    // MARK: - Hotkey Description

    var hotkeyDescription: String {
        var parts: [String] = []
        let mods = hotkeyModifiers
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append(keyCodeToString(hotkeyKeyCode))
        return parts.joined()
    }

    private func keyCodeToString(_ keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_Space: return "Space"
        default: return "?"
        }
    }
}

// MARK: - Extensions

private extension Double {
    var nonZero: Double? {
        self != 0 ? self : nil
    }
}

private extension UInt32 {
    var nonZero: UInt32? {
        self != 0 ? self : nil
    }
}
