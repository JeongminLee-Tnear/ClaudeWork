import SwiftUI

// MARK: - Claude Theme Colors
// Inspired by Clui CC's warm, earthy design language

enum ClaudeTheme {
    // MARK: - Accent
    /// Terracotta/burnt orange - Claude's signature color
    static let accent = Color(light: .hex(0xD97757), dark: .hex(0xD97757))
    static let accentSubtle = Color(light: .hex(0xD97757).opacity(0.12), dark: .hex(0xD97757).opacity(0.15))

    // MARK: - Backgrounds
    static let background = Color(light: .hex(0xF5F4EF), dark: .hex(0x21211E))
    static let surfacePrimary = Color(light: .hex(0xEDEAE0), dark: .hex(0x2A2A27))
    static let surfaceSecondary = Color(light: .hex(0xE5E2D9), dark: .hex(0x353530))
    static let surfaceTertiary = Color(light: .hex(0xDDDAD2), dark: .hex(0x42423D))
    static let surfaceElevated = Color(light: .hex(0xFAF9F6), dark: .hex(0x2F2F2B))

    // MARK: - Sidebar
    static let sidebarBackground = Color(light: .hex(0xEDEAE2), dark: .hex(0x1C1C1A))
    static let sidebarItemHover = Color(light: .hex(0xE0DDD4), dark: .hex(0x2A2A27))
    static let sidebarItemSelected = Color(light: .hex(0xD97757).opacity(0.12), dark: .hex(0xD97757).opacity(0.15))

    // MARK: - Text
    static let textPrimary = Color(light: .hex(0x3C3929), dark: .hex(0xCCC9C0))
    static let textSecondary = Color(light: .hex(0x6B6960), dark: .hex(0x9A978E))
    static let textTertiary = Color(light: .hex(0x9A978E), dark: .hex(0x76766E))
    static let textOnAccent = Color.white

    // MARK: - Borders
    static let border = Color(light: .hex(0xD5D2C8), dark: .hex(0x3B3B36))
    static let borderSubtle = Color(light: .hex(0xE0DDD4), dark: .hex(0x2F2F2B))

    // MARK: - Code Blocks
    static let codeBackground = Color(light: .hex(0xE8E5DC), dark: .hex(0x1A1A18))
    static let codeHeaderBackground = Color(light: .hex(0xDDD9CF), dark: .hex(0x252523))

    // MARK: - User Bubble
    static let userBubble = Color(light: .hex(0x3C3929), dark: .hex(0x42423D))
    static let userBubbleText = Color(light: .hex(0xF5F4EF), dark: .hex(0xE8E5DC))

    // MARK: - Assistant Bubble
    static let assistantBubble = Color(light: .hex(0xE8E5DC), dark: .hex(0x2A2A27))

    // MARK: - Status Colors
    static let statusSuccess = Color(light: .hex(0x5A9A6E), dark: .hex(0x7AAC8C))
    static let statusError = Color(light: .hex(0xB85C50), dark: .hex(0xC47060))
    static let statusWarning = Color(light: .hex(0xC78A40), dark: .hex(0xD9A757))
    static let statusRunning = accent

    // MARK: - Input
    static let inputBackground = Color(light: .hex(0xFAF9F6), dark: .hex(0x2A2A27))
    static let inputBorder = Color(light: .hex(0xD5D2C8), dark: .hex(0x3B3B36))
    static let inputPlaceholder = textTertiary

    // MARK: - Dimensions
    static let cornerRadiusSmall: CGFloat = 8
    static let cornerRadiusMedium: CGFloat = 12
    static let cornerRadiusLarge: CGFloat = 16
    static let cornerRadiusPill: CGFloat = 20

    // MARK: - Shadows
    static let shadowColor = Color.black.opacity(0.08)
    static let shadowRadius: CGFloat = 8
}

// MARK: - Color Helpers

extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}

extension Color {
    static func hex(_ hex: UInt, opacity: Double = 1.0) -> Color {
        Color(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }
}

// MARK: - Theme View Modifiers

extension View {
    func claudeCard() -> some View {
        self
            .background(ClaudeTheme.surfacePrimary)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusMedium)
                    .strokeBorder(ClaudeTheme.border, lineWidth: 0.5)
            )
    }

    func claudeInputField() -> some View {
        self
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(ClaudeTheme.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusPill))
            .overlay(
                RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusPill)
                    .strokeBorder(ClaudeTheme.inputBorder, lineWidth: 1)
            )
    }
}

// MARK: - Claude Button Style

struct ClaudeAccentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                configuration.isPressed
                    ? ClaudeTheme.accent.opacity(0.8)
                    : ClaudeTheme.accent
            )
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
    }
}

struct ClaudeSecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.medium))
            .foregroundStyle(ClaudeTheme.textPrimary)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                configuration.isPressed
                    ? ClaudeTheme.surfaceTertiary
                    : ClaudeTheme.surfaceSecondary
            )
            .clipShape(RoundedRectangle(cornerRadius: ClaudeTheme.cornerRadiusSmall))
    }
}

// MARK: - Claude Send Button

struct ClaudeSendButton: View {
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(isEnabled ? ClaudeTheme.accent : ClaudeTheme.textTertiary)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}
