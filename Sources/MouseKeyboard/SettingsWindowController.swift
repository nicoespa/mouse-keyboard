import AppKit

protocol SettingsWindowDelegate: AnyObject {
    func settingsWindowDidClose()
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - SettingsWindowController
// ─────────────────────────────────────────────────────────────────────────────

class SettingsWindowController: NSWindowController, NSWindowDelegate {

    weak var delegate: SettingsWindowDelegate?

    private var keyButtons:      [String: NSButton] = [:]
    private var sliderLabels:    [String: NSTextField] = [:]

    // Capture state (shared between modifier and regular key capture)
    private var captureMonitorKeyDown:    Any?
    private var captureMonitorFlagsChanged: Any?
    private var captureKeyID: String?   // nil = modifier capture in progress

    convenience init() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 620),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        win.title = "MouseKeyboard – Ajustes"
        win.isReleasedWhenClosed = false
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
        guard let content = window?.contentView else { return }
        let s = AppSettings.shared
        var y: CGFloat = 578

        func row(label: String, keyID: String, keyCode: Int) {
            y -= 36
            addKeyRow(in: content, label: label, keyID: keyID, keyCode: keyCode, y: y)
        }

        // ── Modifier key ─────────────────────────────────────────────────────
        y -= 22
        addSectionHeader("Tecla de Activación", in: content, y: y)
        y -= 18
        addSubtitle("Cualquier tecla — mantenela presionada para activar el modo mouse.", in: content, y: y)
        y -= 36
        addModifierCaptureRow(in: content, y: y)

        y -= 14; addHRule(in: content, y: y)

        // ── Movement ─────────────────────────────────────────────────────────
        y -= 22
        addSectionHeader("Movimiento", in: content, y: y)
        y -= 16
        addSubtitle("Las flechas del teclado siempre funcionan como alternativa.", in: content, y: y)

        row(label: "Mover arriba",    keyID: "upKeyCode",    keyCode: s.upKeyCode)
        row(label: "Mover abajo",     keyID: "downKeyCode",  keyCode: s.downKeyCode)
        row(label: "Mover izquierda", keyID: "leftKeyCode",  keyCode: s.leftKeyCode)
        row(label: "Mover derecha",   keyID: "rightKeyCode", keyCode: s.rightKeyCode)

        y -= 14; addHRule(in: content, y: y)

        // ── Actions ──────────────────────────────────────────────────────────
        y -= 22
        addSectionHeader("Acciones", in: content, y: y)
        y -= 16
        addSubtitle("Mantener la tecla de click + mover = arrastrar.", in: content, y: y)

        row(label: "Click izquierdo", keyID: "leftClickKeyCode",  keyCode: s.leftClickKeyCode)
        row(label: "Click derecho",   keyID: "rightClickKeyCode", keyCode: s.rightClickKeyCode)
        row(label: "Scroll arriba",   keyID: "scrollUpKeyCode",   keyCode: s.scrollUpKeyCode)
        row(label: "Scroll abajo",    keyID: "scrollDownKeyCode", keyCode: s.scrollDownKeyCode)

        y -= 14; addHRule(in: content, y: y)

        // ── Speed ────────────────────────────────────────────────────────────
        y -= 22
        addSectionHeader("Velocidad", in: content, y: y)

        y -= 36
        addSliderRow(in: content, label: "Velocidad normal:", sliderID: "normalSpeed",
                     value: s.normalSpeed, min: 3, max: 40, unit: "px", y: y)
        y -= 36
        addSliderRow(in: content, label: "Multiplicador rápido (+ ⇧):", sliderID: "fastMultiplier",
                     value: s.fastMultiplier, min: 1.5, max: 8, unit: "×", y: y)
        y -= 36
        addSliderRow(in: content, label: "Velocidad de scroll:", sliderID: "scrollSpeed",
                     value: s.scrollSpeed, min: 1, max: 30, unit: "px", y: y)

        y -= 14; addHRule(in: content, y: y)

