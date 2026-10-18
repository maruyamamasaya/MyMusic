import SwiftUI

struct SceneryBatteryIndicator: View {
    let percentage: Int?
    var isCharging = false
    let fontSize: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            Canvas { context, size in
                let columns = 20
                let rows = 9
                let step = min(size.width / CGFloat(columns), size.height / CGFloat(rows))
                let filled = Int((Double(percentage ?? 0) / 100 * 14).rounded())
                var dots = Path()
                for row in 0..<rows {
                    for column in 0..<columns {
                        let outline = column <= 17 && (row == 0 || row == 8 || column == 0 || column == 17)
                        let terminal = column >= 18 && (3...5).contains(row)
                        let charge = (2...6).contains(row) && column >= 2 && column < 2 + filled
                        if outline || terminal || charge {
                            dots.addRect(CGRect(x: CGFloat(column) * step, y: CGFloat(row) * step,
                                                width: step * 0.75, height: step * 0.75))
                        }
                    }
                }
                context.fill(dots, with: .color(SceneryPlayerAppearance.display))
            }
            .frame(width: fontSize * 1.7, height: fontSize * 0.8)
            if isCharging {
                Canvas { context, size in
                    let pattern = ["000110", "001100", "011000", "111111", "000110", "001100", "011000", "010000"]
                    let step = min(size.width / 6, size.height / 8)
                    var dots = Path()
                    for (row, line) in pattern.enumerated() {
                        for (column, pixel) in line.enumerated() where pixel == "1" {
                            dots.addRect(CGRect(x: CGFloat(column) * step, y: CGFloat(row) * step,
                                                width: step * 0.8, height: step * 0.8))
                        }
                    }
                    context.fill(dots, with: .color(SceneryPlayerAppearance.display))
                }
                .frame(width: fontSize * 0.6, height: fontSize * 0.8)
            }
        }
        .foregroundStyle(SceneryPlayerAppearance.display)
        .opacity(0.75)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("電池残量")
        .accessibilityValue((percentage.map { "\($0)パーセント" } ?? "取得できません") + (isCharging ? "、充電中" : ""))
    }
}
