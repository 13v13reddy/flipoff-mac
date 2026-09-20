import Combine
import SwiftUI

struct MacContentView: View {
    @State private var quote = FlipOffQuotes.all[4]
    @State private var agentState: FlipOffAgentState?

    private let timer = Timer.publish(every: 4, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 22) {
                HStack(alignment: .firstTextBaseline) {
                    Text("FlipOff.")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Spacer()

                    Text("MAC PREVIEW")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(.white.opacity(0.45))
                }

                FlipOffMacBoard(quote: agentState?.overrideQuote ?? quote)

                HStack {
                    Label("Widget + screen saver included", systemImage: "sparkles")
                    Spacer()
                    Text("Quotes rotate locally")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
            }
            .padding(30)
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

        VStack(spacing: 14) {
            HStack {
                HStack(spacing: 4) {
                    Circle().fill(Color.green).frame(width: 7, height: 7)
                    Circle().fill(Color.green.opacity(0.55)).frame(width: 7, height: 7)
                }
                Spacer()
                Text(quote.author.isEmpty ? "FLIPOFF" : String(quote.author.dropFirst()))
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(.white.opacity(0.36))
            }

            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: columns),
                spacing: 4
            ) {
                ForEach(Array(rows.joined().enumerated()), id: \.offset) { _, character in
                    MacTile(character: character)
                }
            }

            Capsule()
                .fill(Color.white.opacity(0.17))
                .frame(width: 40, height: 4)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background(Color(red: 0.10, green: 0.10, blue: 0.10))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        }
    }
}

private struct MacTile: View {
    let character: Character

    var body: some View {
        Text(character == " " ? "" : String(character))
            .font(.system(size: 18, weight: .bold, design: .monospaced))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .aspectRatio(1.12, contentMode: .fit)
            .background(Color(red: 0.13, green: 0.13, blue: 0.13))
            .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
            .overlay {
                Rectangle()
                    .fill(Color.black.opacity(0.35))
                    .frame(height: 1)
            }
    }
}
