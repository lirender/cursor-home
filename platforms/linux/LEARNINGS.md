# CursorHome Linux - Implementation Learnings

## Platform Discovery

The target Ubuntu system runs **X11** (not Wayland as initially assumed):
```
loginctl show-session ... -p Type
Type=x11
```

This significantly simplifies cursor tracking but changes our approach.

## X11 Cursor Position Tracking

Successfully implemented using `x11rb` crate:

```rust
use x11rb::connection::Connection;
use x11rb::protocol::xproto::*;

fn get_x11_cursor_position() -> Option<(f64, f64)> {
    let (conn, screen_num) = x11rb::connect(None).ok()?;
    let screen = &conn.setup().roots[screen_num];
    let root = screen.root;

    query_pointer(&conn, root)
        .ok()
        .and_then(|cookie| cookie.reply().ok())
        .map(|reply| (reply.root_x as f64, reply.root_y as f64))
}
```

This provides reliable global cursor position at any time - no need for motion event tracking.

## Synergy 3 Integration

Working implementation monitors Synergy log file:
- **Log location**: `~/.var/app/com.symless.synergy/.local/state/Synergy/synergy.log` (Flatpak)
- **Events detected**:
  - "entering", "switch from", "switching from" → CursorReturned
  - "leaving", "switch to", "switching to" → CursorLeft
- Uses `notify` crate for file watching
- Uses `glib::MainContext::channel` for thread-safe GTK communication

## Current Issues

### Overlay Window Blocks Screen
The fullscreen GTK4 window overlay is not transparent - it blocks the entire screen when visible.

**Root cause**: GTK4 window transparency requires:
1. RGBA visual support
2. Compositor with transparency support
3. Proper window type hints

**Attempted approaches that didn't work**:
- `window.set_opacity(1.0)` - controls window opacity, not content transparency
- Cairo `Operator::Clear` - clears to transparent but window background still shows

### Potential Solutions

1. **Use X11 directly for overlay** (recommended for X11):
   - Create override-redirect window with ARGB visual
   - Use Xcomposite extension for true transparency
   - More control but bypasses GTK

2. **GTK4 with proper visual setup**:
   ```rust
   // Need to set up RGBA visual before window creation
   // GTK4 should auto-detect but may need explicit setup
   ```

3. **Use cairo-xlib directly**:
   - Create X11 window with 32-bit depth
   - Draw with cairo directly
   - Full transparency control

4. **Shaped window approach**:
   - Instead of transparency, use X11 shape extension
   - Only show the highlight circle region
   - Window is shaped to match highlight bounds

## Display Configuration

Ubuntu display is portrait mode:
- Resolution: 2160x3840
- Center: (1080, 1920)
- Connected via HDMI-0

## Architecture That Works

```
┌─────────────────────────────────────────────────────────┐
│                    Main GTK4 App                         │
├─────────────────────────────────────────────────────────┤
│  SynergyMonitor                                          │
│  - Watches log file with notify crate                   │
│  - Sends events via glib channel                        │
│  - Triggers highlight on CursorReturned                 │
├─────────────────────────────────────────────────────────┤
│  CursorFinderService                                     │
│  - Creates HighlightOverlay on demand                   │
│  - Passes style/animation settings                      │
├─────────────────────────────────────────────────────────┤
│  HighlightOverlay (NEEDS REWORK)                        │
│  - X11 cursor position query works                      │
│  - Animation loop at 60fps works                        │
│  - Transparency NOT working                             │
└─────────────────────────────────────────────────────────┘
```

## Dependencies That Work

```toml
gtk4 = "0.7"
libadwaita = "0.5"
x11rb = "0.13"           # X11 cursor position
notify = "6"             # File watching
regex = "1"              # Log parsing
glib channels            # Thread-safe GTK communication
```

## Next Steps

1. **Fix overlay transparency** - either:
   - Pure X11 ARGB window (most reliable)
   - GTK4 with proper RGBA setup
   - X11 shaped window

2. **Consider alternative approaches**:
   - Desktop notification with icon instead of overlay
   - Smaller non-fullscreen window that follows cursor
   - System compositor effects (if available)

## Environment Variables for Running

```bash
DISPLAY=:1 RUST_LOG=info ./target/debug/cursorhome
```

## Files Modified

- `platforms/linux/Cargo.toml` - Added x11rb dependency
- `platforms/linux/src/ui/highlight_overlay.rs` - X11 cursor tracking
- `platforms/linux/src/services/synergy_monitor.rs` - glib channel for thread safety
- `platforms/linux/src/app.rs` - Service flag and hold guard for background running
