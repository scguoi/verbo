import SwiftUI

struct FloatingPanelView: View {
    @Bindable var viewModel: FloatingViewModel

    var body: some View {
        VStack(spacing: 6) {
            PillView(
                state: viewModel.pipelineState,
                sceneName: viewModel.currentSceneName,
                hotkeyHint: viewModel.currentHotkeyHint,
                timerText: viewModel.timerText,
                audioLevels: viewModel.audioLevels,
                dotColor: viewModel.pillDotColor,
                onTap: { viewModel.pillTapped() }
            )

            if let partial = viewModel.partialTranscript {
                TranscriptPreviewView(text: partial)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: viewModel.partialTranscript != nil)
        .frame(width: FloatingPanel.panelWidth)
        .frame(maxHeight: .infinity, alignment: .bottom)
        .task { await pollAudioLevelsLoop() }
    }

    private func pollAudioLevelsLoop() async {
        while !Task.isCancelled {
            if viewModel.isRecording || viewModel.isTranscribing {
                await viewModel.pollAudioLevels()
            }
            try? await Task.sleep(for: .milliseconds(16))
        }
    }
}

// MARK: - TranscriptPreviewView

/// A compact bubble below the pill that shows the partial transcript as
/// it streams in from STT / LLM. Matches the pill's ivory + warmSand
/// visual language.
private struct TranscriptPreviewView: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13, weight: .regular))
            .foregroundStyle(DesignTokens.Colors.charcoalWarm)
            .lineLimit(8)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: 280)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(DesignTokens.Colors.ivory)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(DesignTokens.Colors.warmSand, lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.12), radius: 8, x: 0, y: 3)
    }
}
