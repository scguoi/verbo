import SwiftUI

struct PillView: View {
    let state: PipelineState
    let sceneName: String
    let hotkeyHint: String
    let timerText: String
    let audioLevels: [Float]
    let dotColor: Color
    let onTap: () -> Void

    @State private var dotPulse: Bool = false
    @State private var dotsPhase: Int = 0
    private let dotsTimer = Timer.publish(every: 0.4, on: .main, in: .common).autoconnect()

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignTokens.Spacing.sm) {
                statusDot
                content
            }
            .frame(width: 150, height: DesignTokens.Pill.height)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.pill)
                    .fill(DesignTokens.Colors.ivory)
                    .overlay(
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.pill)
                            .stroke(DesignTokens.Colors.borderCream, lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
        .onReceive(dotsTimer) { _ in
            if case .processing = state {
                dotsPhase = (dotsPhase + 1) % 4
            }
        }
    }

    // MARK: - Status Dot

    @ViewBuilder
    private var statusDot: some View {
        Circle()
            .fill(dotColor)
            .frame(
                width: DesignTokens.Pill.dotSize,
                height: DesignTokens.Pill.dotSize
            )
            .scaleEffect(dotPulse ? 1.3 : 1.0)
            .onChange(of: state) { _, newState in
                if case .recording = newState {
                    withAnimation(
                        .easeInOut(duration: 0.6).repeatForever(autoreverses: true)
                    ) {
                        dotPulse = true
                    }
                } else {
                    withAnimation(DesignTokens.Animation.quick) {
                        dotPulse = false
                    }
                }
            }
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        switch state {
        case .idle:
            HStack(spacing: DesignTokens.Spacing.xs) {
                Text(sceneName)
                    .font(DesignTokens.Typography.pillText)
                    .foregroundStyle(DesignTokens.Colors.charcoalWarm)
                    .lineLimit(1)
                Text(hotkeyHint)
                    .font(DesignTokens.Typography.pillHotkey)
                    .foregroundStyle(DesignTokens.Colors.stoneGray)
            }

        case .recording:
            WaveformView(levels: audioLevels)

        case .transcribing:
            WaveformView(levels: audioLevels, color: DesignTokens.Colors.coral)

        case .processing:
            HStack(spacing: 2) {
                Text(String(localized: "pill.processing"))
                    .font(DesignTokens.Typography.pillText)
                    .foregroundStyle(DesignTokens.Colors.coral)
                bouncingDots
            }

        case .done:
            Text(String(localized: "pill.done"))
                .font(DesignTokens.Typography.pillText)
                .foregroundStyle(Color.green)

        case .error:
            Text(String(localized: "pill.error"))
                .font(DesignTokens.Typography.pillText)
                .foregroundStyle(DesignTokens.Colors.errorCrimson)
        }
    }

    // MARK: - Bouncing Dots

    private var bouncingDots: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(DesignTokens.Colors.coral)
                    .frame(width: 3, height: 3)
                    .offset(y: dotsPhase == i ? -3 : 0)
                    .animation(
                        .easeInOut(duration: 0.3).delay(Double(i) * 0.1),
                        value: dotsPhase
                    )
            }
        }
    }
}
