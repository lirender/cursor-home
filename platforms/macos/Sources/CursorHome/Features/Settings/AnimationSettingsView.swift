import SwiftUI

struct AnimationSettingsView: View {
    @State private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section("Highlight Animation") {
                Picker("Type", selection: $preferences.animationStyle.type) {
                    ForEach(AnimationType.allCases, id: \.self) { type in
                        Label(type.displayName, systemImage: type.iconName)
                            .tag(type)
                    }
                }

                if preferences.animationStyle.type != .none {
                    HStack {
                        Text("Duration")
                        Slider(value: $preferences.animationStyle.duration, in: 0.1...2.0, step: 0.1)
                        Text("\(String(format: "%.1f", preferences.animationStyle.duration))s")
                            .monospacedDigit()
                            .frame(width: 40, alignment: .trailing)
                    }

                    Picker("Easing", selection: $preferences.animationStyle.easing) {
                        ForEach(EasingType.allCases, id: \.self) { easing in
                            Text(easing.displayName).tag(easing)
                        }
                    }

                    Stepper("Repeat: \(preferences.animationStyle.repeatCount)x",
                            value: $preferences.animationStyle.repeatCount,
                            in: 1...5)
                }
            }

            Section("Cursor Movement") {
                Toggle("Animate cursor to center", isOn: $preferences.movementStyle.animated)

                if preferences.movementStyle.animated {
                    HStack {
                        Text("Duration")
                        Slider(value: $preferences.movementStyle.duration, in: 0.1...1.0, step: 0.05)
                        Text("\(String(format: "%.2f", preferences.movementStyle.duration))s")
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
                    }

                    Picker("Easing", selection: $preferences.movementStyle.easing) {
                        ForEach(EasingType.allCases, id: \.self) { easing in
                            Text(easing.displayName).tag(easing)
                        }
                    }
                }
            }

            Section {
                HStack {
                    Spacer()
                    Button("Preview") {
                        CursorFinderService.shared.findCursor()
                    }
                    Button("Reset to Defaults") {
                        preferences.animationStyle = .default
                        preferences.movementStyle = .default
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
