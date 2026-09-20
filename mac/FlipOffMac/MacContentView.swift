import Combine
import SwiftUI

struct MacContentView: View {
    @State private var quote = FlipOffQuotes.all[4]
    @State private var agentState: FlipOffAgentState?

    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    private var displayQuote: FlipOffQuote {
        agentState?.overrideQuote ?? quote
    }

    private var accentHex: String {
        agentState?.accentHex
            ?? FlipOffQuotes.accentHexValues[quote.id % FlipOffQuotes.accentHexValues.count]
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    FlipOffMacBoard(quote: displayQuote, accentHex: accentHex)
                        .frame(
                            width: min(max(proxy.size.width - 64, 640), 1_360),
                            height: min(max(proxy.size.height * 0.62, 340), 540)
                        )
                        .offset(y: -proxy.size.height * 0.125)

                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 28)
            }
        }
        .frame(minWidth: 760, minHeight: 430)
        .onReceive(timer) { date in
            let latestState = FlipOffAgentStateStore.load()
            if latestState != agentState {
                agentState = latestState
            }

            if latestState?.overrideQuote == nil && latestState?.paused != true {
                withAnimation(.easeInOut(duration: 0.25)) {
                    quote = FlipOffQuotes.all[(quote.id + 1) % FlipOffQuotes.all.count]
                }
            }
            _ = date
        }
    }
}

private struct FlipOffMacBoard: View {
    let quote: FlipOffQuote
    let accentHex: String

    private let columns = 22

    var body: some View {
        let rows = FlipOffQuotes.boardRows(for: quote, columns: columns)

        GeometryReader { proxy in
            let gap = max(3, min(6, proxy.size.width * 0.004))
            let horizontalPadding = max(22, min(38, proxy.size.width * 0.026))
            let verticalPadding: CGFloat = 22
            let headerHeight: CGFloat = 22
            let footerHeight: CGFloat = 4
            let availableTileWidth = (proxy.size.width - (horizontalPadding * 2) - (gap * 21)) / 22
            let availableTileHeight = (proxy.size.height - (verticalPadding * 2) - headerHeight - footerHeight - 42 - (gap * 4)) / 5
            let tileSize = max(14, min(availableTileWidth, availableTileHeight))
            let gridWidth = (tileSize * 22) + (gap * 21)
            let gridHeight = (tileSize * 5) + (gap * 4)
            let accent = Color(flipOffHex: accentHex)

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(accent)
                            .frame(width: 9, height: 6)
                        RoundedRectangle(cornerRadius: 2, style: .continuous)
                            .fill(accent.opacity(0.42))
                            .frame(width: 9, height: 6)
                    }

                    Spacer()

                    Text(quote.author.isEmpty ? "FLIPOFF" : String(quote.author.dropFirst()))
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.42))
                }
                .frame(height: headerHeight)

                Spacer(minLength: 14)

                VStack(spacing: gap) {
                    ForEach(rows.indices, id: \.self) { rowIndex in
                        HStack(spacing: gap) {
                            ForEach(Array(rows[rowIndex].enumerated()), id: \.offset) { item in
                                MacTile(character: item.element, size: tileSize)
                            }
                        }
                    }
                }
                .frame(width: gridWidth, height: gridHeight)

                Spacer(minLength: 14)

                Capsule()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 42, height: footerHeight)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color(red: 0.10, green: 0.105, blue: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
        }
    }
}

private struct MacTile: View {
    let character: Character
    let size: CGFloat

    var body: some View {
        Text(character == " " ? "" : String(character))
            .font(.system(size: max(11, min(32, size * 0.47)), weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(red: 0.135, green: 0.14, blue: 0.145))
            .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
            .overlay(alignment: .center) {
                Rectangle()
                    .fill(Color.black.opacity(0.32))
                    .frame(height: 1)
            }
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
