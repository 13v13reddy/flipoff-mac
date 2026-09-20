import Foundation

struct FlipOffQuote: Hashable, Identifiable, Sendable {
    let id: Int
    let lines: [String]

    var author: String {
        lines.last(where: { $0.hasPrefix("-") }) ?? ""
    }
}

enum FlipOffQuotes {
    static let all: [FlipOffQuote] = [
        FlipOffQuote(id: 0, lines: ["", "GOD IS IN", "THE DETAILS .", "- LUDWIG MIES", ""]),
        FlipOffQuote(id: 1, lines: ["", "STAY HUNGRY", "STAY FOOLISH", "- STEVE JOBS", ""]),
        FlipOffQuote(id: 2, lines: ["", "GOOD DESIGN IS", "GOOD BUSINESS", "- THOMAS WATSON", ""]),
        FlipOffQuote(id: 3, lines: ["", "LESS IS MORE", "", "- MIES VAN DER ROHE", ""]),
        FlipOffQuote(id: 4, lines: ["", "MAKE IT SIMPLE", "BUT SIGNIFICANT", "- DON DRAPER", ""]),
        FlipOffQuote(id: 5, lines: ["", "HAVE NO FEAR OF", "PERFECTION", "- SALVADOR DALI", ""])
    ]

    static let accentHexValues = [
        "00FF7F",
        "FF4D00",
        "AA00FF",
        "00AAFF",
        "00FFCC"
    ]

    static func quote(for date: Date) -> FlipOffQuote {
        let quarterHour = Int(date.timeIntervalSince1970 / (15 * 60))
        let index = ((quarterHour % all.count) + all.count) % all.count
        return all[index]
    }

    static func boardRows(for quote: FlipOffQuote, columns: Int = 22) -> [String] {
        let normalized = quote.lines.prefix(5).map { centered($0, columns: columns) }
        return normalized + Array(repeating: String(repeating: " ", count: columns), count: max(0, 5 - normalized.count))
    }

    private static func centered(_ value: String, columns: Int) -> String {
        let characters = Array(value.uppercased().prefix(columns))
        let left = max(0, (columns - characters.count) / 2)
        let right = max(0, columns - left - characters.count)
        return String(repeating: " ", count: left)
            + String(characters)
            + String(repeating: " ", count: right)
    }
}
