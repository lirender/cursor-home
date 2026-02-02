# CursorHome Cross-Platform Protocol

This document describes the communication protocol used between CursorHome clients on different platforms (macOS, Linux).

## Overview

CursorHome clients communicate to provide seamless cursor highlighting across multiple machines connected via Synergy 3. The protocol uses JSON messages exchanged via Synergy's barrier protocol or a shared configuration mechanism.

## Communication Methods

### 1. Synergy Event Monitoring (Primary)

Both macOS and Linux clients monitor Synergy 3 for cursor transition events:

- **Cursor Leave**: When cursor exits to another machine
- **Cursor Enter**: When cursor returns from another machine

This happens by monitoring Synergy log files or the barrier network protocol.

### 2. Direct Communication (Optional)

For advanced features like settings sync and remote highlight requests, clients can communicate directly:

- **Port**: 24801 (one above Synergy's default 24800)
- **Protocol**: TCP with JSON messages
- **Discovery**: mDNS/Bonjour for automatic peer detection

## Message Types

### cursor_transition

Sent when the cursor moves between machines. This is primarily detected from Synergy events.

```json
{
  "type": "cursor_transition",
  "from": "macbook-pro",
  "to": "linux-desktop",
  "position": { "x": 1920, "y": 540 },
  "timestamp": 1706825432000
}
```

### highlight_request

Request another machine to show cursor highlight.

```json
{
  "type": "highlight_request",
  "target": "linux-desktop",
  "style": {
    "shape": "circle",
    "size": 100,
    "color": { "r": 255, "g": 85, "b": 0, "a": 0.8 }
  },
  "duration": 3.0
}
```

### teleport_request

Request to move cursor to a specific position or center of main display.

```json
{
  "type": "teleport_request",
  "target": "macbook-pro",
  "center_on_main": true
}
```

### settings_sync

Synchronize visual settings between machines for consistent appearance.

```json
{
  "type": "settings_sync",
  "source": "macbook-pro",
  "cursor_style": {
    "shape": "ring",
    "size": 80,
    "color": { "r": 0, "g": 122, "b": 255, "a": 1.0 },
    "border_weight": 3,
    "glow_enabled": true
  },
  "shake_enabled": true,
  "shake_sensitivity": 0.5
}
```

### heartbeat

Keep-alive message to detect peer disconnections.

```json
{
  "type": "heartbeat",
  "source": "macbook-pro",
  "timestamp": 1706825432000
}
```

## Cursor Style Options

| Property | Type | Range | Description |
|----------|------|-------|-------------|
| shape | string | circle, ring, crosshair, spotlight | Highlight shape |
| size | number | 20-200 | Diameter in pixels |
| color | object | RGBA | Fill/stroke color |
| border_weight | number | 1-10 | Border thickness |
| border_style | string | solid, dashed, dotted | Border pattern |
| glow_enabled | boolean | - | Enable glow effect |
| glow_intensity | number | 0-1 | Glow brightness |

## Animation Options

| Property | Type | Range | Description |
|----------|------|-------|-------------|
| type | string | none, pulse, ripple, fade, scale | Animation type |
| duration | number | 0.1-5.0 | Animation duration in seconds |
| easing | string | linear, ease_in, ease_out, ease_in_out | Timing function |
| repeat_count | integer | 0+ | Repeat count (0 = infinite) |

## Platform Implementation Notes

### macOS

- Uses `SynergyMonitor.swift` to watch Synergy log files
- Posts `NSNotification` for cursor transitions
- Integrates with `CursorFinderService` for highlighting

### Linux (Wayland)

- Uses `synergy_monitor.rs` to watch Synergy log files
- Emits events via channels for cursor transitions
- Uses layer-shell protocol for overlay windows

## Error Handling

All response messages include a `success` boolean. On failure, an `error` string describes the issue:

```json
{
  "type": "highlight_response",
  "source": "linux-desktop",
  "success": false,
  "error": "Wayland compositor does not support layer-shell protocol"
}
```

## Security Considerations

- Communication is intended for local network only (same as Synergy)
- No authentication is implemented (relies on network security)
- Messages should be validated against the JSON schema before processing