        // ── Reset ────────────────────────────────────────────────────────────
        y -= 36
        let resetBtn = NSButton(title: "Restaurar valores por defecto",
                                target: self, action: #selector(resetDefaults))
        resetBtn.bezelStyle = .rounded
        resetBtn.frame = NSRect(x: 130, y: y, width: 200, height: 26)
        content.addSubview(resetBtn)
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Row builders
    // ─────────────────────────────────────────────────────────────────────────

    private func addSectionHeader(_ text: String, in view: NSView, y: CGFloat) {
        let tf = NSTextField(labelWithString: text.uppercased())
        tf.font = NSFont.systemFont(ofSize: 11, weight: .semibold)
        tf.textColor = .secondaryLabelColor
        tf.frame = NSRect(x: 20, y: y, width: 420, height: 16)
        view.addSubview(tf)
    }

    private func addSubtitle(_ text: String, in view: NSView, y: CGFloat) {
        let tf = NSTextField(labelWithString: text)
        tf.font = NSFont.systemFont(ofSize: 11)
        tf.textColor = .tertiaryLabelColor
        tf.frame = NSRect(x: 20, y: y, width: 420, height: 14)
        view.addSubview(tf)
    }

    private func addHRule(in view: NSView, y: CGFloat) {
        let box = NSBox(); box.boxType = .separator
        box.frame = NSRect(x: 20, y: y, width: 420, height: 1)
        view.addSubview(box)
    }

    /// Modifier key row: label + key-badge capture button + type hint
    private func addModifierCaptureRow(in view: NSView, y: CGFloat) {
        let s = AppSettings.shared

        let lbl = NSTextField(labelWithString: "Activar con:")
        lbl.font = NSFont.systemFont(ofSize: 13)
        lbl.frame = NSRect(x: 20, y: y + 4, width: 200, height: 20)
        view.addSubview(lbl)

        let btn = makeKeyButton(title: keyName(for: s.modifierKeyCode), keyID: "modifier")
        btn.frame = NSRect(x: 350, y: y, width: 90, height: 28)
        btn.action = #selector(modifierButtonClicked(_:))
        view.addSubview(btn)
        keyButtons["modifier"] = btn

        // Type hint (regular / hardware modifier)
        let hint = NSTextField(labelWithString: modifierTypeHint())
        hint.identifier = NSUserInterfaceItemIdentifier("modifierHint")
        hint.font = NSFont.systemFont(ofSize: 11)
        hint.textColor = .tertiaryLabelColor
        hint.frame = NSRect(x: 230, y: y + 6, width: 110, height: 16)
        hint.alignment = .right
        view.addSubview(hint)
    }

    private func modifierTypeHint() -> String {
        let s = AppSettings.shared
        return s.modifierIsHardwareModifier ? "tecla modificadora" : "tecla regular"
    }

    /// A key-binding row with a capture button.
    private func addKeyRow(in view: NSView, label: String, keyID: String, keyCode: Int, y: CGFloat) {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = NSFont.systemFont(ofSize: 13)
        lbl.frame = NSRect(x: 20, y: y + 4, width: 220, height: 20)
        view.addSubview(lbl)

        let btn = makeKeyButton(title: keyName(for: keyCode), keyID: keyID)
        btn.frame = NSRect(x: 350, y: y, width: 90, height: 28)
        view.addSubview(btn)
        keyButtons[keyID] = btn
    }

    private func addSliderRow(in view: NSView, label: String, sliderID: String,
                               value: Double, min: Double, max: Double, unit: String, y: CGFloat) {
        let lbl = NSTextField(labelWithString: label)
        lbl.font = NSFont.systemFont(ofSize: 13)
        lbl.frame = NSRect(x: 20, y: y + 5, width: 210, height: 20)
        view.addSubview(lbl)

        let slider = NSSlider(value: value, minValue: min, maxValue: max,
                              target: self, action: #selector(sliderChanged(_:)))
        slider.isContinuous = true
        slider.identifier   = NSUserInterfaceItemIdentifier(sliderID)
        slider.toolTip      = unit
        slider.frame = NSRect(x: 235, y: y + 4, width: 160, height: 22)
        view.addSubview(slider)

        let valLbl = NSTextField(labelWithString: formatSlider(value: value, unit: unit))
        valLbl.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        valLbl.alignment = .right
        valLbl.frame = NSRect(x: 400, y: y + 5, width: 50, height: 20)
        view.addSubview(valLbl)
        sliderLabels[sliderID] = valLbl
    }

    private func makeKeyButton(title: String, keyID: String) -> NSButton {
        let btn = NSButton(title: title, target: self, action: #selector(keyButtonClicked(_:)))
        btn.bezelStyle = .rounded
        btn.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
        btn.identifier = NSUserInterfaceItemIdentifier(keyID)
        btn.toolTip = "Clic para reasignar"
        // Make it look like a key badge
        btn.wantsLayer = true
        btn.layer?.cornerRadius = 6
        return btn
    }

    private func formatSlider(value: Double, unit: String) -> String {
        unit == "×" ? String(format: "%.1f×", value) : String(format: "%.0f px", value)
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
        alert.messageText = "¿Restaurar valores por defecto?"
        alert.informativeText = "Se restablecerán todas las teclas y velocidades."
        alert.addButton(withTitle: "Restaurar")
        alert.addButton(withTitle: "Cancelar")
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        AppSettings.shared.resetToDefaults()
        monitor?.reload()
        window?.contentView?.subviews.forEach { $0.removeFromSuperview() }
        keyButtons.removeAll(); sliderLabels.removeAll()
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
            // Ignore hardware modifier keys (they don't generate keyDown)
            guard !AppSettings.hardwareModifierKeyCodes.contains(code) else { return event }
            self.applyRegularCapture(keyID: keyID, keyCode: code, button: button)
            return nil
        }
    }

    private func applyRegularCapture(keyID: String, keyCode: Int, button: NSButton) {
        let s = AppSettings.shared
        switch keyID {
        case "upKeyCode":          s.upKeyCode           = keyCode
        case "downKeyCode":        s.downKeyCode         = keyCode
        case "leftKeyCode":        s.leftKeyCode         = keyCode
        case "rightKeyCode":       s.rightKeyCode        = keyCode
        case "leftClickKeyCode":   s.leftClickKeyCode    = keyCode
        case "rightClickKeyCode":  s.rightClickKeyCode   = keyCode
        case "scrollUpKeyCode":    s.scrollUpKeyCode     = keyCode
        case "scrollDownKeyCode":  s.scrollDownKeyCode   = keyCode
        default: break
        }
        s.save()
        monitor?.reload()
        button.title = keyName(for: keyCode)
        button.isHighlighted = false
        cancelCapture()
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Modifier key capture (accepts any key, including hardware modifiers)
    // ─────────────────────────────────────────────────────────────────────────

    private func startModifierCapture(button: NSButton) {
        cancelCapture()
        captureKeyID = nil  // signals "modifier capture mode"
        setButtonWaiting(button)
        monitor?.isCapturing = true

        // Listen for regular key presses
        captureMonitorKeyDown = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak button] event in
            guard let self = self, let button = button else { return event }
            let code = Int(event.keyCode)
            guard !AppSettings.hardwareModifierKeyCodes.contains(code) else { return event }
            self.applyModifierCapture(keyCode: code, rawMask: 0, button: button)
            return nil
        }

        // Also listen for hardware modifier key presses (flagsChanged)
        captureMonitorFlagsChanged = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self, weak button] event in
            guard let self = self, let button = button else { return event }
            let code = Int(event.keyCode)
            guard AppSettings.hardwareModifierKeyCodes.contains(code) else { return event }
            guard code != 57 else { return event } // Skip Caps Lock (it's a toggle, not a hold)

            // Detect PRESS vs RELEASE using high-level NSEvent.ModifierFlags
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
        button.title = keyName(for: keyCode)
        button.isHighlighted = false
        // Update the type hint label
        if let hint = window?.contentView?.subviews
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
        button.title = "…"
        button.isHighlighted = true
    }

