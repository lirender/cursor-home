import SwiftUI
import AppKit

struct AppearanceSettingsView: View {
    @State private var preferences = UserPreferences.shared

    var body: some View {
        Form {
            Section("Shape") {
                Picker("Highlight Shape", selection: $preferences.cursorStyle.shape) {
                    ForEach(HighlightShape.allCases, id: \.self) { shape in
                        Label(shape.displayName, systemImage: shape.iconName)
                            .tag(shape)
                    }
                }
                .pickerStyle(.segmented)

                HStack {
                    Text("Size")
                    Slider(value: $preferences.cursorStyle.size, in: 20...200, step: 5)
                    Text("\(Int(preferences.cursorStyle.size))px")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                }
            }

            Section("Color") {
                ColorPicker("Highlight Color", selection: highlightColor)

                HStack {
                    Text("Opacity")
                    Slider(value: $preferences.cursorStyle.opacity, in: 0.1...1.0, step: 0.05)
                    Text("\(Int(preferences.cursorStyle.opacity * 100))%")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                }
            }

            Section("Border") {
                HStack {
                    Text("Weight")
                    Slider(value: $preferences.cursorStyle.borderWeight, in: 1...10, step: 0.5)
                    Text("\(String(format: "%.1f", preferences.cursorStyle.borderWeight))px")
                        .monospacedDigit()
                        .frame(width: 45, alignment: .trailing)
                }

                Picker("Style", selection: $preferences.cursorStyle.borderStyle) {
                    ForEach(BorderStyle.allCases, id: \.self) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .pickerStyle(.segmented)

                Toggle("Glow Effect", isOn: $preferences.cursorStyle.glowEnabled)

                if preferences.cursorStyle.glowEnabled {
                    HStack {
                        Text("Glow Intensity")
                        Slider(value: $preferences.cursorStyle.glowIntensity, in: 0.1...1.0, step: 0.05)
                        Text("\(Int(preferences.cursorStyle.glowIntensity * 100))%")
                            .monospacedDigit()
                            .frame(width: 45, alignment: .trailing)
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
                        preferences.cursorStyle = .default
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var highlightColor: Binding<Color> {
        Binding(
            get: { preferences.cursorStyle.color.color },
            set: { newColor in
                preferences.cursorStyle.color = CodableColor(NSColor(newColor))
            }
        )
    }
}
