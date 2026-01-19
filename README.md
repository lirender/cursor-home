# CursorHome

A lightweight macOS menu bar app that helps you locate and center your cursor across multiple displays.

## Features

- **Find Cursor**: Instantly locate and highlight your cursor position
- **Center on Main Display**: Smoothly animate cursor to the center of your main screen
- **Customizable Appearance**: Shape, size, color, border, and glow effects
- **Animations**: Pulse, ripple, fade, and scale effects
- **Magnifier**: Zoom in around your cursor location
- **Global Hotkey**: Customizable keyboard shortcut (default: ⌘⇧F)
- **Apple Shortcuts**: Siri and Shortcuts.app integration
- **Menu Bar App**: Lightweight, always accessible
- **Quick Toggle**: Option-click menu bar icon to enable/disable

## Requirements

- macOS 14.0 (Sonoma) or later
- Accessibility permission (for cursor control and global hotkeys)

## Building

### Using Swift Package Manager

```bash
# Clone the repository
cd CursorHome

# Build the project
swift build

# Run
swift run CursorHome
```

### Using Xcode

1. Open the folder in Xcode: `File > Open > CursorHome folder`
2. Or generate an Xcode project: `swift package generate-xcodeproj`
3. Build and run (⌘R)

## Usage

1. **Launch the app** - CursorHome appears in your menu bar
2. **Grant Accessibility permission** when prompted
3. **Press ⌘⇧F** to find and center your cursor
4. **Hold Option + ⌘⇧F** to highlight without centering
5. **Right-click** the menu bar icon for options
6. **Option-click** the menu bar icon to quickly enable/disable

## Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| ⌘⇧F | Find and center cursor |
| ⌥⌘⇧F | Highlight cursor only |
| ⌘⇧M | Toggle magnifier |

## Settings

Access settings by right-clicking the menu bar icon and selecting "Settings...":

- **Appearance**: Shape, size, color, border, glow
- **Animation**: Type, duration, easing, repeat count
- **Magnifier**: Zoom, size, quality
- **Shortcuts**: Customize hotkeys
- **General**: Launch at login, show in dock

## Use Cases

- Working with multiple displays
- Screen sharing and presentations
- Video tutorials and lectures
- Video calls and meetings
- Accessibility assistance

## License

MIT License
