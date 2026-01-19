import AppKit
import SwiftUI

final class HighlightWindow: NSWindow {
    private var highlightView: HighlightOverlayView!
    private var trackingTimer: Timer?
    private var hideWorkItem: DispatchWorkItem?
    private var onHideCompletion: (() -> Void)?
    private var onScreenChanged: ((NSScreen) -> Void)?

    convenience init(screen: NSScreen) {
        self.init(
            contentRect: screen.frame,
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.highlightView = HighlightOverlayView()
        self.level = .screenSaver
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = false
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        self.setFrame(screen.frame, display: false)
        self.contentView = highlightView
    }

    func showHighlight(at point: CGPoint, style: CursorStyle, animation: AnimationStyle, duration: TimeInterval = 5.0, onHide: (() -> Void)? = nil, onScreenChanged: ((NSScreen) -> Void)? = nil) {
        hideWorkItem?.cancel()
        trackingTimer?.invalidate()

        self.onHideCompletion = onHide
        self.onScreenChanged = onScreenChanged
        highlightView.style = style
        highlightView.animationStyle = animation
        updateHighlightPosition()

        orderFrontRegardless()
        highlightView.startAnimation()

        // Start tracking cursor position
        trackingTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.updateHighlightPosition()
        }

        // Auto-hide after duration
        let workItem = DispatchWorkItem { [weak self] in
            self?.hideHighlight()
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: workItem)
    }

    private func updateHighlightPosition() {
        guard let screen = screen else { return }
        let mouseLocation = NSEvent.mouseLocation

        // Check if mouse moved to a different screen
        if !screen.frame.contains(mouseLocation) {
            // Find the new screen and hide this window
            if let newScreen = NSScreen.screens.first(where: { $0.frame.contains(mouseLocation) }) {
                // Hide this highlight immediately
                highlightView.stopAnimation()
                orderOut(nil)
                onScreenChanged?(newScreen)
            }
            return
        }

        let windowPoint = CGPoint(
            x: mouseLocation.x - screen.frame.origin.x,
            y: mouseLocation.y - screen.frame.origin.y
        )
        highlightView.updatePosition(windowPoint)
    }

    func hideHighlight() {
        trackingTimer?.invalidate()
        trackingTimer = nil
        highlightView.stopAnimation()
        orderOut(nil)
        onHideCompletion?()
        onHideCompletion = nil
    }
}

// MARK: - Highlight Overlay View

final class HighlightOverlayView: NSView {
    var style: CursorStyle = .default
    var animationStyle: AnimationStyle = .default

    private var currentPoint: CGPoint = .zero

    private var highlightLayer: CAShapeLayer?
    private var glowLayer: CAShapeLayer?
    private var particleLayers: [CAShapeLayer] = []
    private var pulseLayer: CAShapeLayer?

    private var animationTimer: Timer?
    private var animationPhase: CGFloat = 0

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool { false }

    func updatePosition(_ point: CGPoint) {
        currentPoint = point
        updateLayers()
    }

