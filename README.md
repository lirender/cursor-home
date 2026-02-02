# CursorHome

A cross-platform cursor highlighting utility that helps you locate your cursor across multiple displays and machines.

## Overview

CursorHome solves the common problem of losing track of your cursor when working with large screens, multiple displays, or multi-machine setups with Synergy. It provides:

- Visual cursor highlighting with customizable shapes and animations
- Shake-to-find gesture detection
- Cross-machine cursor tracking via Synergy 3 integration
- Native implementations for macOS and Linux (Wayland)

## Platforms

| Platform | Technology | Status |
|----------|------------|--------|
| [macOS](platforms/macos/) | Swift, SwiftUI, AppKit | ✅ Ready |
| [Linux (Wayland)](platforms/linux/) | Rust, GTK4, Libadwaita | ✅ Ready |

## Features

### Cursor Highlighting
- **Shapes**: Circle, ring, crosshair, spotlight
- **Size**: Adjustable diameter (20px - 200px)
- **Colors**: Full color picker with opacity control
- **Border**: Weight, style (solid, dashed, dotted), glow effect

### Animations
- Pulse, ripple, fade, and scale effects
- Configurable duration and easing
- Smooth 60fps rendering

### Shake Detection
- Find your cursor by shaking the mouse
- Adjustable sensitivity

### Synergy 3 Integration
- Automatic cursor highlighting when transitioning between machines
- Cross-platform communication protocol
- Works seamlessly with Synergy 3 setups

## Project Structure

```
CursorHome/
├── platforms/
│   ├── macos/          # macOS application (Swift)
│   │   ├── Package.swift
│   │   ├── Sources/CursorHome/
│   │   └── README.md
│   │
│   └── linux/          # Linux application (Rust + GTK4)
│       ├── Cargo.toml
│       ├── src/
│       └── README.md
│
├── shared/             # Cross-platform definitions
│   ├── protocol/       # Communication protocol schemas
│   │   ├── messages.json
│   │   └── README.md
│   └── models/         # Shared data model schemas
│       ├── cursor_style.json
│       └── animation_style.json
│
├── CLAUDE.md           # Development instructions
└── README.md           # This file
```

## Quick Start

### macOS

```bash
cd platforms/macos
swift build
swift run CursorHome
```

Requirements: macOS 14.0+, Xcode Command Line Tools

### Linux (Wayland)

```bash
cd platforms/linux
cargo build
cargo run
```

Requirements: GTK4, Libadwaita, Wayland development libraries

See platform-specific READMEs for detailed installation instructions.

## Synergy Setup

For cross-machine cursor tracking:

1. Install and configure [Synergy 3](https://symless.com/synergy)
2. Run CursorHome on both machines
3. Cursor highlighting will automatically trigger when moving between machines

## Default Keyboard Shortcuts

### macOS
| Shortcut | Action |
|----------|--------|
| ⌘⇧F | Find and center cursor |
| ⌥⌘⇧F | Highlight cursor only |
| ⌘⇧M | Toggle magnifier |

### Linux
| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+F | Find cursor |
| Ctrl+, | Open settings |
| Ctrl+Q | Quit |

## Use Cases

- **Multiple Displays**: Quickly locate cursor across 2+ monitors
- **Synergy/KVM Users**: Find cursor after switching machines
- **Screen Sharing**: Make cursor visible to viewers
- **Presentations**: Highlight cursor for audiences
- **Accessibility**: Help track cursor movement

## Development

See [CLAUDE.md](CLAUDE.md) for detailed development instructions.

### Building Both Platforms

```bash
# macOS
cd platforms/macos && swift build

# Linux
cd platforms/linux && cargo build
```

### Running Tests

```bash
# macOS
cd platforms/macos && swift test

# Linux
cd platforms/linux && cargo test
```

## Protocol Documentation

The cross-platform communication protocol is documented in [shared/protocol/README.md](shared/protocol/README.md). Key message types:

- `cursor_transition`: Cursor moved between machines
- `highlight_request`: Request highlight on a specific machine
- `settings_sync`: Synchronize visual settings

## License

MIT License

## Contributing

Contributions are welcome! Please see the platform-specific READMEs for development setup instructions.
