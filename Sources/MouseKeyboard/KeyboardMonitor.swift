import AppKit
import CoreGraphics

extension Notification.Name {
    static let mouseModeActivated   = Notification.Name("MouseModeActivated")
    static let mouseModeDeactivated = Notification.Name("MouseModeDeactivated")
    static let tapCreationFailed    = Notification.Name("TapCreationFailed")
    static let tapCreated           = Notification.Name("TapCreated")
}

class KeyboardMonitor {
    var isEnabled:   Bool = true
    var isCapturing: Bool = false

    private(set) var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private var isModifierActive = false
    private var pressedKeys      = Set<Int>()

    private var moveTimer:      Timer?
    private var velocityX:      Double = 0
    private var velocityY:      Double = 0
    private var scrollVelocity: Double = 0

    private let arrowLeft  = 123
    private let arrowRight = 124
    private let arrowDown  = 125
    private let arrowUp    = 126

    // -------------------------------------------------------------------------
    // MARK: - Lifecycle
    // -------------------------------------------------------------------------

    func start() {
        guard eventTap == nil else { return }   // already running

        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue)      |
            (1 << CGEventType.keyUp.rawValue)        |
            (1 << CGEventType.flagsChanged.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[MouseKeyboard] ❌ Event tap creation FAILED.")
            NotificationCenter.default.post(name: .tapCreationFailed, object: nil)
            return
        }

