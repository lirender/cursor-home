import SwiftUI
import Carbon.HIToolbox

struct MagnifierSettingsView: View {
    @State private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section {
                Toggle("Enable Magnifier", isOn: $preferences.magnifierEnabled)
                    .onChange(of: preferences.magnifierEnabled) { _, newValue in
                        if !newValue {
                            MagnifierService.shared.hide()
                        }
                        HotkeyManager.shared.updateHotkeys()
                    }
            }

            Section("Magnifier Settings") {
                HStack {
                    Text("Zoom Factor")
                    Slider(value: $preferences.magnifierZoom, in: 1.5...10.0, step: 0.5)
                    Text("\(String(format: "%.1f", preferences.magnifierZoom))x")
                        .monospacedDigit()
                        .frame(width: 40, alignment: .trailing)
                }

                HStack {
                    Text("Size")
                    Slider(value: $preferences.magnifierSize, in: 100...400, step: 25)
                    Text("\(Int(preferences.magnifierSize))px")
                        .monospacedDigit()
                        .frame(width: 50, alignment: .trailing)
                }

                Toggle("High Quality", isOn: $preferences.magnifierHighQuality)

                Text("Higher quality uses more system resources but provides sharper magnification.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!preferences.magnifierEnabled)

            Section("Hotkey") {
                HStack {
                    Text("Magnifier Shortcut")
                    Spacer()
                    Text(magnifierHotkeyDescription)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(6)
                }

                Text("Press the shortcut to toggle the magnifier on/off.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .disabled(!preferences.magnifierEnabled)

            Section {
                HStack {
                    Spacer()
                    Button("Test Magnifier") {
                        MagnifierService.shared.show()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            MagnifierService.shared.hide()
                        }
                    }
                    .disabled(!preferences.magnifierEnabled)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var magnifierHotkeyDescription: String {
        var parts: [String] = []
        let mods = preferences.magnifierHotkeyModifiers
        if mods & UInt32(cmdKey) != 0 { parts.append("⌘") }
        if mods & UInt32(shiftKey) != 0 { parts.append("⇧") }
        if mods & UInt32(optionKey) != 0 { parts.append("⌥") }
        if mods & UInt32(controlKey) != 0 { parts.append("⌃") }
        parts.append("M")
        return parts.joined()
    }
}
