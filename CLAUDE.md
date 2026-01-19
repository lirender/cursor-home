# CursorHome

A lightweight macOS menu bar app that helps you locate and center your cursor across multiple displays.

## Project Overview

CursorHome solves the common problem of losing track of your cursor when working with large screens or multiple displays. It provides visual highlighting, smooth animations, and a "find my cursor" feature that moves the pointer to the center of your main display.

## Core Features

### Cursor Highlighting
- **Shape options**: Circle, ring, crosshair, spotlight
- **Size**: Adjustable diameter (20px - 200px)
- **Colors**: Full color picker with opacity control
- **Border**: Weight (1-10px), style (solid, dashed, dotted), glow effect

### Animations
- Pulse animation when cursor is found
- Smooth easing when moving cursor to center
- Click ripple effects
- Semantic animations that indicate current interaction state

### Magnifier
- Configurable hotkey activation
- Zoom factor: 1.5x - 10x
- Quality settings (performance vs quality)
- Adjustable magnifier size

### System Integration
- Menu bar app (lightweight, unobtrusive)
- Autostart on login
- Customizable global keyboard shortcut
- Apple Shortcuts.app support
- Quick-toggle: Option-click menu bar icon to enable/disable

## Tech Stack

- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI + AppKit (for system integration)
- **Minimum macOS**: 14.0 (Sonoma)
- **Architecture**: Menu bar app with settings window

## Project Structure

```
CursorHome/
├── CursorHome.xcodeproj/
├── CursorHome/
│   ├── App/
│   │   ├── CursorHomeApp.swift        # Main app entry point
│   │   ├── AppDelegate.swift          # Menu bar setup, global shortcuts
│   │   └── StatusBarController.swift  # Menu bar icon and menu
│   ├── Features/
│   │   ├── CursorFinder/
│   │   │   ├── CursorFinderService.swift    # Core cursor location/movement
│   │   │   ├── CursorHighlightView.swift    # Overlay window for highlighting
│   │   │   └── AnimationController.swift    # Animation management
│   │   ├── Magnifier/
│   │   │   ├── MagnifierService.swift
│   │   │   └── MagnifierView.swift
│   │   └── Settings/
│   │       ├── SettingsView.swift
│   │       ├── AppearanceSettings.swift
│   │       ├── ShortcutSettings.swift
│   │       └── GeneralSettings.swift
│   ├── Models/
│   │   ├── CursorStyle.swift          # Shape, size, color, border config
│   │   ├── AnimationStyle.swift       # Animation type and timing
│   │   └── UserPreferences.swift      # All user settings
│   ├── Services/
│   │   ├── DisplayManager.swift       # Multi-display handling
│   │   ├── HotkeyManager.swift        # Global keyboard shortcuts
│   │   ├── ShortcutsIntegration.swift # Apple Shortcuts support
│   │   └── LaunchAtLoginManager.swift # Autostart functionality
│   ├── Utilities/
│   │   ├── CGPointExtensions.swift
│   │   ├── NSScreenExtensions.swift
│   │   └── AnimationUtils.swift
│   └── Resources/
│       ├── Assets.xcassets/
│       └── Localizable.strings
├── CursorHomeTests/
└── README.md
```

## Key Implementation Details

### Multi-Display Cursor Detection
```swift
// Get current cursor position across all displays
let cursorLocation = NSEvent.mouseLocation

// Find which screen contains the cursor
let currentScreen = NSScreen.screens.first { screen in
    screen.frame.contains(cursorLocation)
}
```

### Smooth Cursor Movement
```swift
// Use CGWarpMouseCursorPosition for instant move
// Or animate with CGDisplayMoveCursorToPoint for smooth transition
func moveCursorToCenter(of screen: NSScreen, animated: Bool) {
    let center = CGPoint(
        x: screen.frame.midX,
        y: screen.frame.midY
    )
    if animated {
        animateCursorTo(center, duration: 0.3, easing: .easeInOut)
    } else {
        CGWarpMouseCursorPosition(center)
    }
}
```

### Overlay Window for Highlighting
- Use `NSWindow` with `.borderless` style
- Set `level` to `.screenSaver` to appear above all content
- `ignoresMouseEvents = true` to allow click-through
- `backgroundColor = .clear` with `isOpaque = false`

### Global Hotkey Registration
Use `CGEvent.tapCreate` or a library like `HotKey` for global keyboard shortcuts:
```swift
// Register global hotkey (e.g., ⌘⇧F)
hotKeyManager.register(keyCombo: KeyCombo(key: .f, modifiers: [.command, .shift])) {
    cursorFinder.findAndHighlight()
}
```

## User Preferences Storage

Use `@AppStorage` with UserDefaults for persistence:
- `highlightShape`: String (circle, ring, crosshair, spotlight)
- `highlightSize`: Double
- `highlightColor`: Data (archived NSColor)
- `borderWeight`: Double
- `borderStyle`: String
- `glowEnabled`: Bool
- `glowIntensity`: Double
- `magnifierZoom`: Double
- `magnifierSize`: Double
- `hotkeyModifiers`: Int
- `hotkeyKeyCode`: Int
- `launchAtLogin`: Bool

## Apple Shortcuts Integration

Implement `AppIntents` framework:
```swift
struct FindCursorIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Cursor"
    static var description = IntentDescription("Highlights and optionally centers the cursor")

    @Parameter(title: "Center on Main Display")
    var centerOnMain: Bool

    func perform() async throws -> some IntentResult {
        await CursorFinderService.shared.findCursor(centerOnMain: centerOnMain)
        return .result()
    }
}
```

## Build & Run

```bash
# Open in Xcode
open CursorHome.xcodeproj

# Build from command line
xcodebuild -scheme CursorHome -configuration Release

# Run tests
xcodebuild test -scheme CursorHome
```

## Required Permissions

- **Accessibility**: Required for cursor manipulation and global hotkeys
- Add to Info.plist:
  ```xml
  <key>NSAppleEventsUsageDescription</key>
  <string>CursorHome needs accessibility permissions to highlight and move your cursor.</string>
  ```

## Design Guidelines

- Menu bar icon: 18x18pt template image
- Settings window: Native macOS styling, ~400x500pt
- Highlight animations: 60fps, smooth easing curves
- Respect system appearance (light/dark mode)
- Use SF Symbols where appropriate

## Use Cases

1. **Multiple displays**: Quickly locate cursor across 2-3+ monitors
2. **Screen sharing/presentations**: Make cursor visible to viewers
3. **Video tutorials**: Highlight cursor for instructional content
4. **Accessibility**: Help users with visual impairments track cursor

## Development Notes

- Test on multiple display configurations
- Ensure smooth performance (target <1% CPU during idle)
- Handle display connect/disconnect gracefully
- Support both Intel and Apple Silicon Macs
