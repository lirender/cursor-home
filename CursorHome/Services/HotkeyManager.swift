import AppKit
import HotKey
import Carbon.HIToolbox

@Observable
final class HotkeyManager {
    static let shared = HotkeyManager()

    private var findCursorHotKey: HotKey?
    private var magnifierHotKey: HotKey?

    var onFindCursor: (() -> Void)?
    var onMagnifierToggle: (() -> Void)?

    private init() {}

    func setup() {
        updateHotkeys()
    }

    func updateHotkeys() {
        let prefs = UserPreferences.shared

        // Clear existing hotkeys
        findCursorHotKey = nil
        magnifierHotKey = nil

        // Setup find cursor hotkey
        if let key = keyFromCode(prefs.hotkeyKeyCode) {
            let modifiers = modifiersFromCarbon(prefs.hotkeyModifiers)
            findCursorHotKey = HotKey(key: key, modifiers: modifiers)
            findCursorHotKey?.keyDownHandler = { [weak self] in
                self?.onFindCursor?()
            }
        }

        // Setup magnifier hotkey
        if prefs.magnifierEnabled, let key = keyFromCode(prefs.magnifierHotkeyKeyCode) {
            let modifiers = modifiersFromCarbon(prefs.magnifierHotkeyModifiers)
            magnifierHotKey = HotKey(key: key, modifiers: modifiers)
            magnifierHotKey?.keyDownHandler = { [weak self] in
                self?.onMagnifierToggle?()
            }
        }
    }

    private func keyFromCode(_ code: UInt32) -> Key? {
        switch Int(code) {
        case kVK_ANSI_A: return .a
        case kVK_ANSI_B: return .b
        case kVK_ANSI_C: return .c
        case kVK_ANSI_D: return .d
        case kVK_ANSI_E: return .e
        case kVK_ANSI_F: return .f
        case kVK_ANSI_G: return .g
        case kVK_ANSI_H: return .h
        case kVK_ANSI_I: return .i
        case kVK_ANSI_J: return .j
        case kVK_ANSI_K: return .k
        case kVK_ANSI_L: return .l
        case kVK_ANSI_M: return .m
        case kVK_ANSI_N: return .n
        case kVK_ANSI_O: return .o
        case kVK_ANSI_P: return .p
        case kVK_ANSI_Q: return .q
        case kVK_ANSI_R: return .r
        case kVK_ANSI_S: return .s
        case kVK_ANSI_T: return .t
        case kVK_ANSI_U: return .u
        case kVK_ANSI_V: return .v
        case kVK_ANSI_W: return .w
        case kVK_ANSI_X: return .x
        case kVK_ANSI_Y: return .y
        case kVK_ANSI_Z: return .z
        case kVK_Space: return .space
        case kVK_Return: return .return
        case kVK_Tab: return .tab
        case kVK_Escape: return .escape
        default: return nil
        }
    }

    private func modifiersFromCarbon(_ carbonMods: UInt32) -> NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if carbonMods & UInt32(cmdKey) != 0 { flags.insert(.command) }
        if carbonMods & UInt32(shiftKey) != 0 { flags.insert(.shift) }
        if carbonMods & UInt32(optionKey) != 0 { flags.insert(.option) }
        if carbonMods & UInt32(controlKey) != 0 { flags.insert(.control) }
        return flags
    }
}

// MARK: - Accessibility Check

extension HotkeyManager {
    static var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }
}
