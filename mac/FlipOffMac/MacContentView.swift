import Combine
import SwiftUI

struct MacContentView: View {
    @State private var quote = FlipOffQuotes.all[4]
    @State private var agentState: FlipOffAgentState?

    private let timer = Timer.publish(every: 8, on: .main, in: .common).autoconnect()

    private var displayQuote: FlipOffQuote {
        agentState?.overrideQuote ?? quote
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    Spacer(minLength: 24)

                    FlipOffMacBoard(quote: displayQuote)
                        .frame(
                            width: min(max(proxy.size.width - 40, 640), 1_440),
                            height: min(max(proxy.size.height * 0.52, 300), 420)
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

    private let columns = 22

    var body: some View {
        let rows = FlipOffQuotes.boardRows(for: quote, columns: columns)

        GeometryReader { proxy in
            let gap = max(3, min(6, proxy.size.width * 0.004))
            let horizontalPadding = max(16, min(28, proxy.size.width * 0.022))
            let verticalPadding: CGFloat = 14
            let headerHeight: CGFloat = 18
            let footerHeight: CGFloat = 3
            let availableTileWidth = (proxy.size.width - (horizontalPadding * 2) - (gap * 21)) / 22
            let availableTileHeight = (proxy.size.height - (verticalPadding * 2) - headerHeight - footerHeight - 16 - (gap * 4)) / 5
            let tileSize = max(14, min(availableTileWidth, availableTileHeight))
            let gridWidth = (tileSize * 22) + (gap * 21)
            let gridHeight = (tileSize * 5) + (gap * 4)
            let author = quote.author.isEmpty ? "" : String(quote.author.dropFirst())

            VStack(spacing: 0) {
                HStack(alignment: .center) {
                    Spacer()

                    if !author.isEmpty {
                        Text(author)
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .tracking(1.1)
                            .foregroundStyle(.white.opacity(0.42))
                    }
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
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 36, height: footerHeight)
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, verticalPadding)
            .background(Color(red: 0.10, green: 0.105, blue: 0.11))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.28), radius: 14, y: 8)
        }
    }
}
