import AppKit

class StatusBarController {
    private var statusItem: NSStatusItem!
    private var enabledMenuItem: NSMenuItem!
    private var settingsWC: SettingsWindowController?
    private var isAppEnabled = true

    init() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        setIcon(active: false)
        buildMenu()
        observeNotifications()
    }

    // ── Icon ─────────────────────────────────────────────────────────────────

    private func setIcon(active: Bool) {
        guard let btn = statusItem.button else { return }
        let symbolName: String
        if !isAppEnabled       { symbolName = "cursorarrow.slash" }
        else if active         { symbolName = "cursorarrow.rays"  }
        else                   { symbolName = "cursorarrow"       }
        let img = NSImage(systemSymbolName: symbolName, accessibilityDescription: "MouseKeyboard")
        img?.isTemplate = true
        btn.image = img
        btn.imageScaling = .scaleProportionallyDown
    }

    // ── Menu ─────────────────────────────────────────────────────────────────

    private func buildMenu() {
        let menu = NSMenu()

        enabledMenuItem = NSMenuItem(
            title:          "Activar MouseKeyboard",
            action:         #selector(toggleEnabled),
            keyEquivalent:  ""
        )
        enabledMenuItem.target = self
        enabledMenuItem.state  = .on
        menu.addItem(enabledMenuItem)

        menu.addItem(.separator())

        let settings = NSMenuItem(
            title:         "Ajustes…",
            action:        #selector(openSettings),
            keyEquivalent: ","
        )
        settings.target = self
        menu.addItem(settings)

        menu.addItem(.separator())

        let quit = NSMenuItem(
            title:         "Salir de MouseKeyboard",
            action:        #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        menu.addItem(quit)

        statusItem.menu = menu
    }

    // ── Notifications ─────────────────────────────────────────────────────────

    private func observeNotifications() {
        let nc = NotificationCenter.default
        nc.addObserver(forName: .mouseModeActivated,   object: nil, queue: .main) { [weak self] _ in
            self?.setIcon(active: true)
        }
        nc.addObserver(forName: .mouseModeDeactivated, object: nil, queue: .main) { [weak self] _ in
            self?.setIcon(active: false)
        }
        nc.addObserver(forName: .tapCreationFailed,    object: nil, queue: .main) { [weak self] _ in
            self?.showPermissionAlert()
        }
    }

    // ── Actions ──────────────────────────────────────────────────────────────

    @objc private func toggleEnabled() {
        guard let monitor = (NSApp.delegate as? AppDelegate)?.keyboardMonitor else { return }
        isAppEnabled           = !isAppEnabled
        enabledMenuItem.state  = isAppEnabled ? .on : .off
        monitor.isEnabled      = isAppEnabled
        setIcon(active: false)
    }

    @objc private func openSettings() {
        if settingsWC == nil {
            settingsWC          = SettingsWindowController()
            settingsWC?.delegate = self
        }
        settingsWC?.showWindow(nil)
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func openAccessibility() {
        NSWorkspace.shared.open(
            URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        )
    }

    private func showPermissionAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText     = "Se necesita permiso de Accesibilidad"
        alert.informativeText = """
            MouseKeyboard necesita acceso de Accesibilidad para controlar el mouse.

            1. Abrí Sistema → Privacidad y Seguridad → Accesibilidad
            2. Eliminá la entrada de MouseKeyboard
            3. Arrastrá el nuevo MouseKeyboard.app a esa lista
            4. Reiniciá la app
            """
        alert.addButton(withTitle: "Abrir Accesibilidad")
        alert.addButton(withTitle: "Ahora no")
        if alert.runModal() == .alertFirstButtonReturn { openAccessibility() }
        NSApp.setActivationPolicy(.accessory)
    }
}

extension StatusBarController: SettingsWindowDelegate {
    func settingsWindowDidClose() {
        NSApp.setActivationPolicy(.accessory)
    }
}