    private func cancelCapture() {
        if let m = captureMonitorKeyDown       { NSEvent.removeMonitor(m); captureMonitorKeyDown = nil }
        if let m = captureMonitorFlagsChanged  { NSEvent.removeMonitor(m); captureMonitorFlagsChanged = nil }
        monitor?.isCapturing = false

        // Restore button label if it's still showing "…"
        if let id = captureKeyID {
            if let btn = keyButtons[id] {
                let code = currentKeyCode(for: id)
                btn.title = keyName(for: code)
                btn.isHighlighted = false
            }
        } else if let btn = keyButtons["modifier"] {
            if btn.title == "…" {
                btn.title = keyName(for: AppSettings.shared.modifierKeyCode)
                btn.isHighlighted = false
            }
        }
        captureKeyID = nil
    }

    private func currentKeyCode(for keyID: String) -> Int {
        let s = AppSettings.shared
        switch keyID {
        case "upKeyCode":          return s.upKeyCode
        case "downKeyCode":        return s.downKeyCode
        case "leftKeyCode":        return s.leftKeyCode
        case "rightKeyCode":       return s.rightKeyCode
        case "leftClickKeyCode":   return s.leftClickKeyCode
        case "rightClickKeyCode":  return s.rightClickKeyCode
        case "scrollUpKeyCode":    return s.scrollUpKeyCode
        case "scrollDownKeyCode":  return s.scrollDownKeyCode
        default:                   return 0
        }
    }

    // ─────────────────────────────────────────────────────────────────────────
    // MARK: - Helpers
    // ─────────────────────────────────────────────────────────────────────────

    private var monitor: KeyboardMonitor? {
        (NSApp.delegate as? AppDelegate)?.keyboardMonitor
    }
}
