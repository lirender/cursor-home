# CursorHome Linux - Revised Implementation Plan

## Current Status

**Working:**
- GTK4 app runs as background service
- Synergy 3 log monitoring detects cursor transitions
- X11 cursor position tracking via `x11rb`
- Animation loop at 60fps

**Not Working:**
- Overlay window is opaque, blocks entire screen

## Problem: Transparent Overlay on X11

GTK4 windows are not transparent by default. We need a different approach.

## Solution Options

### Option 1: Pure X11 ARGB Window (Recommended)

Create an overlay window directly with X11, bypassing GTK for the overlay:

```rust
use x11rb::protocol::xproto::*;

// 1. Find ARGB visual (32-bit depth with alpha)
// 2. Create window with that visual
// 3. Set override_redirect = true (no window manager decoration)
// 4. Use cairo-xlib to draw with transparency
```

**Pros:**
- Full control over transparency
- Known to work reliably
- No compositor dependency

**Cons:**
- More complex code
- Need to manage X11 window lifecycle manually

### Option 2: GTK4 with CSS Transparency

Use GTK4's CSS system for transparency:

```rust
let provider = gtk4::CssProvider::new();
provider.load_from_data("window { background: transparent; }");
// Apply to window
```

Combined with proper window hints:
```rust
window.set_type_hint(gdk::WindowTypeHint::Dock); // or Notification
```

**Pros:**
- Stays within GTK4 ecosystem
- Simpler code

**Cons:**
- May not work on all X11 setups
- Compositor-dependent

### Option 3: Shaped Window (No Transparency Needed)

Use X11 shape extension to make window non-rectangular:

```rust
// Only the highlight circle is part of the window
// Rest of screen passes through
use x11rb::protocol::shape::*;
```

**Pros:**
- Works without compositor
- No transparency needed

**Cons:**
- Need to update shape on every frame
- Slightly more complex

### Option 4: Small Following Window

Instead of fullscreen overlay, use a small window that follows cursor:

```rust
// 100x100 pixel window
// Positioned centered on cursor
// Move window every frame instead of redrawing on fullscreen
```

**Pros:**
- Simpler transparency (small area)
- Less GPU intensive

**Cons:**
- Window may flicker during movement
- Need to handle window manager interactions

## Recommended Approach

**Phase 1: Try GTK4 CSS transparency first (simplest)**
- Add CSS provider for transparent background
- Test if it works with current compositor

**Phase 2: If CSS fails, implement X11 ARGB window**
- Create separate X11 overlay module
- Use cairo-xlib for drawing
- Keep GTK4 for settings/tray icon

## Implementation Details for Option 1 (X11 ARGB)

```rust
// New file: src/ui/x11_overlay.rs

pub struct X11Overlay {
    conn: x11rb::rust_connection::RustConnection,
    window: u32,
    gc: u32,
    width: u16,
    height: u16,
}

impl X11Overlay {
    pub fn new() -> Result<Self> {
        let (conn, screen_num) = x11rb::connect(None)?;
        let screen = &conn.setup().roots[screen_num];

        // Find 32-bit ARGB visual
        let visual = find_argb_visual(&conn, screen)?;

        // Create colormap for ARGB visual
        let colormap = conn.generate_id()?;
        create_colormap(&conn, ColormapAlloc::NONE, colormap, screen.root, visual)?;

        // Create window
        let window = conn.generate_id()?;
        create_window(
            &conn,
            32, // depth
            window,
            screen.root,
            0, 0, screen.width_in_pixels, screen.height_in_pixels,
            0, // border
            WindowClass::INPUT_OUTPUT,
            visual,
            &CreateWindowAux::new()
                .background_pixel(0) // transparent
                .border_pixel(0)
                .override_redirect(1) // no WM decoration
                .colormap(colormap)
                .event_mask(EventMask::EXPOSURE),
        )?;

        // ... create GC, etc.
    }

    pub fn show(&self) { map_window(&self.conn, self.window); }
    pub fn hide(&self) { unmap_window(&self.conn, self.window); }
    pub fn draw_highlight(&self, x: i16, y: i16, radius: u16, color: u32) {
        // Use cairo or direct X11 drawing
    }
}
```

## Dependencies to Add

For X11 ARGB approach:
```toml
x11rb = { version = "0.13", features = ["allow-unsafe-code", "render"] }
cairo-rs = { version = "0.18", features = ["xcb"] }
```

## Testing Plan

1. Test CSS transparency on current Ubuntu setup
2. If fails, implement X11 ARGB
3. Verify highlight follows cursor
4. Verify highlight fades after duration
5. Verify no screen blocking

## Timeline

1. CSS transparency attempt: 30 min
2. X11 ARGB implementation (if needed): 2-3 hours
3. Testing and polish: 1 hour
