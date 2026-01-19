import SwiftUI

enum HighlightShape: String, CaseIterable, Codable {
    case circle
    case ring
    case crosshair
    case spotlight

    var displayName: String {
        switch self {
        case .circle: return "Circle"
        case .ring: return "Ring"
        case .crosshair: return "Crosshair"
        case .spotlight: return "Spotlight"
        }
    }

    var iconName: String {
        switch self {
        case .circle: return "circle.fill"
        case .ring: return "circle"
        case .crosshair: return "plus"
        case .spotlight: return "light.max"
        }
    }
}

enum BorderStyle: String, CaseIterable, Codable {
    case solid
    case dashed
    case dotted

    var displayName: String {
        switch self {
        case .solid: return "Solid"
        case .dashed: return "Dashed"
        case .dotted: return "Dotted"
        }
    }
}

struct CursorStyle: Codable, Equatable {
    var shape: HighlightShape = .ring
    var size: CGFloat = 60
    var color: CodableColor = CodableColor(.systemYellow)
    var opacity: CGFloat = 0.8
    var borderWeight: CGFloat = 3
    var borderStyle: BorderStyle = .solid
    var glowEnabled: Bool = true
    var glowIntensity: CGFloat = 0.5

    static let `default` = CursorStyle()
}

struct CodableColor: Codable, Equatable {
    var red: CGFloat
    var green: CGFloat
    var blue: CGFloat
    var alpha: CGFloat

    init(_ color: NSColor) {
        let converted = color.usingColorSpace(.sRGB) ?? color
        self.red = converted.redComponent
        self.green = converted.greenComponent
        self.blue = converted.blueComponent
        self.alpha = converted.alphaComponent
    }

    var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }

    var color: Color {
        Color(nsColor)
    }
}
