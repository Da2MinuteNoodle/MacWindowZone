import AppKit

/// Named highlight/zone color pairs offered in the customizer.
/// Opacity is left alone so picking a scheme doesn't throw away a tuned slider.
private struct OverlayColorPreset {
    let name: String
    let toolTip: String
    let highlightSystem: Bool
    let highlight: (Double, Double, Double)
    let zoneSystem: Bool
    let zone: (Double, Double, Double)

    static let all: [OverlayColorPreset] = [
        OverlayColorPreset(
            name: "Default",
            toolTip: "System blue highlight and teal zones",
            highlightSystem: true, highlight: (0, 0, 0),
            zoneSystem: true, zone: (0, 0, 0)
        ),
        OverlayColorPreset(
            name: "Ocean",
            toolTip: "Blue highlight and cyan zones",
            highlightSystem: false, highlight: (0.00, 0.48, 1.00),
            zoneSystem: false, zone: (0.10, 0.78, 0.86)
        ),
        OverlayColorPreset(
            name: "Forest",
            toolTip: "Green highlight and lighter green zones",
            highlightSystem: false, highlight: (0.18, 0.78, 0.38),
            zoneSystem: false, zone: (0.48, 0.82, 0.42)
        ),
        OverlayColorPreset(
            name: "Sunset",
            toolTip: "Orange highlight and red zones",
            highlightSystem: false, highlight: (1.00, 0.58, 0.10),
            zoneSystem: false, zone: (0.96, 0.34, 0.28)
        ),
        OverlayColorPreset(
            name: "Grape",
            toolTip: "Purple highlight and indigo zones",
            highlightSystem: false, highlight: (0.70, 0.36, 0.98),
            zoneSystem: false, zone: (0.48, 0.42, 0.92)
        ),
        OverlayColorPreset(
            name: "Rose",
            toolTip: "Pink highlight and coral zones",
            highlightSystem: false, highlight: (1.00, 0.28, 0.46),
            zoneSystem: false, zone: (0.98, 0.52, 0.58)
        ),
        OverlayColorPreset(
            name: "Slate",
            toolTip: "Neutral gray highlight and zones",
            highlightSystem: false, highlight: (0.86, 0.89, 0.93),
            zoneSystem: false, zone: (0.62, 0.66, 0.72)
        )
    ]
}

/// Menu-bar panel for the snap overlay's colors and opacity.
final class OverlayCustomizer {
    static let shared = OverlayCustomizer()

    private var window: OverlayCustomizerWindow?
    private var savedShowsAlpha = false

    private init() {}

    func show() {
        if window == nil {
            savedShowsAlpha = NSColorPanel.shared.showsAlpha
            // Opacity has its own sliders. Hide the color panel's alpha so the
            // two controls don't fight over the same channel.
            NSColorPanel.shared.showsAlpha = false
            window = OverlayCustomizerWindow(content: OverlayCustomizerView())
        }
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    fileprivate func closeCleanup() {
        NSColorPanel.shared.showsAlpha = savedShowsAlpha
        if NSColorPanel.shared.isVisible {
            NSColorPanel.shared.orderOut(nil)
        }
        window = nil
    }
}

/// Convenience init only — see `ZoneEditorWindow` for why a custom designated
/// init on NSWindow traps inside AppKit.
final class OverlayCustomizerWindow: NSWindow, NSWindowDelegate {

