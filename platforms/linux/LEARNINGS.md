# CursorHome Linux - Implementation Learnings

## Platform Discovery

The target Ubuntu system runs **X11** (not Wayland as initially assumed):
```
loginctl show-session ... -p Type
Type=x11
```

This significantly simplifies cursor tracking but changes our approach.

## X11 ARGB Overlay - WORKING

Successfully implemented transparent overlay using X11's 32-bit ARGB visual:

```rust
use x11rb::protocol::render::{ConnectionExt as RenderConnectionExt, PictType};

fn find_argb_visual(conn: &RustConnection, screen_num: usize) -> Result<(Visualid, u8)> {
    let formats = conn.render_query_pict_formats()?.reply()?;

    for format in &formats.formats {
        if format.depth == 32 && format.type_ == PictType::DIRECT {
            if format.direct.alpha_mask > 0 {
                // Find visual using this format...
            }
        }
    }
}
```

Key settings for transparent overlay:
- `background_pixel(0)` - Transparent background
- `override_redirect(1)` - No window manager decoration
- Use shape extension to make click-through: `shape_rectangles(SO::SET, SK::INPUT, ...)`

## X11 Cursor Position Tracking - WORKING

```rust
fn get_cursor_position(&self) -> Result<(i16, i16)> {
    let screen = &self.conn.setup().roots[self.screen_num];
    self.conn.query_pointer(screen.root)?
        .reply()
        .map(|r| (r.root_x, r.root_y))
}
```

## Synergy 3 Integration - WORKING

Monitors Synergy log file for cursor transitions:
- **Log location**: `~/.var/app/com.symless.synergy/.local/state/Synergy/synergy.log` (Flatpak)
- **Events detected**:
  - "entering", "switch from", "switching from" → CursorReturned
  - "leaving", "switch to", "switching to" → CursorLeft
- Uses `notify` crate for file watching
- Uses `glib::MainContext::channel` for thread-safe GTK communication

## Current Status

### Working
- X11 ARGB transparent overlay
- Cursor position tracking (follows mouse)
- Synergy transition detection triggers highlight
- Click-through overlay (can interact with apps behind it)
- Animation loop at 60fps

### Not Working / TODO
- **Ubuntu shake detection**: ShakeDetector stub exists but doesn't track mouse
- **macOS shake detection broken**: Recent fix to skip non-local cursor broke shake entirely

## macOS Shake Detection Issue

The fix to prevent Mac highlight when cursor is on Ubuntu was too aggressive:
```swift
// This check is probably too strict
let isOnLocalScreen = NSScreen.screens.contains { $0.frame.contains(currentLocation) }
if !isOnLocalScreen {
    previousLocations.removeAll()
    return
}
```

The issue might be that `NSEvent.mouseLocation` returns coordinates that don't perfectly match `NSScreen.frame` bounds, especially near edges or with Synergy active.

**Possible fixes:**
1. Add small tolerance to screen bounds check
2. Only skip if cursor is CLEARLY outside all screens (by significant margin)
3. Use a different method to detect if Synergy has control

## Display Configuration

Ubuntu display is portrait mode:
- Resolution: 2160x3840
- Center: (1080, 1920)
- Connected via HDMI-0

## Dependencies

```toml
x11rb = { version = "0.13", features = ["allow-unsafe-code", "render", "shape"] }
gtk4 = "0.7"
libadwaita = "0.5"
notify = "6"        # File watching
regex = "1"         # Log parsing
```

## Environment Variables

```bash
DISPLAY=:1 RUST_LOG=info ./target/debug/cursorhome
```

## Next Steps

1. **Fix macOS shake detection** - Add tolerance to screen bounds check
2. **Implement Ubuntu shake detection** - Add X11 mouse polling loop
3. **Test animation styles** - Currently only simple circle, verify pulse/fade/etc work
