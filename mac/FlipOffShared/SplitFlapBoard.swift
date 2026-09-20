import SwiftUI

enum SplitFlapCharacters {
    // The order is the physical path around a real flap drum.
    static let ordered: [Character] = Array(" ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-./")

    private static let indexByCharacter = Dictionary(
        uniqueKeysWithValues: ordered.enumerated().map { ($0.element, $0.offset) }
    )

    static func index(of character: Character) -> Int {
        let normalized = String(character).uppercased().first ?? " "
        return indexByCharacter[normalized] ?? 0
    }

    static func character(at index: Int) -> Character {
        ordered[index % ordered.count]
    }

    static func nextIndex(after index: Int) -> Int {
        (index + 1) % ordered.count
    }
}

struct SplitFlapBoard: View {
    let rows: [String]
    let columns: Int
    let cellSize: CGFloat
    let gap: CGFloat

    var body: some View {
        VStack(spacing: gap) {
            ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                SplitFlapRow(
                    text: row,
                    columns: columns,
                    cellSize: cellSize,
                    gap: gap,
                    rowIndex: rowIndex
                )
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(rows.joined(separator: " "))
    }
}

private struct SplitFlapRow: View {
    let characters: [Character]
    let columns: Int
    let cellSize: CGFloat
    let gap: CGFloat
    let rowIndex: Int

    init(text: String, columns: Int, cellSize: CGFloat, gap: CGFloat, rowIndex: Int) {
        self.columns = columns
        self.cellSize = cellSize
        self.gap = gap
        self.rowIndex = rowIndex

        let source = Array(text.uppercased())
        self.characters = Array(source.prefix(columns))
            + Array(repeating: " ", count: max(0, columns - source.count))
    }

    var body: some View {
        HStack(spacing: gap) {
            ForEach(Array(characters.enumerated()), id: \.offset) { item in
                SplitFlapCell(
                    targetCharacter: item.element,
                    cellSize: cellSize,
                    cellID: rowIndex * columns + item.offset
                )
            }
        }
    }
}

struct SplitFlapCell: View {
    let targetCharacter: Character
    let cellSize: CGFloat
    let cellID: Int

    @State private var currentIndex: Int
    @State private var targetIndex: Int
    @State private var nextIndex: Int
    @State private var flapProgress: CGFloat = 1
    @State private var isAnimating = false
    @State private var animationTask: Task<Void, Never>?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(targetCharacter: Character, cellSize: CGFloat, cellID: Int) {
        self.targetCharacter = targetCharacter
        self.cellSize = cellSize
        self.cellID = cellID

        let initialIndex = SplitFlapCharacters.index(of: targetCharacter)
        _currentIndex = State(initialValue: initialIndex)
        _targetIndex = State(initialValue: initialIndex)
        _nextIndex = State(initialValue: initialIndex)
    }

    private var currentCharacter: Character {
        SplitFlapCharacters.character(at: currentIndex)
    }

    private var nextCharacter: Character {
        SplitFlapCharacters.character(at: nextIndex)
    }

    private var upperProgress: CGFloat {
        min(max(flapProgress * 2, 0), 1)
    }

    private var lowerProgress: CGFloat {
        min(max((flapProgress - 0.5) * 2, 0), 1)
    }

