//
//  Models.swift
//  MewGlow
//
//  Data models, enums, and helpers shared across the app.
//

import SwiftUI

// MARK: - Connection Status

enum ConnectionStatus: Equatable {
    case notConnected
    case connecting
    case connected
    case failed

    var displayText: String {
        switch self {
        case .notConnected: return "Not Connected"
        case .connecting:   return "Connecting..."
        case .connected:    return "Connected"
        case .failed:       return "Connection Failed"
        }
    }

    var indicatorColor: Color {
        switch self {
        case .notConnected: return Color.gray.opacity(0.5)
        case .connecting:   return Color.yellow
        case .connected:    return Color.green
        case .failed:       return Color.red
        }
    }

    var buttonText: String {
        switch self {
        case .notConnected: return "Connect"
        case .connecting:   return "Connecting..."
        case .connected:    return "Connected"
        case .failed:       return "Try Again"
        }
    }
}

// MARK: - Light Effect

enum LightEffect: String, CaseIterable, Identifiable, Codable {
    case steady = "Steady"
    case breathing = "Breathing"
    case blink = "Blink"
    case heartbeat = "Heartbeat"

    var id: String { rawValue }

    var wireValue: String {
        switch self {
        case .steady: return "steady"
        case .breathing: return "breathing"
        case .blink: return "blink"
        case .heartbeat: return "heartbeat"
        }
    }
}

// MARK: - Command Status

enum CommandStatus: Equatable {
    case idle
    case sending
    case received
    case executing
    case completed
    case replied
    case failed

    var displayText: String {
        switch self {
        case .idle:      return "Ready"
        case .sending:   return "Sending..."
        case .received:  return "Lamp received the message"
        case .executing: return "Playing light and motion"
        case .completed: return "Completed"
        case .replied:   return "They responded to you \u{2764}\u{FE0F}"
        case .failed:    return "Failed to send"
        }
    }

    var isInProgress: Bool {
        self == .sending || self == .received || self == .executing
    }
}

// MARK: - Lamp Command

struct LampCommand: Codable {
    let text: String
    let emoticon: String
    let red: Int
    let green: Int
    let blue: Int
    let brightness: Int
    let effect: String
}

// MARK: - Color Helpers

extension Color {
    func toRGB255() -> (red: Int, green: Int, blue: Int) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return (Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        #else
        return (0, 0, 0)
        #endif
    }
}

// MARK: - Preset Palettes

enum Presets {
    static let emoticons: [String] = ["(^_^)", "(-_-)", "(^o^)", "(>_<)", "(T_T)"]

    static let colors: [Color] = [
        Color(red: 1.0, green: 0.78, blue: 0.32), // Warm Yellow
        Color(red: 1.0, green: 0.55, blue: 0.68), // Pink
        Color(red: 0.65, green: 0.48, blue: 0.90), // Purple
        Color(red: 0.38, green: 0.67, blue: 0.95), // Blue
        Color(red: 0.43, green: 0.80, blue: 0.58), // Green
        Color.white
    ]
}

// MARK: - App Theme Colors

enum AppTheme {
    static let warmYellow = Color(red: 1.0, green: 0.86, blue: 0.48)
    static let paleYellow = Color(red: 1.0, green: 0.94, blue: 0.72)
    static let softBackground = Color(red: 1.0, green: 0.99, blue: 0.96)
    static let lightGray = Color(red: 0.85, green: 0.85, blue: 0.85)
    static let darkText = Color(red: 0.15, green: 0.15, blue: 0.15)
}
