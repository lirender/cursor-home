import SwiftUI
import AppKit

struct GeneralSettingsView: View {
    @State private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section("Behavior") {
                HStack {
                    Text("Highlight Duration")
                    Slider(value: $preferences.highlightDuration, in: 1...30, step: 1)
                    Text("\(Int(preferences.highlightDuration))s")
                        .monospacedDigit()
                        .frame(width: 30, alignment: .trailing)
                }

                Toggle("Auto-highlight on mouse shake", isOn: $preferences.autoHighlightOnShake)
                    .onChange(of: preferences.autoHighlightOnShake) { _, _ in
                        CursorFinderService.shared.updateShakeDetection()
                    }

                Text("Automatically highlight the cursor when you shake the mouse rapidly.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch at Login", isOn: $preferences.launchAtLogin)
                    .onChange(of: preferences.launchAtLogin) { _, newValue in
                        LaunchAtLoginManager.setEnabled(newValue)
                    }

                Toggle("Show in Dock", isOn: $preferences.showInDock)
                    .onChange(of: preferences.showInDock) { _, newValue in
                        NSApp.setActivationPolicy(newValue ? .regular : .accessory)
                    }

                Text("When hidden from Dock, CursorHome runs as a menu bar app only.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Quick Toggle") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Option-click the menu bar icon to quickly enable or disable CursorHome.")
                        .font(.callout)

                    HStack {
                        Circle()
                            .fill(preferences.enabled ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(preferences.enabled ? "Currently Enabled" : "Currently Disabled")
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Build")
                    Spacer()
                    Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1")
                        .foregroundStyle(.secondary)
                }

                Link("View on GitHub", destination: URL(string: "https://github.com")!)
            }

            Section {
                Button("Reset All Settings", role: .destructive) {
                    resetAllSettings()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private func resetAllSettings() {
        preferences.cursorStyle = .default
        preferences.animationStyle = .default
        preferences.highlightDuration = 5.0
        preferences.autoHighlightOnShake = true
        preferences.magnifierEnabled = false
        preferences.magnifierZoom = 2.0
        preferences.magnifierSize = 150.0
        preferences.magnifierHighQuality = true
        preferences.enabled = true
        HotkeyManager.shared.updateHotkeys()
        CursorFinderService.shared.updateShakeDetection()
    }
}
