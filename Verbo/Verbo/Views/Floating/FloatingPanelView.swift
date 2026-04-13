import SwiftUI

struct FloatingPanelView: View {
    @Bindable var viewModel: FloatingViewModel

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
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
        .task { await pollAudioLevelsLoop() }
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