        eventTap      = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[MouseKeyboard] ✅ Event tap created OK.")
        NotificationCenter.default.post(name: .tapCreated, object: nil)
    }

    func stop() {
        if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: false) }
        eventTap = nil
        stopTimer()
    }

    func reload() {
        MouseController.shared.releaseAllButtons()
        pressedKeys.removeAll()
        isModifierActive = false
        velocityX = 0; velocityY = 0; scrollVelocity = 0
        stopTimer()
    }

    // -------------------------------------------------------------------------
    // MARK: - Modifier-flag helper
    // -------------------------------------------------------------------------

    /// Returns true if the hardware modifier key (identified by its keyCode)
    /// is currently held, based on the CGEventFlags of the event.
    private func hardwareModHeld(_ flags: CGEventFlags, for keyCode: Int) -> Bool {
        switch keyCode {
        case 54, 55: return flags.contains(.maskCommand)
        case 56, 60: return flags.contains(.maskShift)
        case 58, 61: return flags.contains(.maskAlternate)
        case 59, 62: return flags.contains(.maskControl)
        default:     return false
        }
    }

    // -------------------------------------------------------------------------
    // MARK: - Event handling
    // -------------------------------------------------------------------------

    func handle(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap { CGEvent.tapEnable(tap: tap, enable: true) }
            return nil
        }

        guard isEnabled && !isCapturing else { return Unmanaged.passRetained(event) }

        let s       = AppSettings.shared
        let keyCode = Int(event.getIntegerValueField(.keyboardEventKeycode))

        switch type {

        // ── flagsChanged ──────────────────────────────────────────────────
        case .flagsChanged:
            guard s.modifierIsHardwareModifier,
                  keyCode == s.modifierKeyCode else { return Unmanaged.passRetained(event) }

            let wasActive = isModifierActive
            let nowHeld   = hardwareModHeld(event.flags, for: keyCode)

            if wasActive && !nowHeld { deactivate() }
            else if !wasActive && nowHeld { activateMode() }

            return Unmanaged.passRetained(event)   // never consume modifier key events

        // ── keyDown ───────────────────────────────────────────────────────
        case .keyDown:
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

            // ── Regular key used as modifier (hold to activate) ──
            if !s.modifierIsHardwareModifier && keyCode == s.modifierKeyCode {
                if !isRepeat && !isModifierActive { isModifierActive = true; activateMode() }
                return nil
            }

            // ── Belt-and-suspenders: hardware modifier check via event flags ──
            // If flagsChanged was missed for any reason, we catch it here.
            if s.modifierIsHardwareModifier {
                let modHeld = hardwareModHeld(event.flags, for: s.modifierKeyCode)
                if modHeld && !isModifierActive { isModifierActive = true; activateMode() }
                if !modHeld && isModifierActive { deactivate() }
                guard isModifierActive else { return Unmanaged.passRetained(event) }
            } else {
                guard isModifierActive else { return Unmanaged.passRetained(event) }
            }

            // ── Mode is active: handle key ──
            if !isRepeat {
                if keyCode == s.leftClickKeyCode  { pressedKeys.insert(keyCode); MouseController.shared.mouseDown(.left);  return nil }
                if keyCode == s.rightClickKeyCode { pressedKeys.insert(keyCode); MouseController.shared.mouseDown(.right); return nil }
            }
            pressedKeys.insert(keyCode)
            return nil

        // ── keyUp ─────────────────────────────────────────────────────────
        case .keyUp:
            // Regular-key modifier released
            if !s.modifierIsHardwareModifier && keyCode == s.modifierKeyCode {
                deactivate(); return nil
            }

            guard isModifierActive else { return Unmanaged.passRetained(event) }

            if keyCode == s.leftClickKeyCode  { pressedKeys.remove(keyCode); MouseController.shared.mouseUp(.left);  return nil }
            if keyCode == s.rightClickKeyCode { pressedKeys.remove(keyCode); MouseController.shared.mouseUp(.right); return nil }
            pressedKeys.remove(keyCode)
            return nil

        default:
            return Unmanaged.passRetained(event)
        }
    }

    // -------------------------------------------------------------------------
    // MARK: - Activate / Deactivate
    // -------------------------------------------------------------------------

    private func activateMode() {
        startTimer()
        NotificationCenter.default.post(name: .mouseModeActivated, object: nil)
    }

    private func deactivate() {
        MouseController.shared.releaseAllButtons()
        pressedKeys.removeAll()
        velocityX = 0; velocityY = 0; scrollVelocity = 0
        isModifierActive = false
        stopTimer()
        NotificationCenter.default.post(name: .mouseModeDeactivated, object: nil)
    }

    // -------------------------------------------------------------------------
    // MARK: - 60 fps movement timer
    // -------------------------------------------------------------------------

    private func startTimer() {
        guard moveTimer == nil else { return }
        let t = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        RunLoop.main.add(t, forMode: .common)
        moveTimer = t
    }

    private func stopTimer() {
        moveTimer?.invalidate()
        moveTimer = nil
    }

    private func tick() {
        let s      = AppSettings.shared
        let shift  = NSEvent.modifierFlags.contains(.shift)
        let speed  = s.normalSpeed  * (shift ? s.fastMultiplier : 1.0)
        let scr    = s.scrollSpeed  * (shift ? s.fastMultiplier : 1.0)

        var tX: Double = 0, tY: Double = 0
        if pressedKeys.contains(s.leftKeyCode)  || pressedKeys.contains(arrowLeft)  { tX -= speed }
        if pressedKeys.contains(s.rightKeyCode) || pressedKeys.contains(arrowRight) { tX += speed }
        if pressedKeys.contains(s.upKeyCode)    || pressedKeys.contains(arrowUp)    { tY -= speed }
        if pressedKeys.contains(s.downKeyCode)  || pressedKeys.contains(arrowDown)  { tY += speed }

        velocityX += (tX - velocityX) * 0.25
        velocityY += (tY - velocityY) * 0.25
        if abs(velocityX) > 0.1 || abs(velocityY) > 0.1 {
            MouseController.shared.moveMouse(dx: velocityX, dy: velocityY)
        }

        var tS: Double = 0
        if pressedKeys.contains(s.scrollUpKeyCode)   { tS += scr }
        if pressedKeys.contains(s.scrollDownKeyCode) { tS -= scr }
        scrollVelocity += (tS - scrollVelocity) * 0.3
        if abs(scrollVelocity) > 0.1 { MouseController.shared.scroll(dy: scrollVelocity) }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
private func tapCallback(
    proxy: CGEventTapProxy, type: CGEventType,
    event: CGEvent?, userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let event, let userInfo else { return nil }
    return Unmanaged<KeyboardMonitor>.fromOpaque(userInfo).takeUnretainedValue()
        .handle(proxy: proxy, type: type, event: event)
}
