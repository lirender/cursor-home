# CursorHome

A cross-platform cursor highlighting utility for macOS and Linux (Wayland).

## Project Overview

CursorHome helps you locate your cursor when working with large screens, multiple displays, or multi-machine setups with Synergy. It provides visual highlighting, smooth animations, shake detection, and cross-machine cursor tracking.

## Core Features

### Cursor Highlighting
- **Shape options**: Circle, ring, crosshair, spotlight
- **Size**: Adjustable diameter (20px - 200px)
- **Colors**: Full color picker with opacity control
- **Border**: Weight (1-10px), style (solid, dashed, dotted), glow effect

### Animations
- Pulse, ripple, fade, and scale effects
- Configurable duration and easing
- Smooth 60fps rendering

### Shake Detection
- Find cursor by shaking the mouse
- Adjustable sensitivity (works on both platforms)

### Synergy 3 Integration
- Monitors Synergy log files for cursor transitions
- Automatic highlighting when cursor enters from remote machine
- Cross-platform communication protocol

## Tech Stack

### macOS
- **Language**: Swift 5.9+
- **UI Framework**: SwiftUI + AppKit
- **Minimum macOS**: 14.0 (Sonoma)
- **Dependencies**: HotKey (SPM)

### Linux
- **Language**: Rust 2021 edition
- **UI Framework**: GTK4 + Libadwaita
- **Display**: Wayland (via smithay-client-toolkit)
- **Dependencies**: See `platforms/linux/Cargo.toml`

## Project Structure

```
CursorHome/
├── platforms/
│   ├── macos/                          # macOS application (Swift)
│   │   ├── Package.swift
│   │   ├── Sources/CursorHome/
│   │   │   ├── App/
│   │   │   │   ├── CursorHomeApp.swift
│   │   │   │   ├── AppDelegate.swift
│   │   │   │   └── StatusBarController.swift
│   │   │   ├── Features/
│   │   │   │   ├── CursorFinder/
│   │   │   │   ├── Magnifier/
│   │   │   │   └── Settings/
│   │   │   ├── Models/
│   │   │   │   ├── CursorStyle.swift
│   │   │   │   ├── AnimationStyle.swift
│   │   │   │   └── UserPreferences.swift
│   │   │   ├── Services/
│   │   │   │   ├── CursorFinderService.swift
│   │   │   │   ├── SynergyMonitor.swift      # Synergy integration
│   │   │   │   ├── DisplayManager.swift
│   │   │   │   ├── HotkeyManager.swift
│   │   │   │   └── LaunchAtLoginManager.swift
│   │   │   └── Resources/
│   │   └── README.md
│   │
│   └── linux/                          # Linux application (Rust + GTK4)
│       ├── Cargo.toml
│       ├── src/
│       │   ├── main.rs
│       │   ├── app.rs
│       │   ├── models/
│       │   │   ├── cursor_style.rs
│       │   │   └── preferences.rs
│       │   ├── services/
│       │   │   ├── cursor_finder.rs
│       │   │   ├── synergy_monitor.rs        # Synergy integration
│       │   │   ├── display_manager.rs
│       │   │   └── shake_detector.rs
│       │   └── ui/
│       │       ├── highlight_overlay.rs
│       │       ├── settings_window.rs
│       │       └── tray_icon.rs
│       └── README.md
│
├── shared/                             # Cross-platform definitions
│   ├── protocol/
│   │   ├── messages.json               # Message schema definitions
│   │   └── README.md                   # Protocol documentation
│   └── models/
│       ├── cursor_style.json
│       └── animation_style.json
│
├── CLAUDE.md                           # This file
└── README.md                           # Project overview
```

## Build & Run

### macOS

```bash
cd platforms/macos
swift build
swift run CursorHome
```

For release builds:
```bash
swift build -c release
```

### Linux

```bash
cd platforms/linux
cargo build
cargo run
```

For release builds:
```bash
cargo build --release
```

## Key Implementation Details

### macOS Cursor Detection
```swift
// Get current cursor position across all displays
let cursorLocation = NSEvent.mouseLocation

// Find which screen contains the cursor
let currentScreen = NSScreen.screens.first { screen in
    screen.frame.contains(cursorLocation)
}
```

### macOS Cursor Warping
```swift
// Warp cursor to center of main display
CGAssociateMouseAndMouseCursorPosition(0)
CGWarpMouseCursorPosition(centerCG)
// Post mouse moved event for Synergy compatibility
if let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: centerCG, mouseButton: .left) {
    moveEvent.post(tap: .cghidEventTap)
}
CGAssociateMouseAndMouseCursorPosition(1)
```

### Linux Wayland Considerations
- **No global cursor position**: Must track via pointer motion events
- **No cursor warping**: Wayland security restriction
- **Overlay windows**: Use wlr-layer-shell protocol

### Synergy Log Monitoring
Both platforms monitor Synergy 3 log files for cursor transitions:
- Log locations: `~/.local/share/synergy/`, `~/.synergy/`, `/var/log/synergy.log`
- Parse for: "leaving", "entering", "switch to", "switch from"

## Cross-Platform Protocol

Messages are defined in `shared/protocol/messages.json`:

```json
{
  "type": "cursor_transition",
  "from": "macos",
  "to": "linux",
  "position": { "x": 1920, "y": 540 },
  "timestamp": 1706825432000
}
```

## Required Permissions

### macOS
- **Accessibility**: For cursor manipulation and global hotkeys
- Add to Info.plist:
  ```xml
  <key>NSAppleEventsUsageDescription</key>
  <string>CursorHome needs accessibility permissions...</string>
  ```

### Linux
- **Wayland compositor**: wlr-layer-shell support for overlay
- **XDG Portal**: For screen capture (magnifier)

## Design Guidelines

- Menu bar/system tray app (lightweight, unobtrusive)
- Native platform styling (SwiftUI on macOS, Libadwaita on Linux)
- 60fps highlight animations
- Respect system appearance (light/dark mode)

## Development Notes

- Test on multiple display configurations
- Ensure smooth performance (target <1% CPU idle)
- Handle display connect/disconnect gracefully
- Test Synergy integration with actual multi-machine setup
- macOS: Support both Intel and Apple Silicon
- Linux: Test on GNOME, KDE, Sway, Hyprland
