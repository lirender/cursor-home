import Foundation

enum AnimationType: String, CaseIterable, Codable {
    case pulse
    case ripple
    case fade
    case scale
    case none

    var displayName: String {
        switch self {
        case .pulse: return "Pulse"
        case .ripple: return "Ripple"
        case .fade: return "Fade"
        case .scale: return "Scale"
        case .none: return "None"
        }
    }

    var iconName: String {
        switch self {
        case .pulse: return "waveform.circle"
        case .ripple: return "circle.hexagongrid"
        case .fade: return "circle.lefthalf.filled"
        case .scale: return "arrow.up.left.and.arrow.down.right"
        case .none: return "xmark.circle"
        }
    }
}

enum EasingType: String, CaseIterable, Codable {
    case linear
    case easeIn
    case easeOut
    case easeInOut
    case spring

    var displayName: String {
        switch self {
        case .linear: return "Linear"
        case .easeIn: return "Ease In"
        case .easeOut: return "Ease Out"
        case .easeInOut: return "Ease In/Out"
        case .spring: return "Spring"
        }
    }
}

struct AnimationStyle: Codable, Equatable {
    var type: AnimationType = .ripple
    var duration: TimeInterval = 0.5
    var easing: EasingType = .easeInOut
    var repeatCount: Int = 2

    static let `default` = AnimationStyle()
}

struct CursorMovementStyle: Codable, Equatable {
    var animated: Bool = true
    var duration: TimeInterval = 0.3
    var easing: EasingType = .easeInOut

    static let `default` = CursorMovementStyle()
}
