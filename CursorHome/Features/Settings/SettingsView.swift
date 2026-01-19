import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            AppearanceSettingsView()
                .tabItem {
                    Label("Appearance", systemImage: "paintbrush")
                }

            AnimationSettingsView()
                .tabItem {
                    Label("Animation", systemImage: "wand.and.stars")
                }

            MagnifierSettingsView()
                .tabItem {
                    Label("Magnifier", systemImage: "magnifyingglass")
                }

            ShortcutSettingsView()
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            GeneralSettingsView()
                .tabItem {
                    Label("General", systemImage: "gear")
                }
        }
        .frame(width: 450, height: 350)
    }
}
