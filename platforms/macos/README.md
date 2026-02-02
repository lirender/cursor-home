# CursorHome - macOS

The macOS implementation of CursorHome, a lightweight menu bar app that helps you locate and center your cursor across multiple displays.

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permission (for cursor control and global hotkeys)

## Building

```bash
cd platforms/macos

# Build
swift build

# Run
swift run CursorHome

# Build release
swift build -c release
```

## Features

- **Find Cursor**: Instantly locate and highlight your cursor position
- **Center on Main Display**: Smoothly animate cursor to the center of your main screen
- **Customizable Appearance**: Shape, size, color, border, and glow effects
- **Animations**: Pulse, ripple, fade, and scale effects
- **Magnifier**: Zoom in around your cursor location
- **Global Hotkey**: Customizable keyboard shortcut (default: ⌘⇧F)
- **Shake Detection**: Find cursor by shaking the mouse
- **Apple Shortcuts**: Siri and Shortcuts.app integration
- **Synergy 3 Integration**: Cursor tracking across networked displays

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧F | Find and center cursor |
| ⌥⌘⇧F | Highlight cursor only |
| ⌘⇧M | Toggle magnifier |

## Synergy 3 Integration

When Synergy 3 is installed, CursorHome monitors cursor transitions between machines. This enables:

- Automatic cursor highlighting when entering from another display
- Coordinated highlighting with the Linux client
- Cross-machine "find my cursor" functionality

## Project Structure

```
Sources/CursorHome/
├── App/
│   ├── CursorHomeApp.swift        # Main app entry point
│   ├── AppDelegate.swift          # Menu bar setup, global shortcuts
│   └── StatusBarController.swift  # Menu bar icon and menu
├── Features/
│   ├── CursorFinder/
│   │   └── HighlightWindow.swift  # Overlay window for highlighting
│   ├── Magnifier/
│   │   └── MagnifierService.swift
│   └── Settings/
│       └── *.swift                # Settings UI views
├── Models/
│   ├── CursorStyle.swift          # Shape, size, color, border config
│   ├── AnimationStyle.swift       # Animation type and timing
│   └── UserPreferences.swift      # All user settings
├── Services/
│   ├── CursorFinderService.swift  # Core cursor location/movement
│   ├── DisplayManager.swift       # Multi-display handling
│   ├── HotkeyManager.swift        # Global keyboard shortcuts
│   ├── ShortcutsIntegration.swift # Apple Shortcuts support
│   ├── LaunchAtLoginManager.swift # Autostart functionality
│   └── SynergyMonitor.swift       # Synergy 3 integration
└── Resources/
    └── Assets.xcassets/
```
