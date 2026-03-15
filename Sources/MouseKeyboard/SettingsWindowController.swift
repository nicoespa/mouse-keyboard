import AppKit

protocol SettingsWindowDelegate: AnyObject {
    func settingsWindowDidClose()
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SettingsWindowController
// ─────────────────────────────────────────────────────────────────────────────

class SettingsWindowController: NSWindowController, NSWindowDelegate {

    weak var delegate: SettingsWindowDelegate?

    private var keyButtons:   [String: KeyCapButton] = [:]
    private var sliderLabels: [String: NSTextField]  = [:]

    private var captureMonitorKeyDown:      Any?
    private var captureMonitorFlagsChanged: Any?
    private var captureKeyID: String?

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
            styleMask:   [.titled, .closable, .miniaturizable],
            backing:     .buffered,
            defer:       false
        )
        win.title                    = "MouseKeyboard"
        win.isReleasedWhenClosed     = false
        win.titlebarAppearsTransparent = false
        win.center()
        self.init(window: win)
        win.delegate = self
        buildUI()
    }

    func windowWillClose(_ notification: Notification) {
        cancelCapture()
        delegate?.settingsWindowDidClose()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Build UI
    // ─────────────────────────────────────────────────────────────────────────

    private func buildUI() {
        guard let contentView = window?.contentView else { return }

        // Scroll view ─────────────────────────────────────────────────────────
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller   = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers    = true
        scrollView.drawsBackground       = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: contentView.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])

        // Main vertical stack ─────────────────────────────────────────────────
        let stack = NSStackView()
        stack.orientation  = .vertical
        stack.alignment    = .leading
        stack.spacing      = 20
        stack.edgeInsets   = NSEdgeInsets(top: 24, left: 20, bottom: 28, right: 20)
        stack.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = stack
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: scrollView.contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        ])

        let s = AppSettings.shared

        // ── Header ───────────────────────────────────────────────────────────
        let header = buildHeader()
        stack.addArrangedSubview(header)
        header.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        // ── Activation Key ───────────────────────────────────────────────────
        let activationSection = buildSection(
            title:    "Tecla de Activación",
            subtitle: "Mantenela presionada para activar el modo mouse.",
            rows:     [buildModifierRow()]
        )
        stack.addArrangedSubview(activationSection)
        activationSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        // ── Movement ─────────────────────────────────────────────────────────
        let movementSection = buildSection(
            title:    "Movimiento",
            subtitle: "Las flechas del teclado siempre funcionan como alternativa.",
            rows: [
                buildKeyRow(label: "Mover arriba",    keyID: "upKeyCode",    keyCode: s.upKeyCode),
                buildKeyRow(label: "Mover abajo",     keyID: "downKeyCode",  keyCode: s.downKeyCode),
                buildKeyRow(label: "Mover izquierda", keyID: "leftKeyCode",  keyCode: s.leftKeyCode),
                buildKeyRow(label: "Mover derecha",   keyID: "rightKeyCode", keyCode: s.rightKeyCode),
            ]
        )
        stack.addArrangedSubview(movementSection)
        movementSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        // ── Actions ──────────────────────────────────────────────────────────
        let actionsSection = buildSection(
            title:    "Acciones",
            subtitle: "Mantener la tecla de click + mover activa el arrastre.",
            rows: [
                buildKeyRow(label: "Click izquierdo", keyID: "leftClickKeyCode",  keyCode: s.leftClickKeyCode),
                buildKeyRow(label: "Click derecho",   keyID: "rightClickKeyCode", keyCode: s.rightClickKeyCode),
                buildKeyRow(label: "Scroll arriba",   keyID: "scrollUpKeyCode",   keyCode: s.scrollUpKeyCode),
                buildKeyRow(label: "Scroll abajo",    keyID: "scrollDownKeyCode", keyCode: s.scrollDownKeyCode),
            ]
        )
        stack.addArrangedSubview(actionsSection)
        actionsSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        // ── Speed ────────────────────────────────────────────────────────────
        let speedSection = buildSection(
            title:    "Velocidad",
            subtitle: nil,
            rows: [
                buildSliderRow(label: "Velocidad normal",         sliderID: "normalSpeed",    value: s.normalSpeed,    min: 3,   max: 40, unit: "px"),
                buildSliderRow(label: "Multiplicador rápido (⇧)", sliderID: "fastMultiplier", value: s.fastMultiplier, min: 1.5, max: 8,  unit: "×"),
                buildSliderRow(label: "Velocidad de scroll",      sliderID: "scrollSpeed",    value: s.scrollSpeed,    min: 1,   max: 30, unit: "px"),
            ]
        )
        stack.addArrangedSubview(speedSection)
        speedSection.widthAnchor.constraint(equalTo: stack.widthAnchor, constant: -40).isActive = true

        // ── Reset ────────────────────────────────────────────────────────────
        let resetBtn = NSButton(title: "Restaurar valores por defecto", target: self, action: #selector(resetDefaults))
        resetBtn.bezelStyle  = .rounded
        resetBtn.controlSize = .regular
        resetBtn.translatesAutoresizingMaskIntoConstraints = false
        stack.addArrangedSubview(resetBtn)
        resetBtn.centerXAnchor.constraint(equalTo: stack.centerXAnchor).isActive = true
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Header
    // ─────────────────────────────────────────────────────────────────────────

    private func buildHeader() -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        let icon = NSImageView()
        if let img = NSImage(systemSymbolName: "cursorarrow.rays", accessibilityDescription: nil) {
            let cfg = NSImage.SymbolConfiguration(pointSize: 28, weight: .light)
            icon.image = img.withSymbolConfiguration(cfg)
        }
        icon.imageScaling = .scaleProportionallyDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(icon)

        let title = NSTextField(labelWithString: "MouseKeyboard")
        title.font      = NSFont.systemFont(ofSize: 17, weight: .semibold)
        title.textColor = .labelColor
        title.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(title)

        let subtitle = NSTextField(labelWithString: "Controlá el mouse desde el teclado")
        subtitle.font      = NSFont.systemFont(ofSize: 12)
        subtitle.textColor = .secondaryLabelColor
        subtitle.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(subtitle)

        NSLayoutConstraint.activate([
            icon.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            icon.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            icon.widthAnchor.constraint(equalToConstant: 36),
            icon.heightAnchor.constraint(equalToConstant: 36),

            title.leadingAnchor.constraint(equalTo: icon.trailingAnchor, constant: 12),
            title.topAnchor.constraint(equalTo: container.topAnchor),
            title.trailingAnchor.constraint(equalTo: container.trailingAnchor),

            subtitle.leadingAnchor.constraint(equalTo: title.leadingAnchor),
            subtitle.topAnchor.constraint(equalTo: title.bottomAnchor, constant: 2),
            subtitle.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            subtitle.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Section builder
    // ─────────────────────────────────────────────────────────────────────────

    private func buildSection(title: String, subtitle: String?, rows: [NSView]) -> NSView {
        let container = NSView()
        container.translatesAutoresizingMaskIntoConstraints = false

        // Section title label
        let titleLabel = NSTextField(labelWithString: title.uppercased())
        titleLabel.font      = NSFont.systemFont(ofSize: 11, weight: .semibold)
        titleLabel.textColor = .secondaryLabelColor
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(titleLabel)

        // Optional subtitle
        var subtitleLabel: NSTextField?
        if let text = subtitle {
            let lbl = NSTextField(labelWithString: text)
            lbl.font      = NSFont.systemFont(ofSize: 11)
            lbl.textColor = .tertiaryLabelColor
            lbl.translatesAutoresizingMaskIntoConstraints = false
            container.addSubview(lbl)
            subtitleLabel = lbl
        }

        // Card (rounded box)
        let card = NSView()
        card.wantsLayer              = true
        card.layer?.cornerRadius     = 10
        card.layer?.borderWidth      = 0.5
        card.layer?.borderColor      = NSColor.separatorColor.cgColor
        card.layer?.backgroundColor  = NSColor.controlBackgroundColor.cgColor
        card.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(card)

        // Rows inside card with separators
        var prevBottom: NSLayoutYAxisAnchor = card.topAnchor
        for (i, row) in rows.enumerated() {
            row.translatesAutoresizingMaskIntoConstraints = false
            card.addSubview(row)

            if i > 0 {
                let sep = NSBox()
                sep.boxType = .separator
                sep.translatesAutoresizingMaskIntoConstraints = false
                card.addSubview(sep)
                NSLayoutConstraint.activate([
                    sep.topAnchor.constraint(equalTo: prevBottom),
                    sep.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 16),
                    sep.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                    sep.heightAnchor.constraint(equalToConstant: 1),
                    row.topAnchor.constraint(equalTo: sep.bottomAnchor),
                ])
            } else {
                row.topAnchor.constraint(equalTo: prevBottom).isActive = true
            }

            NSLayoutConstraint.activate([
                row.leadingAnchor.constraint(equalTo: card.leadingAnchor),
                row.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                row.heightAnchor.constraint(equalToConstant: 44),
            ])
            prevBottom = row.bottomAnchor
        }
        rows.last?.bottomAnchor.constraint(equalTo: card.bottomAnchor).isActive = true

        // Title constraints
        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: container.topAnchor),
            titleLabel.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
            titleLabel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
        ])

        if let sub = subtitleLabel {
            NSLayoutConstraint.activate([
                sub.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 2),
                sub.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 4),
                sub.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                card.topAnchor.constraint(equalTo: sub.bottomAnchor, constant: 8),
            ])
        } else {
            card.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8).isActive = true
        }

        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            card.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            card.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        return container
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Row builders
    // ─────────────────────────────────────────────────────────────────────────

    private func buildModifierRow() -> NSView {
        let s   = AppSettings.shared
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = makeLabel("Activar con", size: 13)
        row.addSubview(label)

        let hint = makeLabel(modifierTypeHint(), size: 11)
        hint.identifier = NSUserInterfaceItemIdentifier("modifierHint")
        hint.textColor  = .tertiaryLabelColor
        row.addSubview(hint)

        let btn = makeKeyCapButton(title: keyName(for: s.modifierKeyCode), keyID: "modifier")
        btn.action = #selector(modifierButtonClicked(_:))
        row.addSubview(btn)
        keyButtons["modifier"] = btn

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor, constant: -9),

            hint.leadingAnchor.constraint(equalTo: label.leadingAnchor),
            hint.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 2),

            btn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            btn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            btn.heightAnchor.constraint(equalToConstant: 26),
        ])

        return row
    }

    private func buildKeyRow(label labelText: String, keyID: String, keyCode: Int) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = makeLabel(labelText, size: 13)
        row.addSubview(label)

        let btn = makeKeyCapButton(title: keyName(for: keyCode), keyID: keyID)
        row.addSubview(btn)
        keyButtons[keyID] = btn

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),

            btn.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            btn.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            btn.widthAnchor.constraint(greaterThanOrEqualToConstant: 56),
            btn.heightAnchor.constraint(equalToConstant: 26),
        ])

        return row
    }

    private func buildSliderRow(label labelText: String, sliderID: String,
                                value: Double, min: Double, max: Double, unit: String) -> NSView {
        let row = NSView()
        row.translatesAutoresizingMaskIntoConstraints = false

        let label = makeLabel(labelText, size: 13)
        row.addSubview(label)

        let slider = NSSlider(value: value, minValue: min, maxValue: max,
                              target: self, action: #selector(sliderChanged(_:)))
        slider.isContinuous = true
        slider.identifier   = NSUserInterfaceItemIdentifier(sliderID)
        slider.toolTip      = unit
        slider.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(slider)

        let valLabel = NSTextField(labelWithString: formatSlider(value: value, unit: unit))
        valLabel.font        = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valLabel.textColor   = .secondaryLabelColor
        valLabel.alignment   = .right
        valLabel.translatesAutoresizingMaskIntoConstraints = false
        row.addSubview(valLabel)
        sliderLabels[sliderID] = valLabel

        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: row.leadingAnchor, constant: 16),
            label.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            label.widthAnchor.constraint(equalToConstant: 190),

            valLabel.trailingAnchor.constraint(equalTo: row.trailingAnchor, constant: -16),
            valLabel.centerYAnchor.constraint(equalTo: row.centerYAnchor),
            valLabel.widthAnchor.constraint(equalToConstant: 52),

            slider.leadingAnchor.constraint(equalTo: label.trailingAnchor, constant: 8),
            slider.trailingAnchor.constraint(equalTo: valLabel.leadingAnchor, constant: -8),
            slider.centerYAnchor.constraint(equalTo: row.centerYAnchor),
        ])

        return row
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Control factories
    // ─────────────────────────────────────────────────────────────────────────

    private func makeLabel(_ text: String, size: CGFloat) -> NSTextField {
        let tf = NSTextField(labelWithString: text)
        tf.font = NSFont.systemFont(ofSize: size)
        tf.translatesAutoresizingMaskIntoConstraints = false
        return tf
    }

    private func makeKeyCapButton(title: String, keyID: String) -> KeyCapButton {
        let btn = KeyCapButton(title: title)
        btn.target     = self
        btn.action     = #selector(keyButtonClicked(_:))
        btn.identifier = NSUserInterfaceItemIdentifier(keyID)
        btn.toolTip    = "Clic para reasignar"
        btn.translatesAutoresizingMaskIntoConstraints = false
        return btn
    }

    private func formatSlider(value: Double, unit: String) -> String {
        unit == "×" ? String(format: "%.1f×", value) : String(format: "%.0f px", value)
    }

    private func modifierTypeHint() -> String {
        AppSettings.shared.modifierIsHardwareModifier ? "tecla modificadora" : "tecla regular"
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Actions
    // ─────────────────────────────────────────────────────────────────────────

    @objc private func modifierButtonClicked(_ sender: NSButton) {
        startModifierCapture(button: sender)
    }

    @objc private func keyButtonClicked(_ sender: NSButton) {
        guard let keyID = sender.identifier?.rawValue else { return }
        startRegularCapture(keyID: keyID, button: sender)
    }

    @objc private func sliderChanged(_ sender: NSSlider) {
        guard let id = sender.identifier?.rawValue else { return }
        let val  = sender.doubleValue
        let unit = sender.toolTip ?? "px"
        sliderLabels[id]?.stringValue = formatSlider(value: val, unit: unit)
        let s = AppSettings.shared
        switch id {
        case "normalSpeed":    s.normalSpeed    = val
        case "fastMultiplier": s.fastMultiplier = val
        case "scrollSpeed":    s.scrollSpeed    = val
        default: break
        }
        s.save()
    }

    @objc private func resetDefaults() {
        let alert = NSAlert()
        alert.messageText     = "¿Restaurar valores por defecto?"
        alert.informativeText = "Se restablecerán todas las teclas y velocidades."
        alert.addButton(withTitle: "Restaurar")
        alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        AppSettings.shared.resetToDefaults()
        monitor?.reload()
        window?.contentView?.subviews.forEach { $0.removeFromSuperview() }
        keyButtons.removeAll()
        sliderLabels.removeAll()
        buildUI()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Key capture (regular bindings)
    // ─────────────────────────────────────────────────────────────────────────

    private func startRegularCapture(keyID: String, button: NSButton) {
        cancelCapture()
        captureKeyID = keyID
        setButtonWaiting(button)
        monitor?.isCapturing = true

        captureMonitorKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak button] event in
            guard let self = self, let button = button else { return event }
            let code = Int(event.keyCode)
            guard !AppSettings.hardwareModifierKeyCodes.contains(code) else { return event }
            self.applyRegularCapture(keyID: keyID, keyCode: code, button: button)
            return nil
        }
    }

    private func applyRegularCapture(keyID: String, keyCode: Int, button: NSButton) {
        let s = AppSettings.shared
        switch keyID {
        case "upKeyCode":         s.upKeyCode          = keyCode
        case "downKeyCode":       s.downKeyCode        = keyCode
        case "leftKeyCode":       s.leftKeyCode        = keyCode
        case "rightKeyCode":      s.rightKeyCode       = keyCode
        case "leftClickKeyCode":  s.leftClickKeyCode   = keyCode
        case "rightClickKeyCode": s.rightClickKeyCode  = keyCode
        case "scrollUpKeyCode":   s.scrollUpKeyCode    = keyCode
        case "scrollDownKeyCode": s.scrollDownKeyCode  = keyCode
        default: break
        }
        s.save()
        monitor?.reload()
        (button as? KeyCapButton)?.setNormal(title: keyName(for: keyCode))
        cancelCapture()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Modifier key capture
    // ─────────────────────────────────────────────────────────────────────────

    private func startModifierCapture(button: NSButton) {
        cancelCapture()
        captureKeyID = nil
        setButtonWaiting(button)
        monitor?.isCapturing = true

        captureMonitorKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak button] event in
            guard let self = self, let button = button else { return event }
            let code = Int(event.keyCode)
            guard !AppSettings.hardwareModifierKeyCodes.contains(code) else { return event }
            self.applyModifierCapture(keyCode: code, rawMask: 0, button: button)
            return nil
        }

        captureMonitorFlagsChanged = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self, weak button] event in
            guard let self = self, let button = button else { return event }
            let code = Int(event.keyCode)
            guard AppSettings.hardwareModifierKeyCodes.contains(code) else { return event }
            guard code != 57 else { return event }

            let f = event.modifierFlags
            let isPressed: Bool
            switch code {
            case 54, 55: isPressed = f.contains(.command)
            case 56, 60: isPressed = f.contains(.shift)
            case 58, 61: isPressed = f.contains(.option)
            case 59, 62: isPressed = f.contains(.control)
            default: return event
            }
            guard isPressed else { return event }

            let mask = AppSettings.modifierRawMasks[code] ?? 0
            self.applyModifierCapture(keyCode: code, rawMask: mask, button: button)
            return event
        }
    }

    private func applyModifierCapture(keyCode: Int, rawMask: Int, button: NSButton) {
        AppSettings.shared.setModifierKey(keyCode: keyCode, rawMask: rawMask)
        monitor?.reload()
        (button as? KeyCapButton)?.setNormal(title: keyName(for: keyCode))
        if let hint = window?.contentView?.subviews
                .compactMap({ $0 as? NSScrollView }).first?
                .documentView?.subviews
                .flatMap({ $0.subviews })
                .compactMap({ $0 as? NSTextField })
                .first(where: { $0.identifier?.rawValue == "modifierHint" }) {
            hint.stringValue = modifierTypeHint()
        }
        cancelCapture()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Capture helpers
    // ─────────────────────────────────────────────────────────────────────────

    private func setButtonWaiting(_ button: NSButton) {
        (button as? KeyCapButton)?.setCapturing()
    }

    private func cancelCapture() {
        if let m = captureMonitorKeyDown      { NSEvent.removeMonitor(m); captureMonitorKeyDown = nil }
        if let m = captureMonitorFlagsChanged { NSEvent.removeMonitor(m); captureMonitorFlagsChanged = nil }
        monitor?.isCapturing = false

        if let id = captureKeyID {
            if let btn = keyButtons[id] {
                btn.setNormal(title: keyName(for: currentKeyCode(for: id)))
            }
        } else if let btn = keyButtons["modifier"], btn.isCapturing {
            btn.setNormal(title: keyName(for: AppSettings.shared.modifierKeyCode))
        }
        captureKeyID = nil
    }

    private func currentKeyCode(for keyID: String) -> Int {
        let s = AppSettings.shared
        switch keyID {
        case "upKeyCode":         return s.upKeyCode
        case "downKeyCode":       return s.downKeyCode
        case "leftKeyCode":       return s.leftKeyCode
        case "rightKeyCode":      return s.rightKeyCode
        case "leftClickKeyCode":  return s.leftClickKeyCode
        case "rightClickKeyCode": return s.rightClickKeyCode
        case "scrollUpKeyCode":   return s.scrollUpKeyCode
        case "scrollDownKeyCode": return s.scrollDownKeyCode
        default:                  return 0
        }
    }

    private var monitor: KeyboardMonitor? {
        (NSApp.delegate as? AppDelegate)?.keyboardMonitor
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - KeyCapButton
// A button styled to resemble a keyboard key cap.
// ─────────────────────────────────────────────────────────────────────────────

class KeyCapButton: NSButton {

    private(set) var isCapturing = false

    init(title: String) {
        super.init(frame: .zero)
        isBordered   = false
        wantsLayer   = true
        font         = NSFont.monospacedSystemFont(ofSize: 12, weight: .medium)
        alignment    = .center
        self.title   = title
        styleNormal()
    }

    required init?(coder: NSCoder) { fatalError() }

    func setNormal(title: String) {
        isCapturing  = false
        self.title   = title
        styleNormal()
    }

    func setCapturing() {
        isCapturing  = true
        self.title   = "⌨ Escribí…"
        styleCapturing()
    }

    private func styleNormal() {
        layer?.backgroundColor = NSColor.controlColor.cgColor
        layer?.cornerRadius    = 6
        layer?.borderColor     = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        layer?.borderWidth     = 0.5
        layer?.shadowColor     = NSColor.black.cgColor
        layer?.shadowOpacity   = 0.10
        layer?.shadowRadius    = 0
        layer?.shadowOffset    = CGSize(width: 0, height: -1.5)
        layer?.masksToBounds   = false
        contentTintColor       = .labelColor
    }

    private func styleCapturing() {
        layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.15).cgColor
        layer?.borderColor     = NSColor.controlAccentColor.cgColor
        layer?.borderWidth     = 1.5
        layer?.shadowOpacity   = 0
        contentTintColor       = .controlAccentColor
    }

    override func updateLayer() {
        super.updateLayer()
        // Re-apply on appearance change (dark/light mode switch)
        if isCapturing { styleCapturing() } else { styleNormal() }
    }
}
