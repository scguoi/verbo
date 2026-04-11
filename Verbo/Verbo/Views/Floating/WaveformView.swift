import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let isActive: Bool

    private let barWidth: CGFloat = 3
    private let barSpacing: CGFloat = 2
    private let minHeight: CGFloat = 4
    private let maxHeight: CGFloat = 16

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<5, id: \.self) { index in
                let level = index < levels.count ? levels[index] : 0
                let height = minHeight + CGFloat(level) * (maxHeight - minHeight)

                RoundedRectangle(cornerRadius: 1.5)
                    .fill(DesignTokens.Colors.terracotta)
                    .frame(width: barWidth, height: height)
                    .animation(
                        isActive
                            ? DesignTokens.Animation.quick.repeatForever(autoreverses: true)
                            : DesignTokens.Animation.quick,
                        value: height
                    )
            }
        }
        .frame(height: maxHeight)
    }
}
