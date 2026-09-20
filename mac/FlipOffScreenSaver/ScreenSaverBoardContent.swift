import SwiftUI

struct FlipOffScreenSaverContent: View {
    let quote: FlipOffQuote
    let accentHex: String

    private let columns = 22

    var body: some View {
        GeometryReader { proxy in
            let boardWidth = min(max(proxy.size.width - 72, 0), 1_560)
            let boardHeight = min(max(proxy.size.height * 0.58, 280), 620)
            let gap = max(3, min(6, boardWidth * 0.004))
            let horizontalPadding = max(16, min(28, boardWidth * 0.022))
            let verticalPadding: CGFloat = 14
            let headerHeight: CGFloat = 18
            let footerHeight: CGFloat = 3
            let availableTileWidth = (boardWidth - (horizontalPadding * 2) - (gap * 21)) / 22
            let availableTileHeight = (boardHeight - (verticalPadding * 2) - headerHeight - footerHeight - 16 - (gap * 4)) / 5
            let tileSize = max(14, min(availableTileWidth, availableTileHeight))
            let gridWidth = (tileSize * 22) + (gap * 21)
            let gridHeight = (tileSize * 5) + (gap * 4)
            let accent = Color(flipOffHex: accentHex)
            let rows = FlipOffQuotes.boardRows(for: quote, columns: columns)
            let author = quote.author.isEmpty ? "FLIPOFF" : String(quote.author.dropFirst())

            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    VStack(spacing: 0) {
                        HStack {
                            Spacer()

                            Text(author)
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .tracking(1.1)
                                .foregroundStyle(.white.opacity(0.42))
                        }
                        .frame(height: headerHeight)

                        Spacer(minLength: 8)

                        SplitFlapBoard(
                            rows: rows,
                            columns: columns,
                            cellSize: tileSize,
                            gap: gap
                        )
                        .frame(width: gridWidth, height: gridHeight)

                        Spacer(minLength: 8)

                        Capsule()
                            .fill(accent.opacity(0.34))
                            .frame(width: 36, height: footerHeight)
                    }
                    .padding(.horizontal, horizontalPadding)
                    .padding(.vertical, verticalPadding)
                    .background(Color(red: 0.10, green: 0.105, blue: 0.11))
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
                    .frame(width: boardWidth, height: boardHeight)
                    .offset(y: -proxy.size.height * 0.12)

                    Spacer(minLength: 24)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(quote.lines.joined(separator: " "))
    }
}

private extension Color {
    init(flipOffHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255,
            opacity: 1
        )
    }
}
