import SwiftUI

struct FloatingPanelView: View {
    @Bindable var viewModel: FloatingViewModel

    var body: some View {
        VStack {
            Spacer()

            HStack(alignment: .bottom, spacing: DesignTokens.Spacing.sm) {
                // Toast area
                ZStack(alignment: .bottomTrailing) {
                    Color.clear.frame(width: 260)

                    if viewModel.shouldShowBubble {
                        BubbleView(
                            state: viewModel.pipelineState,
                            lastResult: viewModel.lastResult,
                            lastSource: viewModel.lastSource,
                            onCopy: handleCopy,
                            onRetry: { viewModel.retry() }
                        )
                        .transition(.opacity)
                        .onHover { hovering in
                            viewModel.toastHovered = hovering
                        }
                    }
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
        }
        .padding(DesignTokens.Spacing.sm)
        .frame(width: FloatingPanel.panelWidth, height: FloatingPanel.panelHeight, alignment: .bottomTrailing)
        .animation(DesignTokens.Animation.standard, value: viewModel.shouldShowBubble)
        .task { await pollAudioLevelsLoop() }
    }

    private func handleCopy() {
        guard let result = viewModel.lastResult else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(result, forType: .string)
    }

    private func pollAudioLevelsLoop() async {
        while !Task.isCancelled {
            if viewModel.isRecording || viewModel.isTranscribing {
                await viewModel.pollAudioLevels()
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }
}
