import AppKit
import ScreenSaver

final class FlipOffScreenSaverView: ScreenSaverView {
    private let quoteDuration: TimeInterval = 4
    private let transitionDuration: TimeInterval = 1.25
    private let columns = 22
    private let rows = 5

    private var currentQuoteIndex = 4
    private var nextQuoteIndex = 5
    private var currentQuote = FlipOffQuotes.all[4]
    private var nextQuote = FlipOffQuotes.all[5]
    private var agentState: FlipOffAgentState?
    private var agentStateSignature = ""
    private var lastStateCheck = Date.distantPast
    private var elapsed: TimeInterval = 0
    private var previousFrameDate = Date()

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 30.0
    }

    override func startAnimation() {
        super.startAnimation()
        previousFrameDate = Date()
    }

    override func animateOneFrame() {
        let now = Date()
        refreshAgentStateIfNeeded(at: now)
        if agentState?.paused == true {
            needsDisplay = true
            return
        }

        let delta = min(now.timeIntervalSince(previousFrameDate), 0.2)
        previousFrameDate = now
        elapsed += delta

        let activeQuoteDuration = max(2, agentState?.rotationSeconds ?? quoteDuration)
        if elapsed >= activeQuoteDuration + transitionDuration {
            if agentState?.overrideQuote != nil {
                elapsed = 0
                needsDisplay = true
                return
            }
            currentQuoteIndex = nextQuoteIndex
            nextQuoteIndex = (nextQuoteIndex + 1) % FlipOffQuotes.all.count
            currentQuote = FlipOffQuotes.all[currentQuoteIndex]
            nextQuote = FlipOffQuotes.all[nextQuoteIndex]
            elapsed = 0
        }

        needsDisplay = true
    }

    override func draw(_ rect: NSRect) {
        super.draw(rect)

        NSColor(calibratedWhite: 0.015, alpha: 1).setFill()
        rect.fill()

        let board = boardRect(in: rect)
        drawBoard(in: board)
        drawHeader(in: board)
        drawTiles(in: board)
        drawFooter(in: board)
    }

    private func boardRect(in rect: NSRect) -> NSRect {
        let horizontalInset = max(24, rect.width * 0.075)
        let width = min(rect.width - horizontalInset * 2, 1180)
        let height = min(rect.height * 0.64, 420)
        return NSRect(
            x: (rect.width - width) / 2,
            y: (rect.height - height) / 2 + rect.height * 0.02,
            width: width,
            height: height
        )
    }

    private func drawBoard(in board: NSRect) {
        let path = NSBezierPath(roundedRect: board, xRadius: 18, yRadius: 18)
        NSColor(calibratedWhite: 0.10, alpha: 1).setFill()
        path.fill()

        NSColor(calibratedWhite: 1, alpha: 0.07).setStroke()
        path.lineWidth = 1
        path.stroke()

        let accentHex = agentState?.accentHex ?? FlipOffQuotes.accentHexValues[currentQuoteIndex % FlipOffQuotes.accentHexValues.count]
        let accentColor = color(forHex: accentHex)
        accentColor.setFill()
        let leftAccent = NSRect(x: board.minX + 18, y: board.maxY - 38, width: 12, height: 12)
        let rightAccent = NSRect(x: board.maxX - 30, y: board.maxY - 38, width: 12, height: 12)
        NSBezierPath(roundedRect: leftAccent, xRadius: 2, yRadius: 2).fill()
        NSBezierPath(roundedRect: rightAccent, xRadius: 2, yRadius: 2).fill()
        accentColor.withAlphaComponent(0.5).setFill()
        NSBezierPath(roundedRect: leftAccent.offsetBy(dx: 0, dy: -16), xRadius: 2, yRadius: 2).fill()
        NSBezierPath(roundedRect: rightAccent.offsetBy(dx: 0, dy: -16), xRadius: 2, yRadius: 2).fill()
    }

    private func drawHeader(in board: NSRect) {
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: max(12, board.height * 0.045), weight: .bold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.92)
        ]
        NSString(string: "FlipOff.").draw(
            at: NSPoint(x: board.minX + 44, y: board.maxY - 34),
            withAttributes: attributes
        )

        let statusAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: max(8, board.height * 0.026), weight: .semibold),
            .foregroundColor: NSColor.white.withAlphaComponent(0.35)
        ]
        NSString(string: "LOCAL / QUIET MODE").draw(
            at: NSPoint(x: board.maxX - 142, y: board.maxY - 31),
            withAttributes: statusAttributes
        )
    }

    private func drawTiles(in board: NSRect) {
        let gap = max(2, min(5, board.width * 0.004))
        let horizontalPadding = max(18, board.width * 0.04)
        let headerHeight = max(48, board.height * 0.19)
        let footerHeight = max(26, board.height * 0.12)
        let tileWidth = (board.width - horizontalPadding * 2 - CGFloat(columns - 1) * gap) / CGFloat(columns)
        let tileHeight = min(tileWidth * 0.92, (board.height - headerHeight - footerHeight - CGFloat(rows - 1) * gap) / CGFloat(rows))
        let gridWidth = CGFloat(columns) * tileWidth + CGFloat(columns - 1) * gap
        let gridHeight = CGFloat(rows) * tileHeight + CGFloat(rows - 1) * gap
        let originX = board.midX - gridWidth / 2
        let originY = board.minY + footerHeight + (board.height - headerHeight - footerHeight - gridHeight) / 2

        let currentRows = FlipOffQuotes.boardRows(for: currentQuote, columns: columns)
        let nextRows = FlipOffQuotes.boardRows(for: nextQuote, columns: columns)
        let activeQuoteDuration = max(2, agentState?.rotationSeconds ?? quoteDuration)
        let transition = max(0, min(1, (elapsed - activeQuoteDuration) / transitionDuration))

        for row in 0..<rows {
            let currentCharacters = Array(currentRows[row])
            let nextCharacters = Array(nextRows[row])

            for column in 0..<columns {
                let x = originX + CGFloat(column) * (tileWidth + gap)
                let y = originY + CGFloat(rows - row - 1) * (tileHeight + gap)
                let tile = NSRect(x: x, y: y, width: tileWidth, height: tileHeight)
                let tileIndex = row * columns + column
                let delay = CGFloat(tileIndex % 9) * 0.018
                let progress = max(0, min(1, (CGFloat(transition) - delay) / 0.82))
                drawTile(
                    in: tile,
                    current: currentCharacters[column],
                    next: nextCharacters[column],
                    progress: progress,
                    accentIndex: tileIndex
                )
            }
        }
    }

    private func drawTile(in tile: NSRect, current: Character, next: Character, progress: CGFloat, accentIndex: Int) {
        NSColor(calibratedWhite: 0.055, alpha: 1).setFill()
        NSBezierPath(roundedRect: tile, xRadius: 3, yRadius: 3).fill()

        let showingNext = progress >= 0.5
        let character = showingNext ? next : current
        let angleProgress = showingNext ? (progress - 0.5) * 2 : progress * 2
        let faceScale = max(0.08, sin(angleProgress * .pi / 2))
        let faceHeight = max(1, tile.height * faceScale)
        let face = NSRect(x: tile.minX, y: tile.midY - faceHeight / 2, width: tile.width, height: faceHeight)

        let background: NSColor
        if progress > 0.04 && progress < 0.96 {
            background = color(forHex: FlipOffQuotes.accentHexValues[accentIndex % FlipOffQuotes.accentHexValues.count])
        } else {
            background = NSColor(calibratedWhite: 0.13, alpha: 1)
        }
        background.setFill()
        NSBezierPath(roundedRect: face, xRadius: 2, yRadius: 2).fill()

        NSGraphicsContext.current?.saveGraphicsState()
        NSBezierPath(rect: face).addClip()
        let fontSize = min(tile.width * 0.58, tile.height * 0.58)
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: max(6, fontSize), weight: .bold),
            .foregroundColor: NSColor.white
        ]
        let string = character == " " ? "" : String(character)
        let size = NSString(string: string).size(withAttributes: attributes)
        NSString(string: string).draw(
            at: NSPoint(x: face.midX - size.width / 2, y: face.midY - size.height / 2),
            withAttributes: attributes
        )
        NSGraphicsContext.current?.restoreGraphicsState()

        NSColor.black.withAlphaComponent(0.4).setFill()
        NSRect(x: tile.minX, y: tile.midY - 0.5, width: tile.width, height: 1).fill()
    }

    private func drawFooter(in board: NSRect) {
        let line = NSBezierPath()
        line.move(to: NSPoint(x: board.midX - 20, y: board.minY + 16))
        line.line(to: NSPoint(x: board.midX + 20, y: board.minY + 16))
        line.lineWidth = 4
        line.lineCapStyle = .round
        NSColor.white.withAlphaComponent(0.16).setStroke()
        line.stroke()
    }

    private func color(forHex hex: String) -> NSColor {
        var value: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&value)
        return NSColor(
            calibratedRed: CGFloat((value >> 16) & 0xFF) / 255,
            green: CGFloat((value >> 8) & 0xFF) / 255,
            blue: CGFloat(value & 0xFF) / 255,
            alpha: 1
        )
    }

    private func refreshAgentStateIfNeeded(at date: Date) {
        guard date.timeIntervalSince(lastStateCheck) >= 0.5 else { return }
        lastStateCheck = date

        let latest = FlipOffAgentStateStore.load()
        let signature = [
            latest?.message ?? "",
            latest?.author ?? "",
            latest?.paused.description ?? "false",
            String(latest?.rotationSeconds ?? quoteDuration),
            latest?.accentHex ?? ""
        ].joined(separator: "|")
        guard signature != agentStateSignature else { return }

        agentStateSignature = signature
        agentState = latest
        if let override = latest?.overrideQuote {
            currentQuote = override
            nextQuote = override
        } else {
            currentQuote = FlipOffQuotes.all[currentQuoteIndex]
            nextQuote = FlipOffQuotes.all[nextQuoteIndex]
        }
        elapsed = 0
        needsDisplay = true
    }
}
