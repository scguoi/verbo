import SwiftUI

// MARK: - Notification Extension

extension Notification.Name {
    static let floatingPanelSizeChanged = Notification.Name("floatingPanelSizeChanged")
}

// MARK: - PanelSizeKey

struct PanelSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        if next != .zero { value = next }
    }
}

// MARK: - FloatingPanelView

struct FloatingPanelView: View {
    @Bindable var viewModel: FloatingViewModel

    var body: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.xs) {
            if viewModel.shouldShowBubble {
                BubbleView(
                    state: viewModel.pipelineState,
                    lastResult: viewModel.lastResult,
                    lastSource: viewModel.lastSource,
                    onCopy: handleCopy,
                    onRetry: { viewModel.retry() }
                )
                .transition(
                    .asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .bottom)),
                        removal: .opacity
                    )
                )
            }

            PillView(
                state: viewModel.pipelineState,
                sceneName: viewModel.currentSceneName,
                hotkeyHint: viewModel.currentHotkeyHint,
                timerText: viewModel.timerText,
                audioLevels: viewModel.audioLevels,
                dotColor: viewModel.pillDotColor,
                onTap: { viewModel.pillTapped() }
            )
        }
        .padding(DesignTokens.Spacing.xs)
        .animation(DesignTokens.Animation.expand, value: viewModel.shouldShowBubble)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: PanelSizeKey.self, value: geometry.size)
            }
        )
        .onPreferenceChange(PanelSizeKey.self) { size in
            guard size != .zero else { return }
            NotificationCenter.default.post(
                name: .floatingPanelSizeChanged,
                object: nil,
                userInfo: ["size": size]
            )
        }
        .task {
            await pollAudioLevelsLoop()
        }
    }

    // MARK: - Private Helpers

    private func handleCopy() {
        guard let result = viewModel.lastResult else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }

    private func pollAudioLevelsLoop() async {
        while !Task.isCancelled {
            if viewModel.isRecording {
                await viewModel.pollAudioLevels()
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
