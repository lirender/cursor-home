import SwiftUI
import Carbon.HIToolbox

struct ShortcutSettingsView: View {
    @State private var preferences = UserPreferences.shared
    @State private var isRecordingFindCursor = false
    @State private var isRecordingMagnifier = false

    var body: some View {
        Form {
            Section("Find Cursor Shortcut") {
                HStack {
                    Text("Current Shortcut")
                    Spacer()
                    ShortcutRecorderView(
                        keyCode: $preferences.hotkeyKeyCode,
                        modifiers: $preferences.hotkeyModifiers,
                        isRecording: $isRecordingFindCursor
                    )
                }

                Text("Press this shortcut to find and center your cursor on the main display.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Hold Option while pressing the shortcut to only highlight without centering.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Magnifier Shortcut") {
                HStack {
                    Text("Current Shortcut")
                    Spacer()
                    ShortcutRecorderView(
                        keyCode: $preferences.magnifierHotkeyKeyCode,
                        modifiers: $preferences.magnifierHotkeyModifiers,
                        isRecording: $isRecordingMagnifier
                    )
                }
                .disabled(!preferences.magnifierEnabled)

                Text("Press this shortcut to toggle the magnifier.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Accessibility") {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Accessibility Permission")
                        Text(HotkeyManager.hasAccessibilityPermission ?
                             "Granted" : "Required for global shortcuts")
                            .font(.caption)
                            .foregroundStyle(HotkeyManager.hasAccessibilityPermission ? .green : .orange)
                    }
                    Spacer()
                    if !HotkeyManager.hasAccessibilityPermission {
                        Button("Grant Access") {
                            HotkeyManager.requestAccessibilityPermission()
                        }
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }

            Section {
                Button("Reset to Defaults") {
                    preferences.hotkeyKeyCode = UInt32(kVK_ANSI_F)
                    preferences.hotkeyModifiers = UInt32(cmdKey | shiftKey)
                    preferences.magnifierHotkeyKeyCode = UInt32(kVK_ANSI_M)
                    preferences.magnifierHotkeyModifiers = UInt32(cmdKey | shiftKey)
                    HotkeyManager.shared.updateHotkeys()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onChange(of: preferences.hotkeyKeyCode) { _, _ in
            HotkeyManager.shared.updateHotkeys()
        }
        .onChange(of: preferences.hotkeyModifiers) { _, _ in
            HotkeyManager.shared.updateHotkeys()
        }
        .onChange(of: preferences.magnifierHotkeyKeyCode) { _, _ in
            HotkeyManager.shared.updateHotkeys()
        }
        .onChange(of: preferences.magnifierHotkeyModifiers) { _, _ in
            HotkeyManager.shared.updateHotkeys()
        }
    }
}

// MARK: - Shortcut Recorder View

struct ShortcutRecorderView: View {
    @Binding var keyCode: UInt32
    @Binding var modifiers: UInt32
    @Binding var isRecording: Bool

    @FocusState private var isFocused: Bool

    var body: some View {
        Button(action: { isRecording.toggle() }) {
            Text(isRecording ? "Press keys..." : shortcutDescription)
                .frame(minWidth: 100)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
        }
        .buttonStyle(.bordered)
        .focusable()
        .focused($isFocused)
        .onKeyPress { keyPress in
            guard isRecording else { return .ignored }

            // Convert SwiftUI key to Carbon key code
            if let carbonKeyCode = carbonKeyCode(from: keyPress.key) {
                keyCode = UInt32(carbonKeyCode)
                modifiers = carbonModifiers(from: keyPress.modifiers)
                isRecording = false
                return .handled
            }
            return .ignored
        }
        .onChange(of: isRecording) { _, newValue in
            isFocused = newValue
        }
    }

    private var shortcutDescription: String {
        var parts: [String] = []
        if modifiers & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if modifiers & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if modifiers & UInt32(optionKey) != 0 { parts.append("⌥") }
        if modifiers & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append(keyCodeToString(keyCode))
        return parts.joined()
    }

    private func carbonModifiers(from swiftUIModifiers: SwiftUI.EventModifiers) -> UInt32 {
        var result: UInt32 = 0
        if swiftUIModifiers.contains(.command) { result |= UInt32(cmdKey) }
        if swiftUIModifiers.contains(.shift) { result |= UInt32(shiftKey) }
        if swiftUIModifiers.contains(.option) { result |= UInt32(optionKey) }
        if swiftUIModifiers.contains(.control) { result |= UInt32(controlKey) }
        return result
    }

    private func carbonKeyCode(from key: KeyEquivalent) -> Int? {
        let keyChar = String(key.character).uppercased()
        switch keyChar {
        case "A": return kVK_ANSI_A
        case "B": return kVK_ANSI_B
        case "C": return kVK_ANSI_C
        case "D": return kVK_ANSI_D
        case "E": return kVK_ANSI_E
        case "F": return kVK_ANSI_F
        case "G": return kVK_ANSI_G
        case "H": return kVK_ANSI_H
        case "I": return kVK_ANSI_I
        case "J": return kVK_ANSI_J
        case "K": return kVK_ANSI_K
        case "L": return kVK_ANSI_L
        case "M": return kVK_ANSI_M
        case "N": return kVK_ANSI_N
        case "O": return kVK_ANSI_O
        case "P": return kVK_ANSI_P
        case "Q": return kVK_ANSI_Q
        case "R": return kVK_ANSI_R
        case "S": return kVK_ANSI_S
        case "T": return kVK_ANSI_T
        case "U": return kVK_ANSI_U
        case "V": return kVK_ANSI_V
        case "W": return kVK_ANSI_W
        case "X": return kVK_ANSI_X
        case "Y": return kVK_ANSI_Y
        case "Z": return kVK_ANSI_Z
        case " ": return kVK_Space
        default: return nil
        }
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
