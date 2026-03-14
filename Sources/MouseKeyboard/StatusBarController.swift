import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var enabledMenuItem: NSMenuItem!
    private var tapStatusItem:   NSMenuItem!
    private var modKeyItem:      NSMenuItem!
    private var settingsWC: SettingsWindowController?

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let btn = statusItem.button {
            btn.title = "⌨"
            btn.font  = NSFont.systemFont(ofSize: 14)
        }
        buildMenu()
        observeNotifications()
    }

    private func buildMenu() {
        let menu = NSMenu()

        // ── Mode toggle ──────────────────────────────────────────────────────
        enabledMenuItem = NSMenuItem(title: "Activado", action: #selector(toggleEnabled), keyEquivalent: "")
        enabledMenuItem.target = self
        enabledMenuItem.state  = .on
        menu.addItem(enabledMenuItem)

        menu.addItem(.separator())

        // ── Diagnostics (read-only) ──────────────────────────────────────────
        tapStatusItem = NSMenuItem(title: tapStatusString(), action: nil, keyEquivalent: "")
        tapStatusItem.isEnabled = false
        menu.addItem(tapStatusItem)

        modKeyItem = NSMenuItem(title: modKeyString(), action: nil, keyEquivalent: "")
        modKeyItem.isEnabled = false
        menu.addItem(modKeyItem)

        let fixItem = NSMenuItem(title: "Re-otorgar permiso de Accesibilidad…",
                                 action: #selector(openAccessibility), keyEquivalent: "")
        fixItem.target = self
        menu.addItem(fixItem)

        menu.addItem(.separator())

        // ── Settings ─────────────────────────────────────────────────────────
        let settingsItem = NSMenuItem(title: "Ajustes…", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Salir", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // ── Diagnostic strings ───────────────────────────────────────────────────

    private func tapStatusString() -> String {
        let monitor = (NSApp.delegate as? AppDelegate)?.keyboardMonitor
        let active  = monitor?.eventTap != nil
        return active ? "Tap: ✅ activo" : "Tap: ❌ inactivo (re-otorgá permiso)"
    }

    private func modKeyString() -> String {
        let s = AppSettings.shared
        let name = keyName(for: s.modifierKeyCode)
        let type = s.modifierIsHardwareModifier ? "modificadora" : "regular"
        return "Tecla activ.: \(name) (\(type))"
    }

    private func refreshDiagnostics() {
        tapStatusItem.title = tapStatusString()
        modKeyItem.title    = modKeyString()
    }

    // ── Notifications ────────────────────────────────────────────────────────

    private func observeNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .mouseModeActivated,   object: nil, queue: .main) { [weak self] _ in
            self?.statusItem.button?.title = "🖱"
        }
        nc.addObserver(forName: .mouseModeDeactivated, object: nil, queue: .main) { [weak self] _ in
            self?.statusItem.button?.title = "⌨"
        }
        nc.addObserver(forName: .tapCreated,           object: nil, queue: .main) { [weak self] _ in
            self?.refreshDiagnostics()
        }
        nc.addObserver(forName: .tapCreationFailed,    object: nil, queue: .main) { [weak self] _ in
            self?.refreshDiagnostics()
            self?.showPermissionAlert()
        }
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    @objc private func toggleEnabled() {
        guard let monitor = (NSApp.delegate as? AppDelegate)?.keyboardMonitor else { return }
        if enabledMenuItem.state == .on {
            enabledMenuItem.state = .off
            monitor.isEnabled = false
            statusItem.button?.title = "⌨̶"
        } else {
            enabledMenuItem.state = .on
            monitor.isEnabled = true
            statusItem.button?.title = "⌨"
        }
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    @objc private func openSettings() {
        refreshDiagnostics()
        if settingsWC == nil {
            settingsWC = SettingsWindowController()
            settingsWC?.delegate = self
        }
        settingsWC?.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func showPermissionAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Tap inactivo — se necesita permiso de Accesibilidad"
        alert.informativeText = """
            1. Abrí Sistema → Privacidad y Seguridad → Accesibilidad
            2. Eliminá la entrada de MouseKeyboard
            3. Arrastrá el nuevo MouseKeyboard.app a esa lista
            4. Reiniciá la app
            """
        alert.addButton(withTitle: "Abrir Accesibilidad")
        alert.addButton(withTitle: "OK")
        if alert.runModal() == .alertFirstButtonReturn { openAccessibility() }
        NSApp.setActivationPolicy(.accessory)
    }
}

extension StatusBarController: SettingsWindowDelegate {
    func settingsWindowDidClose() {
        NSApp.setActivationPolicy(.accessory)
        refreshDiagnostics()
    }
}
