import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusBarController: StatusBarController!
    var keyboardMonitor: KeyboardMonitor!
    private var retryTimer: Timer?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppSettings.shared.load()
        keyboardMonitor = KeyboardMonitor()
        statusBarController = StatusBarController()

        observeTapFailure()

        if AXIsProcessTrusted() {
            keyboardMonitor.start()
        } else {
            requestAccessibility()
            startRetryTimer()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        keyboardMonitor.stop()
    }

    // MARK: - Accessibility

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Poll until Accessibility is granted, then start the tap.
    private func startRetryTimer() {
        retryTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] timer in
            guard let self = self else { timer.invalidate(); return }
            guard AXIsProcessTrusted() else { return }
            timer.invalidate()
            self.retryTimer = nil
            self.keyboardMonitor.start()
            if self.keyboardMonitor.eventTap == nil {
                self.showTapFailedAlert()
            }
        }
    }

    /// If the tap fails even with permission, guide the user to re-add the app.
    private func observeTapFailure() {
        NotificationCenter.default.addObserver(
            forName: .tapCreationFailed, object: nil, queue: .main
        ) { [weak self] _ in
            if AXIsProcessTrusted() {
                self?.showTapFailedAlert()
            } else {
                self?.startRetryTimer()
            }
        }
    }

    private func showTapFailedAlert() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "No se pudo activar MouseKeyboard"
        alert.informativeText = """
            El permiso de Accesibilidad fue otorgado a una versión anterior de la app.

            Para solucionarlo:
            1. Abrí Configuración del Sistema → Privacidad y Seguridad → Accesibilidad
            2. Eliminá la entrada de MouseKeyboard (ícono 🗑)
            3. Volvé a agregar esta versión de MouseKeyboard.app
            4. Reiniciá la app
            """
        alert.addButton(withTitle: "Abrir Accesibilidad")
        alert.addButton(withTitle: "Cancelar")
        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(
                URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            )
        }
        NSApp.setActivationPolicy(.accessory)
    }
}
