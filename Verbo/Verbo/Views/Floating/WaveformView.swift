import SwiftUI

struct WaveformView: View {
    let levels: [Float]
    let barCount: Int
    let color: Color

    private let barWidth: CGFloat = 2.5
    private let barSpacing: CGFloat = 2.5
    private let minHeight: CGFloat = 3
    private let maxHeight: CGFloat = 36

    init(levels: [Float], barCount: Int = 13, color: Color = DesignTokens.Colors.terracotta) {
        self.levels = levels
        self.barCount = barCount
        self.color = color
    }

    var body: some View {
        HStack(spacing: barSpacing) {
            ForEach(0..<barCount, id: \.self) { index in
                RoundedRectangle(cornerRadius: barWidth / 2)
                    .fill(color)
                    .frame(width: barWidth, height: barHeight(for: index))
            }
        }
        .frame(height: maxHeight)
        .animation(.easeOut(duration: 0.08), value: levels)
    }

    private func barHeight(for index: Int) -> CGFloat {
        // Map barCount bars from the available levels
        let levelIndex = levels.count > 0 ? index * levels.count / barCount : 0
        let level: Float
        if levelIndex < levels.count {
            level = min(levels[levelIndex] * 2.0, 1.0)
        } else {
            level = 0
        }
        return minHeight + CGFloat(level) * (maxHeight - minHeight)
    }
}
