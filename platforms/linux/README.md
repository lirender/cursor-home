# CursorHome - Linux (Wayland)

The Linux implementation of CursorHome, a cursor highlighting utility for Wayland compositors.

## Features

- **Cursor Highlighting**: Highlight your cursor with customizable shapes, colors, and animations
- **Shake Detection**: Find your cursor by shaking the mouse
- **Synergy 3 Integration**: Cross-machine cursor tracking with macOS
- **System Tray**: Lightweight presence in system tray
- **GTK4/Libadwaita UI**: Native GNOME-style settings interface

## Requirements

### System Dependencies

```bash
# Ubuntu/Debian
sudo apt install libgtk-4-dev libadwaita-1-dev libwayland-dev

# Fedora
sudo dnf install gtk4-devel libadwaita-devel wayland-devel

# Arch Linux
sudo pacman -S gtk4 libadwaita wayland
```

### Rust

Install Rust via [rustup](https://rustup.rs/):

```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

## Building

```bash
cd platforms/linux

# Debug build
cargo build

# Release build
cargo build --release

# Run
cargo run
```

The release binary will be at `target/release/cursorhome`.

## Installation

```bash
# Build release
cargo build --release

# Install to ~/.local/bin
cp target/release/cursorhome ~/.local/bin/

# Or system-wide
sudo cp target/release/cursorhome /usr/local/bin/
```

### Desktop Entry

Create `~/.local/share/applications/cursorhome.desktop`:

```desktop
[Desktop Entry]
Type=Application
Name=CursorHome
Comment=Cursor highlighting utility
Exec=cursorhome
Icon=find-location
Categories=Utility;Accessibility;
StartupNotify=false
Terminal=false
```

### Autostart

To start CursorHome on login, create `~/.config/autostart/cursorhome.desktop` with the same content as above.

## Wayland Limitations

Due to Wayland's security model, some features work differently than on macOS:

| Feature | Status | Notes |
|---------|--------|-------|
| Cursor highlighting | ✅ Works | Uses layer-shell protocol |
| Shake detection | ✅ Works | Via pointer motion events |
| Global cursor position | ⚠️ Limited | Only available via events |
| Cursor warping | ❌ Not supported | Wayland security restriction |
| Magnifier | ⚠️ Limited | Requires portal API permission |

### Compositor Support

The overlay window requires `wlr-layer-shell` protocol support:

- **GNOME**: Supported via extensions or Mutter layer-shell
- **KDE Plasma**: Supported natively
- **Sway/wlroots**: Fully supported
- **Hyprland**: Fully supported

## Configuration

Settings are stored in `~/.config/cursorhome/preferences.json`.

Example configuration:

```json
{
  "enabled": true,
  "cursor_style": {
    "shape": "ring",
    "size": 60.0,
    "color": { "r": 255, "g": 149, "b": 0, "a": 1.0 },
    "border_weight": 4.0,
    "glow_enabled": true
  },
  "animation_style": {
    "animation_type": "pulse",
    "duration": 0.8,
    "easing": "ease_in_out",
    "repeat_count": 3
  },
  "highlight_duration": 5.0,
  "shake_enabled": true,
  "shake_sensitivity": 0.5
}
```

## Keyboard Shortcuts

Default shortcuts (configurable):

| Shortcut | Action |
|----------|--------|
| Ctrl+Shift+F | Find cursor |
| Ctrl+, | Open settings |
| Ctrl+Q | Quit |

## Synergy 3 Integration

CursorHome monitors Synergy 3 log files for cursor transitions. When your cursor moves from the macOS machine to Linux (or vice versa), CursorHome will automatically highlight the cursor on the destination.

Synergy log file locations checked:
- `~/.local/share/synergy/synergy.log`
- `~/.synergy/synergy.log`
- `/var/log/synergy.log`

## Troubleshooting

### Highlight doesn't appear

1. Check if your compositor supports `wlr-layer-shell`:
   ```bash
   wayland-info | grep layer_shell
   ```

2. On GNOME, you may need an extension for layer-shell support.

### Shake detection not working

Ensure CursorHome has access to pointer events. On some compositors, this requires the window to be focused.

### Permission denied for screen capture (magnifier)

The magnifier uses the XDG Desktop Portal. Grant permission when prompted, or check:
```bash
flatpak permission-show
```

## Project Structure

```
src/
├── main.rs              # Entry point
├── app.rs               # Application lifecycle
├── models/
│   ├── cursor_style.rs  # Style definitions
│   └── preferences.rs   # Settings storage
├── services/
│   ├── cursor_finder.rs # Cursor highlighting
│   ├── display_manager.rs # Wayland display handling
│   ├── shake_detector.rs  # Mouse shake detection
│   └── synergy_monitor.rs # Synergy 3 integration
└── ui/
    ├── highlight_overlay.rs # Overlay window
    ├── settings_window.rs   # Settings UI
    └── tray_icon.rs         # System tray
```

## License

MIT License