    var body: some View {
        ZStack {
            if isAnimating {
                // The incoming top face is behind the current upper flap.
                positionedHalf(
                    SplitFlapHalf(character: nextCharacter, section: .upper, size: cellSize),
                    alignment: .top
                )
                .zIndex(0)

                // The current lower face stays visible until the hinge changes.
                positionedHalf(
                    SplitFlapHalf(character: currentCharacter, section: .lower, size: cellSize),
                    alignment: .bottom
                )
                .zIndex(1)

                SplitFlapHalf(character: currentCharacter, section: .upper, size: cellSize)
                    .rotation3DEffect(
                        .degrees(Double(-90 * upperProgress)),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .bottom,
                        perspective: 0.62
                    )
                    .frame(width: cellSize, height: cellSize, alignment: .top)
                    .zIndex(2)

                SplitFlapHalf(character: nextCharacter, section: .lower, size: cellSize)
                    .rotation3DEffect(
                        .degrees(Double(90 * (1 - lowerProgress))),
                        axis: (x: 1, y: 0, z: 0),
                        anchor: .top,
                        perspective: 0.62
                    )
                    .frame(width: cellSize, height: cellSize, alignment: .bottom)
                    .zIndex(3)
            } else {
                positionedHalf(
                    SplitFlapHalf(character: currentCharacter, section: .upper, size: cellSize),
                    alignment: .top
                )
                positionedHalf(
                    SplitFlapHalf(character: currentCharacter, section: .lower, size: cellSize),
                    alignment: .bottom
                )
            }
        }
        .frame(width: cellSize, height: cellSize)
        .clipShape(RoundedRectangle(cornerRadius: max(3, cellSize * 0.08), style: .continuous))
        .overlay {
            Rectangle()
                .fill(Color.black.opacity(0.38))
                .frame(height: max(1, cellSize * 0.025))
        }
        .shadow(color: .black.opacity(0.16), radius: max(1, cellSize * 0.04), y: 1)
        .accessibilityHidden(true)
        .onAppear {
            requestTarget(targetCharacter)
        }
        .onChange(of: targetCharacter) { _, character in
            requestTarget(character)
        }
        .onDisappear {
            animationTask?.cancel()
        }
    }

    private func positionedHalf(_ half: SplitFlapHalf, alignment: Alignment) -> some View {
        half.frame(width: cellSize, height: cellSize, alignment: alignment)
    }

    private func requestTarget(_ character: Character) {
        targetIndex = SplitFlapCharacters.index(of: character)

        guard currentIndex != targetIndex, !isAnimating else { return }

        isAnimating = true
        animationTask = Task { @MainActor in
            await advanceUntilTarget()
        }
    }

    @MainActor
    private func advanceUntilTarget() async {
        defer {
            isAnimating = false
            flapProgress = 1
            animationTask = nil
        }

        while currentIndex != targetIndex {
            let upcomingIndex = SplitFlapCharacters.nextIndex(after: currentIndex)
            nextIndex = upcomingIndex
            flapProgress = 0

            if reduceMotion {
                currentIndex = upcomingIndex
                continue
            }

            let timingVariation = UInt64((cellID % 5) * 4_000_000)
            do {
                try await Task.sleep(nanoseconds: 8_000_000 + timingVariation)
                try Task.checkCancellation()

                withAnimation(.easeIn(duration: 0.024)) {
                    flapProgress = 0.5
                }

                try await Task.sleep(nanoseconds: 26_000_000)
                try Task.checkCancellation()

                withAnimation(.spring(response: 0.055, dampingFraction: 0.86, blendDuration: 0)) {
                    flapProgress = 1
                }

                try await Task.sleep(nanoseconds: 54_000_000)
                try Task.checkCancellation()
            } catch {
                return
            }

            currentIndex = upcomingIndex
        }
    }
}

private enum SplitFlapSection {
    case upper
    case lower
}

private struct SplitFlapHalf: View {
    let character: Character
    let section: SplitFlapSection
    let size: CGFloat

    var body: some View {
        ZStack {
            Color(red: 0.135, green: 0.14, blue: 0.145)

            Text(character == " " ? "" : String(character))
                .font(.system(size: max(12, min(34, size * 0.52)), weight: .bold, design: .monospaced))
                .foregroundStyle(.white)
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .frame(
            width: size,
            height: size / 2,
            alignment: section == .upper ? .top : .bottom
        )
        .clipped()
        .overlay(alignment: section == .upper ? .bottom : .top) {
            Rectangle()
                .fill(Color.black.opacity(0.16))
                .frame(height: max(1, size * 0.02))
        }
    }
}
