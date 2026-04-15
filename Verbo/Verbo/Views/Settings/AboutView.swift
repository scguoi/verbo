import SwiftUI

// MARK: - AboutView

struct AboutView: View {

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.lg) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(DesignTokens.Colors.terracotta)

            Text("Verbo")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(DesignTokens.Colors.textPrimary)

            Text("v\(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?")")
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            Text(String(localized: "about.description"))
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Text(String(localized: "about.license"))
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.textTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }
}
