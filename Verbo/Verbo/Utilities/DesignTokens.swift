import SwiftUI

enum DesignTokens {
    enum Colors {
        // Primary
        static let nearBlack = Color(hex: 0x141413)
        static let terracotta = Color(hex: 0xc96442)
        static let coral = Color(hex: 0xd97757)
        // Surface
        static let parchment = Color(hex: 0xf5f4ed)
        static let ivory = Color(hex: 0xfaf9f5)
        static let warmSand = Color(hex: 0xe8e6dc)
        static let darkSurface = Color(hex: 0x30302e)
        // Text
        static let charcoalWarm = Color(hex: 0x4d4c48)
        static let oliveGray = Color(hex: 0x5e5d59)
        static let stoneGray = Color(hex: 0x87867f)
        static let warmSilver = Color(hex: 0xb0aea5)
        // Border
        static let borderCream = Color(hex: 0xf0eee6)
        static let borderWarm = Color(hex: 0xe8e6dc)
        // Semantic
        static let errorCrimson = Color(hex: 0xb53333)
        static let focusBlue = Color(hex: 0x3898ec)
        // Recording
        static let recordingRed = terracotta
        static let processingCoral = coral
    }

    enum Typography {
        static let headlineFont = Font.system(.title, design: .serif)
        static let bodyFont = Font.system(.body, design: .default)
        static let captionFont = Font.system(.caption, design: .default)
        static let monoFont = Font.system(.body, design: .monospaced)
        // Pill
        static let pillText = Font.system(size: 13, weight: .medium)
        static let pillTimer = Font.system(size: 12, weight: .medium, design: .monospaced)
        static let pillHotkey = Font.system(size: 11, weight: .regular)
        // Bubble
        static let bubbleText = Font.system(size: 14, weight: .regular)
        static let bubbleStatus = Font.system(size: 12, weight: .medium)
        // Settings
        static let settingsTitle = Font.system(size: 13, weight: .semibold)
        static let settingsBody = Font.system(size: 13, weight: .regular)
        static let settingsCaption = Font.system(size: 11, weight: .regular)
    }

    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 24
        static let xxl: CGFloat = 32
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let pill: CGFloat = 18
        static let bubble: CGFloat = 16
    }

    enum Shadows {
        static let ring = Color.black.opacity(0.08)
        static let whisper = Color.black.opacity(0.05)
    }

    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.15)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.25)
        static let expand = SwiftUI.Animation.spring(response: 0.35, dampingFraction: 0.8)
    }

    enum Pill {
        static let height: CGFloat = 36
        static let minWidth: CGFloat = 150
        static let dotSize: CGFloat = 8
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        let red = Double((hex >> 16) & 0xFF) / 255.0
        let green = Double((hex >> 8) & 0xFF) / 255.0
        let blue = Double(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, opacity: opacity)
    }
}
