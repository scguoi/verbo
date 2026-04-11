import SwiftUI

struct BubbleView: View {
    let state: PipelineState
    let lastResult: String?
    let lastSource: String?
    let onCopy: () -> Void
    let onRetry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            bubbleContent
        }
        .padding(DesignTokens.Spacing.md)
        .frame(minWidth: 200, maxWidth: 320, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.bubble)
                .fill(DesignTokens.Colors.ivory)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.bubble)
                        .stroke(DesignTokens.Colors.borderCream, lineWidth: 1)
                )
        )
    }

    // MARK: - Bubble Content

    @ViewBuilder
    private var bubbleContent: some View {
        switch state {
        case .idle:
            if let result = lastResult {
                resultContent(result)
            }

        case .recording:
            if let result = lastResult {
                resultContent(result)
            }

        case .transcribing(let partial):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(String(localized: "bubble.recognizing"))
                    .font(DesignTokens.Typography.bubbleStatus)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                if !partial.isEmpty {
                    Text(partial)
                        .font(DesignTokens.Typography.bubbleText)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                }
            }

        case .processing(let source, let partial):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.xs) {
                Text(source)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
                    .strikethrough(true, color: DesignTokens.Colors.stoneGray)
                if !partial.isEmpty {
                    Text(partial)
                        .font(DesignTokens.Typography.bubbleText)
                        .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                }
            }

        case .done(let result, _):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(result)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    .textSelection(.enabled)

                HStack(spacing: DesignTokens.Spacing.sm) {
                    Text(String(localized: "bubble.inserted"))
                        .font(DesignTokens.Typography.bubbleStatus)
                        .foregroundStyle(Color.green)

                    Spacer()

                    Button(action: onCopy) {
                        Image(systemName: "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundStyle(DesignTokens.Colors.stoneGray)
                    }
                    .buttonStyle(.plain)
                    .help(String(localized: "bubble.copy"))
                }
            }

        case .error(let message):
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
                Text(message)
                    .font(DesignTokens.Typography.bubbleText)
                    .foregroundStyle(DesignTokens.Colors.errorCrimson)

                Button(action: onRetry) {
                    Text(String(localized: "bubble.retry"))
                        .font(DesignTokens.Typography.bubbleStatus)
                        .foregroundStyle(DesignTokens.Colors.terracotta)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Result Content

    private func resultContent(_ result: String) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.sm) {
            Text(result)
                .font(DesignTokens.Typography.bubbleText)
                .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                .textSelection(.enabled)

            HStack {
                Spacer()
                Button(action: onCopy) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 12))
                        .foregroundStyle(DesignTokens.Colors.stoneGray)
                }
                .buttonStyle(.plain)
                .help(String(localized: "bubble.copy"))
            }
        }
    }
}
