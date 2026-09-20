import AppKit
import ScreenSaver
import SwiftUI

final class FlipOffScreenSaverView: ScreenSaverView {
    private let quoteDuration: TimeInterval = 8

    private var currentQuoteIndex = 4
    private var currentQuote = FlipOffQuotes.all[4]
    private var agentState: FlipOffAgentState?
    private var agentStateSignature = ""
    private var lastStateCheck = Date.distantPast
    private var elapsed: TimeInterval = 0
    private var previousFrameDate = Date()
    private var hostingView: NSHostingView<FlipOffScreenSaverContent>?

    override init?(frame: NSRect, isPreview: Bool) {
        super.init(frame: frame, isPreview: isPreview)
        animationTimeInterval = 1.0 / 30.0
        installHostingView()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        animationTimeInterval = 1.0 / 30.0
        installHostingView()
    }

    override func startAnimation() {
        super.startAnimation()
        previousFrameDate = Date()
        refreshAgentStateIfNeeded(at: previousFrameDate)
        updateHostedView()
    }

    override func animateOneFrame() {
        let now = Date()
        refreshAgentStateIfNeeded(at: now)
        guard agentState?.paused != true else { return }

        let delta = min(now.timeIntervalSince(previousFrameDate), 0.2)
        previousFrameDate = now
        elapsed += delta

        let activeQuoteDuration = max(6, agentState?.rotationSeconds ?? quoteDuration)
        guard elapsed >= activeQuoteDuration else { return }

        if agentState?.overrideQuote != nil {
            elapsed = 0
            return
        }

        currentQuoteIndex = (currentQuoteIndex + 1) % FlipOffQuotes.all.count
        currentQuote = FlipOffQuotes.all[currentQuoteIndex]
        elapsed = 0
        updateHostedView()
    }

    override func draw(_ rect: NSRect) {
        NSColor.black.setFill()
        rect.fill()
    }

    override func layout() {
        super.layout()
        hostingView?.frame = bounds
    }

    private var accentHex: String {
        if let accent = agentState?.accentHex, !accent.isEmpty {
            return accent
        }

        let index = max(0, currentQuote.id) % FlipOffQuotes.accentHexValues.count
        return FlipOffQuotes.accentHexValues[index]
    }

    private func installHostingView() {
        let hosted = NSHostingView(
            rootView: FlipOffScreenSaverContent(quote: currentQuote, accentHex: accentHex)
        )
        hosted.frame = bounds
        hosted.autoresizingMask = [.width, .height]
        addSubview(hosted)
        hostingView = hosted
    }

    private func updateHostedView() {
        hostingView?.rootView = FlipOffScreenSaverContent(quote: currentQuote, accentHex: accentHex)
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
        } else {
            currentQuote = FlipOffQuotes.all[currentQuoteIndex]
        }
        elapsed = 0
        updateHostedView()
    }
}
