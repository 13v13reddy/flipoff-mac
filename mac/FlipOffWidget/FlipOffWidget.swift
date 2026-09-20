import SwiftUI
import WidgetKit

struct FlipOffWidgetEntry: TimelineEntry {
    let date: Date
    let quote: FlipOffQuote
    let accentHex: String
}

struct FlipOffWidgetProvider: TimelineProvider {
    func placeholder(in context: Context) -> FlipOffWidgetEntry {
        FlipOffWidgetEntry(date: .now, quote: FlipOffQuotes.all[4], accentHex: FlipOffQuotes.accentHexValues[0])
    }

    func getSnapshot(in context: Context, completion: @escaping (FlipOffWidgetEntry) -> Void) {
        completion(placeholder(in: context))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<FlipOffWidgetEntry>) -> Void) {
        let now = Date()
        let agentState = FlipOffAgentStateStore.load()
        let entries = (0..<12).compactMap { offset -> FlipOffWidgetEntry? in
            guard let date = Calendar.current.date(byAdding: .minute, value: offset * 15, to: now) else {
                return nil
            }
            let quote: FlipOffQuote
            if let override = agentState?.overrideQuote {
                quote = override
            } else if agentState?.paused == true {
                quote = FlipOffQuotes.quote(for: now)
            } else {
                quote = FlipOffQuotes.quote(for: date)
            }
            let accentHex = agentState?.accentHex ?? FlipOffQuotes.accentHexValues[offset % FlipOffQuotes.accentHexValues.count]
            return FlipOffWidgetEntry(date: date, quote: quote, accentHex: accentHex)
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct FlipOffWidget: Widget {
    let kind = "FlipOffWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: FlipOffWidgetProvider()) { entry in
            FlipOffWidgetView(entry: entry)
        }
        .configurationDisplayName("FlipOff")
        .description("A quiet split-flap quote for your desktop.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}

struct FlipOffWidgetView: View {
    @Environment(\.widgetFamily) private var family

    let entry: FlipOffWidgetEntry

    private var columns: Int {
        family == .systemSmall ? 12 : 22
    }

    private var rowCount: Int {
        family == .systemSmall ? 3 : 5
    }

    var body: some View {
        VStack(alignment: .leading, spacing: family == .systemSmall ? 7 : 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("FlipOff.")
                    .font(.system(size: family == .systemSmall ? 12 : 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 4)

                HStack(spacing: 3) {
                    Circle().fill(Color.green).frame(width: 5, height: 5)
                    Circle().fill(Color.green.opacity(0.5)).frame(width: 5, height: 5)
                }
            }

            FlipOffWidgetBoard(
                quote: entry.quote,
                columns: columns,
                rowCount: rowCount,
                compact: family == .systemSmall,
                accentHex: entry.accentHex
            )

            if family != .systemSmall {
                HStack(spacing: 6) {
                    Text(entry.quote.author)
                        .lineLimit(1)
                    Spacer()
                    Text("LOCAL")
                        .tracking(1)
                }
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.42))
            }
        }
        .padding(family == .systemSmall ? 10 : 14)
        .containerBackground(for: .widget) {
            Color(red: 0.065, green: 0.065, blue: 0.065)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("FlipOff quote: \(entry.quote.lines.filter { !$0.isEmpty }.joined(separator: " "))")
    }
}

private struct FlipOffWidgetBoard: View {
    let quote: FlipOffQuote
    let columns: Int
    let rowCount: Int
    let compact: Bool
    let accentHex: String

    var body: some View {
        let rows = Array(FlipOffQuotes.boardRows(for: quote, columns: columns).prefix(rowCount))

        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: compact ? 2 : 3), count: columns),
            spacing: compact ? 2 : 3
        ) {
            ForEach(Array(rows.joined().enumerated()), id: \.offset) { _, character in
                FlipOffWidgetTile(character: character)
            }
        }
        .padding(compact ? 5 : 7)
        .background(Color(red: 0.105, green: 0.105, blue: 0.105))
        .clipShape(RoundedRectangle(cornerRadius: compact ? 7 : 9, style: .continuous))
        .overlay(alignment: .topLeading) {
            Capsule()
                .fill(Color(flipOffHex: accentHex))
                .frame(width: compact ? 16 : 24, height: 3)
                .padding(compact ? 5 : 7)
        }
    }
}

private struct FlipOffWidgetTile: View {
    let character: Character

    var body: some View {
        Text(character == " " ? "" : String(character))
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .minimumScaleFactor(0.5)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .aspectRatio(1.18, contentMode: .fit)
            .background(Color(red: 0.135, green: 0.135, blue: 0.135))
            .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
            .overlay {
                Rectangle()
                    .fill(Color.black.opacity(0.32))
                    .frame(height: 0.5)
            }
    }
}

private extension Color {
    init(flipOffHex hex: String) {
        let value = UInt64(hex.trimmingCharacters(in: CharacterSet(charactersIn: "#")), radix: 16) ?? 0x00FF7F
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

@main
struct FlipOffWidgetBundle: WidgetBundle {
    var body: some Widget {
        FlipOffWidget()
    }
}
