import AppKit
import CoreGraphics

@Observable
final class MagnifierService {
    static let shared = MagnifierService()

    private var magnifierWindow: MagnifierWindow?
    private var displayLink: CVDisplayLink?
    private(set) var isActive = false

    private init() {}

    func toggle() {
        if isActive {
            hide()
        } else {
            show()
        }
    }

    func show() {
        guard !isActive else { return }
        isActive = true

        let prefs = UserPreferences.shared
        magnifierWindow = MagnifierWindow(
            size: prefs.magnifierSize,
            zoom: prefs.magnifierZoom,
            highQuality: prefs.magnifierHighQuality
        )
        magnifierWindow?.orderFrontRegardless()

        startTracking()
    }

    func hide() {
        guard isActive else { return }
        isActive = false

        stopTracking()
        magnifierWindow?.orderOut(nil)
        magnifierWindow = nil
    }

    private func startTracking() {
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        guard let displayLink = link else { return }

        let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
            let service = Unmanaged<MagnifierService>.fromOpaque(userInfo!).takeUnretainedValue()
            DispatchQueue.main.async {
                service.updateMagnifier()
            }
            return kCVReturnSuccess
        }

        let pointer = Unmanaged.passUnretained(self).toOpaque()
        CVDisplayLinkSetOutputCallback(displayLink, callback, pointer)
        CVDisplayLinkStart(displayLink)

        self.displayLink = displayLink
    }

    private func stopTracking() {
        guard let link = displayLink else { return }
        CVDisplayLinkStop(link)
        displayLink = nil
    }

    private func updateMagnifier() {
        guard let window = magnifierWindow else { return }
        let mouseLocation = NSEvent.mouseLocation
        window.updatePosition(to: mouseLocation)
    }
}

// MARK: - Magnifier Window

final class MagnifierWindow: NSWindow {
    private let magnifierView: MagnifierView
    private let zoom: CGFloat
    private let captureSize: CGFloat

    init(size: CGFloat, zoom: CGFloat, highQuality: Bool) {
        self.zoom = zoom
        self.captureSize = size / zoom
        self.magnifierView = MagnifierView(frame: NSRect(x: 0, y: 0, width: size, height: size))

        super.init(
            contentRect: NSRect(x: 0, y: 0, width: size, height: size),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.ignoresMouseEvents = true
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        magnifierView.wantsLayer = true
        magnifierView.layer?.cornerRadius = size / 2
        magnifierView.layer?.masksToBounds = true
        magnifierView.layer?.borderWidth = 2
        magnifierView.layer?.borderColor = NSColor.white.withAlphaComponent(0.8).cgColor

        self.contentView = magnifierView
    }

    func updatePosition(to mouseLocation: CGPoint) {
        // Position window offset from cursor
        let offset: CGFloat = 30
        let newOrigin = CGPoint(
            x: mouseLocation.x + offset,
            y: mouseLocation.y + offset
        )
        setFrameOrigin(newOrigin)

        // Capture screen content
        captureScreen(around: mouseLocation)
    }

    private func captureScreen(around point: CGPoint) {
        // Convert NSScreen coordinates (origin bottom-left) to CG coordinates (origin top-left)
        // The global display bounds have origin at top-left of the primary display
        guard let primaryScreen = NSScreen.screens.first else { return }
        let primaryHeight = primaryScreen.frame.height

        // Convert Y: NS has origin at bottom, CG has origin at top
        let cgPoint = CGPoint(
            x: point.x,
            y: primaryHeight - point.y
        )

        let captureRect = CGRect(
            x: cgPoint.x - captureSize / 2,
            y: cgPoint.y - captureSize / 2,
            width: captureSize,
            height: captureSize
        )

        guard let cgImage = CGWindowListCreateImage(
            captureRect,
            .optionOnScreenBelowWindow,
            CGWindowID(0),
            .bestResolution
        ) else { return }

        magnifierView.updateImage(cgImage)
    }
}

// MARK: - Magnifier View

final class MagnifierView: NSView {
    private var currentImage: CGImage?

    override func draw(_ dirtyRect: NSRect) {
        guard let image = currentImage, let context = NSGraphicsContext.current?.cgContext else {
            NSColor.black.setFill()
            dirtyRect.fill()
            return
        }

        context.interpolationQuality = .high
        context.draw(image, in: bounds)
    }

    func updateImage(_ image: CGImage) {
        currentImage = image
        needsDisplay = true
    }
}