    func startAnimation() {
        removeAllLayers()
        createLayers()

        // Start continuous animation updates
        animationTimer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
            self?.animationPhase += 0.05
            self?.updateAnimations()
        }
    }

    func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
        removeAllLayers()
    }

    private func removeAllLayers() {
        highlightLayer?.removeFromSuperlayer()
        glowLayer?.removeFromSuperlayer()
        pulseLayer?.removeFromSuperlayer()
        particleLayers.forEach { $0.removeFromSuperlayer() }

        highlightLayer = nil
        glowLayer = nil
        pulseLayer = nil
        particleLayers.removeAll()
    }

    private func createLayers() {
        // Create glow layer
        if style.glowEnabled {
            let glow = CAShapeLayer()
            glow.fillColor = nil
            glow.strokeColor = style.color.nsColor.withAlphaComponent(style.glowIntensity * 0.5).cgColor
            glow.lineWidth = style.borderWeight * 4
            glow.lineCap = .round
            glow.lineJoin = .round
            glow.shadowColor = style.color.nsColor.cgColor
            glow.shadowRadius = 15 * style.glowIntensity
            glow.shadowOpacity = Float(style.glowIntensity)
            glow.shadowOffset = .zero
            layer?.addSublayer(glow)
            glowLayer = glow
        }

        // Create pulse layer for pulse animation
        if animationStyle.type == .pulse || animationStyle.type == .ripple {
            let pulse = CAShapeLayer()
            pulse.fillColor = nil
            pulse.strokeColor = style.color.nsColor.withAlphaComponent(0.5).cgColor
            pulse.lineWidth = style.borderWeight
            layer?.addSublayer(pulse)
            pulseLayer = pulse
        }

        // Create main highlight layer
        let highlight = CAShapeLayer()
        highlight.fillColor = fillColorForShape()
        highlight.strokeColor = style.color.nsColor.withAlphaComponent(style.opacity).cgColor
        highlight.lineWidth = style.borderWeight
        highlight.lineDashPattern = dashPatternForStyle()
        layer?.addSublayer(highlight)
        highlightLayer = highlight

        // Create particle layers for ripple effect
        if animationStyle.type == .ripple {
            for _ in 0..<8 {
                let particle = CAShapeLayer()
                particle.fillColor = style.color.nsColor.withAlphaComponent(0.6).cgColor
                particle.strokeColor = nil
                layer?.addSublayer(particle)
                particleLayers.append(particle)
            }
        }
    }

    private func updateLayers() {
        guard let highlight = highlightLayer else { return }

        let size = style.size
        let rect = CGRect(
            x: currentPoint.x - size / 2,
            y: currentPoint.y - size / 2,
            width: size,
            height: size
        )

        // Update main highlight
        highlight.path = pathForShape(in: rect)

        // Update glow
        glowLayer?.path = highlight.path

        // Update pulse
        updatePulse(at: currentPoint)

        // Update particles
        updateParticles(at: currentPoint)
    }

    private func updatePulse(at center: CGPoint) {
        guard let pulse = pulseLayer else { return }

        let pulseScale = 1.0 + 0.5 * sin(animationPhase * 2)
        let pulseSize = style.size * pulseScale
        let pulseRect = CGRect(
            x: center.x - pulseSize / 2,
            y: center.y - pulseSize / 2,
            width: pulseSize,
            height: pulseSize
        )

        pulse.path = CGPath(ellipseIn: pulseRect, transform: nil)
        pulse.opacity = Float(0.5 * (1.0 - (pulseScale - 1.0) / 0.5))
    }

    private func updateParticles(at center: CGPoint) {
        guard !particleLayers.isEmpty else { return }

        for (i, particle) in particleLayers.enumerated() {
            let angle = (CGFloat(i) / CGFloat(particleLayers.count)) * 2 * .pi + animationPhase
            let distance = style.size * 0.6 + 10 * sin(animationPhase * 3 + CGFloat(i))
            let particleSize: CGFloat = 4 + 2 * sin(animationPhase * 2 + CGFloat(i) * 0.5)

            let x = center.x + cos(angle) * distance
            let y = center.y + sin(angle) * distance

            let particleRect = CGRect(
                x: x - particleSize / 2,
                y: y - particleSize / 2,
                width: particleSize,
                height: particleSize
            )
            particle.path = CGPath(ellipseIn: particleRect, transform: nil)
        }
    }

    private func updateAnimations() {
        guard highlightLayer != nil else { return }

        switch animationStyle.type {
        case .pulse:
            // Gentle glow intensity change (no scale bouncing)
            let glowOpacity = 0.3 + 0.2 * sin(animationPhase * 1.5)
            glowLayer?.shadowOpacity = Float(glowOpacity * style.glowIntensity)

        case .ripple:
            // Particles orbit smoothly
            break

        case .fade:
            // Smooth opacity breathing
            let opacity = 0.6 + 0.4 * sin(animationPhase * 1.5)
            highlightLayer?.opacity = Float(opacity)
            glowLayer?.opacity = Float(opacity)

        case .scale:
            // Rotation instead of scale bouncing
            let rotation = animationPhase * 0.5
            highlightLayer?.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)
            glowLayer?.transform = CATransform3DMakeRotation(rotation, 0, 0, 1)

        case .none:
            break
        }

        // Animate dash pattern smoothly
        if style.borderStyle != .solid {
            highlightLayer?.lineDashPhase = animationPhase * 5
        }
    }

    private func pathForShape(in rect: CGRect) -> CGPath {
        switch style.shape {
        case .circle:
            return CGPath(ellipseIn: rect, transform: nil)

        case .ring:
            return CGPath(ellipseIn: rect, transform: nil)

        case .crosshair:
            let path = CGMutablePath()
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let halfSize = rect.width / 2

            // Horizontal line
            path.move(to: CGPoint(x: center.x - halfSize, y: center.y))
            path.addLine(to: CGPoint(x: center.x + halfSize, y: center.y))

            // Vertical line
            path.move(to: CGPoint(x: center.x, y: center.y - halfSize))
            path.addLine(to: CGPoint(x: center.x, y: center.y + halfSize))

            // Center dot
            let dotSize: CGFloat = 6
            path.addEllipse(in: CGRect(
                x: center.x - dotSize / 2,
                y: center.y - dotSize / 2,
                width: dotSize,
                height: dotSize
            ))

            return path

        case .spotlight:
            let path = CGMutablePath()
            path.addRect(bounds)
            path.addEllipse(in: rect)
            return path
        }
    }

    private func fillColorForShape() -> CGColor? {
        switch style.shape {
        case .circle:
            return style.color.nsColor.withAlphaComponent(style.opacity * 0.2).cgColor
        case .ring, .crosshair:
            return nil
        case .spotlight:
            return NSColor.black.withAlphaComponent(0.5).cgColor
        }
    }

    private func dashPatternForStyle() -> [NSNumber]? {
        switch style.borderStyle {
        case .solid:
            return nil
        case .dashed:
            return [10, 5]
        case .dotted:
            return [2, 4]
        }
    }
}
