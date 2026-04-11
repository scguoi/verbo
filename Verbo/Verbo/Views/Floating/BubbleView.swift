import SwiftUI

struct BubbleView: View {
    let state: PipelineState
    let lastResult: String?
    let lastSource: String?
    let onCopy: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
            bubbleContent
        }
        .padding(.horizontal, DesignTokens.Spacing.md)
        .padding(.vertical, DesignTokens.Spacing.sm)
        .frame(width: 260, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                .fill(DesignTokens.Colors.ivory)
                .shadow(color: DesignTokens.Shadows.whisper, radius: 8, x: 0, y: 2)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.large)
                        .stroke(DesignTokens.Colors.borderCream, lineWidth: 0.5)
                )
        )
    }

    @ViewBuilder
    private var bubbleContent: some View {
        switch state {
        case .transcribing(let partial):
            if !partial.isEmpty {
                Text(partial)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    .fixedSize(horizontal: false, vertical: true)
            }

        case .processing(let source, let partial):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(source)
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                    .strikethrough()
                    .fixedSize(horizontal: false, vertical: true)
                if !partial.isEmpty {
                    Text(partial)
                        .font(DesignTokens.Typography.bubbleText)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

        case .done(let result, _):
            HStack(alignment: .top, spacing: DesignTokens.Spacing.sm) {
                Text(result)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)

                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 11))
                        .foregroundStyle(DesignTokens.Colors.stoneGray)
                }
                .buttonStyle(.plain)
            }

        case .error(let message):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(message)
                    .font(DesignTokens.Typography.settingsCaption)
                    .foregroundStyle(DesignTokens.Colors.errorCrimson)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: onRetry) {
                    Text(String(localized: "bubble.retry"))
                        .font(DesignTokens.Typography.bubbleStatus)
                        .foregroundStyle(DesignTokens.Colors.terracotta)
                }
                .buttonStyle(.plain)
            }

        default:
            if let result = lastResult {
                Text(result)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
