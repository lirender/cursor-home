import AppIntents

// MARK: - Find Cursor Intent

struct FindCursorIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Cursor"
    static var description = IntentDescription("Highlights your cursor location")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            CursorFinderService.shared.findCursor()
        }
        return .result()
    }
}

// MARK: - Toggle Magnifier Intent

struct ToggleMagnifierIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle Magnifier"
    static var description = IntentDescription("Toggles the cursor magnifier on or off")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            MagnifierService.shared.toggle()
        }
        return .result()
    }
}

// MARK: - Show Magnifier Intent

struct ShowMagnifierIntent: AppIntent {
    static var title: LocalizedStringResource = "Show Magnifier"
    static var description = IntentDescription("Shows the cursor magnifier")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            MagnifierService.shared.show()
        }
        return .result()
    }
}

// MARK: - Hide Magnifier Intent

struct HideMagnifierIntent: AppIntent {
    static var title: LocalizedStringResource = "Hide Magnifier"
    static var description = IntentDescription("Hides the cursor magnifier")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            MagnifierService.shared.hide()
        }
        return .result()
    }
}

// MARK: - Toggle CursorHome Intent

struct ToggleCursorHomeIntent: AppIntent {
    static var title: LocalizedStringResource = "Toggle CursorHome"
    static var description = IntentDescription("Enables or disables CursorHome")

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            UserPreferences.shared.enabled.toggle()
        }
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct CursorHomeShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: FindCursorIntent(),
            phrases: [
                "Find my cursor with \(.applicationName)",
                "Where is my cursor \(.applicationName)",
                "Locate cursor with \(.applicationName)"
            ],
            shortTitle: "Find Cursor",
            systemImageName: "cursorarrow.rays"
        )

        AppShortcut(
            intent: ToggleMagnifierIntent(),
            phrases: [
                "Toggle magnifier with \(.applicationName)",
                "Magnify cursor with \(.applicationName)"
            ],
            shortTitle: "Toggle Magnifier",
            systemImageName: "magnifyingglass"
        )
    }
}
