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
                .foregroundStyle(DesignTokens.Colors.nearBlack)

            Text("v0.1.0")
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.stoneGray)

            Text(String(localized: "about.description"))
                .font(DesignTokens.Typography.settingsBody)
                .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 360)

            Text(String(localized: "about.license"))
                .font(DesignTokens.Typography.settingsCaption)
                .foregroundStyle(DesignTokens.Colors.stoneGray)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.xxl)
    }
}