    convenience init(content: NSView) {
        self.init(
            contentRect: NSRect(origin: .zero, size: content.frame.size),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        title = "Customize Overlay"
        isReleasedWhenClosed = false
        level = .floating
        delegate = self
        contentView = content
        center()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Escape dismisses. Return is the Done button's key equivalent.
        if event.keyCode == 53 {
            close()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    func windowWillClose(_ notification: Notification) {
        OverlayCustomizer.shared.closeCleanup()
    }
}

/// Miniature of the snap overlay: one highlighted cell, three idle cells,
/// drawn with the same fill, stroke, and opacity as the real overlay.
private final class OverlayPreviewView: NSView {

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 10
        layer?.masksToBounds = true
        layer?.borderWidth = 1
        layer?.borderColor = NSColor.separatorColor.cgColor
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.borderColor = NSColor.separatorColor.cgColor
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let clip = NSBezierPath(roundedRect: bounds, xRadius: 10, yRadius: 10)
        clip.addClip()

        NSGradient(colors: [
            NSColor(srgbRed: 0.13, green: 0.18, blue: 0.29, alpha: 1),
            NSColor(srgbRed: 0.36, green: 0.24, blue: 0.22, alpha: 1)
        ])?.draw(in: bounds, angle: 18)

        let windowRect = NSRect(
            x: bounds.width * 0.16,
            y: bounds.height * 0.18,
            width: bounds.width * 0.42,
            height: bounds.height * 0.46
        )
        NSColor(srgbRed: 0.94, green: 0.95, blue: 0.97, alpha: 0.96).setFill()
        NSBezierPath(roundedRect: windowRect, xRadius: 8, yRadius: 8).fill()
        let dots: [NSColor] = [.systemRed, .systemYellow, .systemGreen]
        for (index, dot) in dots.enumerated() {
            dot.setFill()
            NSBezierPath(ovalIn: NSRect(
                x: windowRect.minX + 10 + CGFloat(index) * 14,
                y: windowRect.maxY - 16,
                width: 8,
                height: 8
            )).fill()
        }
        NSColor(srgbRed: 0.78, green: 0.80, blue: 0.84, alpha: 1).setFill()
        for index in 0..<3 {
            let line = NSRect(
                x: windowRect.minX + 12,
                y: windowRect.minY + 16 + CGFloat(index) * 16,
                width: windowRect.width * (0.72 - CGFloat(index) * 0.12),
                height: 6
            )
            NSBezierPath(roundedRect: line, xRadius: 3, yRadius: 3).fill()
        }

        let palette = Settings.shared.overlayPalette
        let margin: CGFloat = 10
        let gap: CGFloat = 4
        let cellW = (bounds.width - margin * 2 - gap) / 2
        let cellH = (bounds.height - margin * 2 - gap) / 2
        let scale = min(1, max(0.35, min(cellW, cellH) / 320))
        for index in 0..<4 {
            let column = CGFloat(index % 2)
            let rowFromTop = CGFloat(index / 2)
            let rect = NSRect(
                x: margin + column * (cellW + gap),
                y: bounds.height - margin - cellH - rowFromTop * (cellH + gap),
                width: cellW,
                height: cellH
            )
            palette.drawZone(in: rect, active: index == 1, scale: scale)
        }
    }
}

private final class OverlayCustomizerView: NSView {
    private let preview = OverlayPreviewView(frame: .zero)
    private let highlightWell = NSColorWell()
    private let zoneWell = NSColorWell()
    private let highlightSlider = NSSlider()
    private let zoneSlider = NSSlider()
    private let borderSlider = NSSlider()
    private let highlightPercent = NSTextField(labelWithString: "")
    private let zonePercent = NSTextField(labelWithString: "")
    private let borderPercent = NSTextField(labelWithString: "")
    private var presetButtons: [NSButton] = []
    private var updatingUI = false
    private var isReady = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        build()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        guard isReady else { return }
        syncControls()
    }

    private func build() {
        let width: CGFloat = 460
        let margin: CGFloat = 20
        let inner = width - margin * 2

        configure(well: highlightWell, action: #selector(highlightColorChanged(_:)), tip: "Color of the zone you are about to snap to, and of edge-snap previews")
        configure(well: zoneWell, action: #selector(zoneColorChanged(_:)), tip: "Color of the other zones while the drag modifier is held")
        configure(slider: highlightSlider, action: #selector(highlightOpacityChanged(_:)), tip: "How solid the highlight is")
        configure(slider: zoneSlider, action: #selector(zoneOpacityChanged(_:)), tip: "How solid the other zones are")
        configure(slider: borderSlider, action: #selector(borderOpacityChanged(_:)), tip: "How solid the border around each zone is")
        for label in [highlightPercent, zonePercent, borderPercent] {
            label.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            label.alignment = .right
        }

        var rows: [(NSView, CGFloat, CGFloat)] = []

        let intro = wrappingLabel(
            "Colors and opacity for the overlay that appears when you snap a window to a screen edge, or hold the drag modifier to pick zones.",
            size: 12,
            width: inner
        )
        rows.append((intro, intro.frame.height, 12))
        rows.append((sectionLabel("Preview"), 18, 6))
        rows.append((preview, 176, 6))
        let caption = wrappingLabel(
            "The bright cell is the highlight — the zone under your cursor, a multi-zone selection, or an edge snap. The dimmer cells show while the drag modifier is held.",
            size: 11,
            width: inner
        )
        rows.append((caption, caption.frame.height, 14))
        rows.append((sectionLabel("Color scheme"), 18, 6))

        let presets = makePresetGrid(width: inner)
        rows.append((presets, presets.frame.height, 16))
        rows.append((
            makeSliderRow(title: "Highlight", well: highlightWell, slider: highlightSlider, percent: highlightPercent, width: inner),
            32, 10
        ))
        rows.append((
            makeSliderRow(title: "Other zones", well: zoneWell, slider: zoneSlider, percent: zonePercent, width: inner),
            32, 10
        ))
        rows.append((
            makeSliderRow(title: "Outline opacity", well: nil, slider: borderSlider, percent: borderPercent, width: inner),
            32, 18
        ))
        rows.append((makeButtonBar(width: inner), 32, 0))

        let body = rows.reduce(CGFloat(0)) { $0 + $1.1 + $1.2 }
        let total = margin + body + margin
        var y = total - margin
        for (view, height, gap) in rows {
            y -= height
            view.frame = NSRect(x: margin, y: y, width: inner, height: height)
            addSubview(view)
            y -= gap
        }
        setFrameSize(NSSize(width: width, height: total))
        syncControls()
        isReady = true
    }

    private func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        return label
    }

    private func wrappingLabel(_ text: String, size: CGFloat, width: CGFloat) -> NSTextField {
        let font = NSFont.systemFont(ofSize: size)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        let bounds = NSAttributedString(string: text, attributes: [
            .font: font,
            .paragraphStyle: style
        ]).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        let label = NSTextField(wrappingLabelWithString: text)
        label.font = font
        label.textColor = .secondaryLabelColor
        label.maximumNumberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.cell?.wraps = true
        label.cell?.isScrollable = false
        label.preferredMaxLayoutWidth = width
        // sizeToFit grows the width instead of wrapping, so the height is measured above.
        label.frame = NSRect(x: 0, y: 0, width: width, height: ceil(bounds.height) + 4)
        return label
    }

    private func configure(well: NSColorWell, action: Selector, tip: String) {
        well.colorWellStyle = .minimal
        well.target = self
        well.action = action
        well.toolTip = tip
    }

    private func configure(slider: NSSlider, action: Selector, tip: String) {
        slider.minValue = 0
        slider.maxValue = 1
        slider.isContinuous = true
        slider.target = self
        slider.action = action
        slider.toolTip = tip
    }

    private func makePresetGrid(width: CGFloat) -> NSView {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 0))
        let columns = 4
        let rowHeight: CGFloat = 26
        let gapX: CGFloat = 6
        let gapY: CGFloat = 6
        let buttonWidth = floor((width - gapX * CGFloat(columns - 1)) / CGFloat(columns))
        var x: CGFloat = 0
        var yDown: CGFloat = 0
        var placed: [(NSButton, CGFloat)] = []

        for (index, preset) in OverlayColorPreset.all.enumerated() {
            let button = NSButton(title: preset.name, target: self, action: #selector(applyPresetClicked(_:)))
            button.bezelStyle = .recessed
            button.setButtonType(.pushOnPushOff)
            button.tag = index
            button.font = NSFont.systemFont(ofSize: 12)
            button.toolTip = preset.toolTip
            if x > 0, x + buttonWidth > width + 0.5 {
                x = 0
                yDown += rowHeight + gapY
            }
            button.frame = NSRect(x: x, y: yDown, width: buttonWidth, height: rowHeight)
            container.addSubview(button)
            presetButtons.append(button)
            placed.append((button, yDown))
            x += buttonWidth + gapX
        }

        let total = yDown + rowHeight
        for (button, down) in placed {
            button.frame.origin.y = total - down - rowHeight
        }
        container.frame.size.height = total
        return container
    }

    private func makeSliderRow(title: String, well: NSColorWell?, slider: NSSlider, percent: NSTextField, width: CGFloat) -> NSView {
        let row = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 32))
        let label = NSTextField(labelWithString: title)
        label.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        label.lineBreakMode = .byTruncatingTail
        if let well {
            label.frame = NSRect(x: 0, y: 7, width: 104, height: 18)
            well.frame = NSRect(x: 108, y: 2, width: 44, height: 28)
            row.addSubview(well)
            let opacity = NSTextField(labelWithString: "Opacity")
            opacity.font = NSFont.systemFont(ofSize: 12)
            opacity.textColor = .secondaryLabelColor
            opacity.frame = NSRect(x: 160, y: 7, width: 56, height: 16)
            row.addSubview(opacity)
        } else {
            label.frame = NSRect(x: 0, y: 7, width: 200, height: 18)
        }
        row.addSubview(label)

        percent.frame = NSRect(x: width - 48, y: 7, width: 48, height: 16)
        slider.frame = NSRect(x: 220, y: 3, width: percent.frame.minX - 8 - 220, height: 26)
        row.addSubview(slider)
        row.addSubview(percent)
        return row
    }

    private func makeButtonBar(width: CGFloat) -> NSView {
        let bar = NSView(frame: NSRect(x: 0, y: 0, width: width, height: 32))
        let reset = NSButton(title: "Reset to Defaults", target: self, action: #selector(resetDefaults))
        reset.bezelStyle = .rounded
        reset.frame = NSRect(x: 0, y: 0, width: 150, height: 32)
        reset.toolTip = "Restore the original blue and teal overlay"
        bar.addSubview(reset)

        let done = NSButton(title: "Done", target: self, action: #selector(closeWindow))
        done.bezelStyle = .rounded
        done.keyEquivalent = "\r"
        done.frame = NSRect(x: width - 100, y: 0, width: 100, height: 32)
        bar.addSubview(done)
        return bar
    }

    private func syncControls() {
        updatingUI = true
        defer { updatingUI = false }
        let palette = Settings.shared.overlayPalette
        highlightWell.color = palette.opaqueColor(active: true)
        zoneWell.color = palette.opaqueColor(active: false)
        highlightSlider.doubleValue = palette.highlightOpacity
        zoneSlider.doubleValue = palette.zoneOpacity
        borderSlider.doubleValue = palette.borderOpacity
        highlightPercent.stringValue = percentString(palette.highlightOpacity)
        zonePercent.stringValue = percentString(palette.zoneOpacity)
        borderPercent.stringValue = percentString(palette.borderOpacity)
        refreshPresetButtons()
        preview.needsDisplay = true
    }

    private func refreshPresetButtons() {
        let palette = Settings.shared.overlayPalette
        for (index, button) in presetButtons.enumerated() {
            button.state = paletteMatches(OverlayColorPreset.all[index], palette: palette) ? .on : .off
        }
    }

    private func paletteMatches(_ preset: OverlayColorPreset, palette: OverlayPalette) -> Bool {
        func close(_ stored: (Double, Double, Double), _ presetRGB: (Double, Double, Double)) -> Bool {
            abs(stored.0 - presetRGB.0) < 0.02
                && abs(stored.1 - presetRGB.1) < 0.02
                && abs(stored.2 - presetRGB.2) < 0.02
        }
        let highlightOK = preset.highlightSystem
            ? palette.highlightIsSystem
            : !palette.highlightIsSystem && close(
                (palette.highlightRed, palette.highlightGreen, palette.highlightBlue),
                preset.highlight
            )
        let zoneOK = preset.zoneSystem
            ? palette.zoneIsSystem
            : !palette.zoneIsSystem && close(
                (palette.zoneRed, palette.zoneGreen, palette.zoneBlue),
                preset.zone
            )
        return highlightOK && zoneOK
    }

    private func percentString(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func storeColor(_ color: NSColor, highlight: Bool) {
        guard let resolved = color.usingColorSpace(.sRGB) else { return }
        var palette = Settings.shared.overlayPalette
        if highlight {
            palette.highlightIsSystem = false
            palette.highlightRed = Double(resolved.redComponent)
            palette.highlightGreen = Double(resolved.greenComponent)
            palette.highlightBlue = Double(resolved.blueComponent)
        } else {
            palette.zoneIsSystem = false
            palette.zoneRed = Double(resolved.redComponent)
            palette.zoneGreen = Double(resolved.greenComponent)
            palette.zoneBlue = Double(resolved.blueComponent)
        }
        Settings.shared.overlayPalette = palette
        refreshPresetButtons()
        preview.needsDisplay = true
    }

    @objc private func highlightColorChanged(_ sender: NSColorWell) {
        guard !updatingUI else { return }
        storeColor(sender.color, highlight: true)
    }

    @objc private func zoneColorChanged(_ sender: NSColorWell) {
        guard !updatingUI else { return }
        storeColor(sender.color, highlight: false)
    }

    @objc private func highlightOpacityChanged(_ sender: NSSlider) {
        guard !updatingUI else { return }
        var palette = Settings.shared.overlayPalette
        palette.highlightOpacity = sender.doubleValue
        Settings.shared.overlayPalette = palette
        highlightPercent.stringValue = percentString(sender.doubleValue)
        preview.needsDisplay = true
    }

    @objc private func zoneOpacityChanged(_ sender: NSSlider) {
        guard !updatingUI else { return }
        var palette = Settings.shared.overlayPalette
        palette.zoneOpacity = sender.doubleValue
        Settings.shared.overlayPalette = palette
        zonePercent.stringValue = percentString(sender.doubleValue)
        preview.needsDisplay = true
    }

    @objc private func borderOpacityChanged(_ sender: NSSlider) {
        guard !updatingUI else { return }
        var palette = Settings.shared.overlayPalette
        palette.borderOpacity = sender.doubleValue
        Settings.shared.overlayPalette = palette
        borderPercent.stringValue = percentString(sender.doubleValue)
        preview.needsDisplay = true
    }

    @objc private func applyPresetClicked(_ sender: NSButton) {
        guard OverlayColorPreset.all.indices.contains(sender.tag) else { return }
        let preset = OverlayColorPreset.all[sender.tag]
        var palette = Settings.shared.overlayPalette
        palette.highlightIsSystem = preset.highlightSystem
        if !preset.highlightSystem {
            palette.highlightRed = preset.highlight.0
            palette.highlightGreen = preset.highlight.1
            palette.highlightBlue = preset.highlight.2
        }
        palette.zoneIsSystem = preset.zoneSystem
        if !preset.zoneSystem {
            palette.zoneRed = preset.zone.0
            palette.zoneGreen = preset.zone.1
            palette.zoneBlue = preset.zone.2
        }
        Settings.shared.overlayPalette = palette
        syncControls()
    }

    @objc private func resetDefaults() {
        Settings.shared.overlayPalette = .default
        syncControls()
    }

    @objc private func closeWindow() {
        window?.close()
    }
}
