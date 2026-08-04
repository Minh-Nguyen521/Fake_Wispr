import AppKit

class RecordingOverlay {
    private var panel: NSPanel?

    func show(hotkey: String) {
        DispatchQueue.main.async {
            if self.panel == nil { self.buildPanel() }
            self.repositionPanel()
            self.updateHotkey(hotkey)
            (self.panel?.contentView as? OverlayContentView)?.startPulse()
            self.panel?.orderFrontRegardless()
        }
    }

    func hide() {
        DispatchQueue.main.async {
            (self.panel?.contentView as? OverlayContentView)?.stopPulse()
            self.panel?.orderOut(nil)
        }
    }

    // MARK: - Build

    private func buildPanel() {
        let width: CGFloat = 260
        let height: CGFloat = 92

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        p.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.screenSaverWindow)) - 1)
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        p.isMovableByWindowBackground = false
        p.contentView = OverlayContentView(frame: NSRect(origin: .zero, size: CGSize(width: width, height: height)))

        self.panel = p
    }

    private func repositionPanel() {
        guard let panel else { return }
        let width = panel.frame.width
        let mouseLocation = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouseLocation, $0.frame, false) })
            ?? NSScreen.main
            ?? NSScreen.screens[0]
        let x = screen.frame.midX - width / 2
        let y = screen.visibleFrame.minY + 24
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func updateHotkey(_ hotkey: String) {
        (panel?.contentView as? OverlayContentView)?.hotkeyLabel.stringValue = hotkey
    }
}

// MARK: - OverlayContentView

private class OverlayContentView: NSView {
    let hotkeyLabel = NSTextField(labelWithString: "")
    private let micPill = NSView()
    private let micIcon = NSImageView()
    private var pulseTimer: Timer?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        // Hotkey pill (top)
        let hotkeyPill = NSView()
        hotkeyPill.wantsLayer = true
        hotkeyPill.layer?.backgroundColor = NSColor(white: 0.15, alpha: 0.95).cgColor
        hotkeyPill.layer?.cornerRadius = 12
        hotkeyPill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hotkeyPill)

        hotkeyLabel.font = .systemFont(ofSize: 13, weight: .medium)
        hotkeyLabel.textColor = .white
        hotkeyLabel.alignment = .center
        hotkeyLabel.translatesAutoresizingMaskIntoConstraints = false
        hotkeyPill.addSubview(hotkeyLabel)

        // Mic pill (bottom)
        micPill.wantsLayer = true
        micPill.layer?.backgroundColor = NSColor(white: 0.22, alpha: 0.95).cgColor
        micPill.layer?.cornerRadius = 22
        micPill.translatesAutoresizingMaskIntoConstraints = false
        addSubview(micPill)

        let micImg = NSImage(systemSymbolName: "mic.fill", accessibilityDescription: nil)
        micIcon.image = micImg
        micIcon.contentTintColor = .white
        micIcon.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 20, weight: .medium)
        micIcon.translatesAutoresizingMaskIntoConstraints = false
        micPill.addSubview(micIcon)

        NSLayoutConstraint.activate([
            // hotkey pill
            hotkeyPill.topAnchor.constraint(equalTo: topAnchor, constant: 8),
            hotkeyPill.centerXAnchor.constraint(equalTo: centerXAnchor),
            hotkeyPill.heightAnchor.constraint(equalToConstant: 32),

            hotkeyLabel.leadingAnchor.constraint(equalTo: hotkeyPill.leadingAnchor, constant: 16),
            hotkeyLabel.trailingAnchor.constraint(equalTo: hotkeyPill.trailingAnchor, constant: -16),
            hotkeyLabel.centerYAnchor.constraint(equalTo: hotkeyPill.centerYAnchor),

            // mic pill
            micPill.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -8),
            micPill.centerXAnchor.constraint(equalTo: centerXAnchor),
            micPill.widthAnchor.constraint(equalToConstant: 52),
            micPill.heightAnchor.constraint(equalToConstant: 36),

            micIcon.centerXAnchor.constraint(equalTo: micPill.centerXAnchor),
            micIcon.centerYAnchor.constraint(equalTo: micPill.centerYAnchor),
        ])

    }

    fileprivate func startPulse() {
        guard pulseTimer == nil else { return }
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            guard let self else { return }
            NSAnimationContext.runAnimationGroup({ ctx in
                ctx.duration = 0.4
                self.micPill.layer?.backgroundColor = NSColor(white: 0.38, alpha: 0.95).cgColor
            }, completionHandler: {
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.4
                    self.micPill.layer?.backgroundColor = NSColor(white: 0.22, alpha: 0.95).cgColor
                }
            })
        }
    }

    fileprivate func stopPulse() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        micPill.layer?.backgroundColor = NSColor(white: 0.22, alpha: 0.95).cgColor
    }

    deinit { pulseTimer?.invalidate() }
}
