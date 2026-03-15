import AppKit
import CoreGraphics

class MouseController {
    static let shared = MouseController()

    private var isLeftDown  = false
    private var isRightDown = false

    // Move cursor by (dx, dy) pixels. +x = right, +y = down (CG coords).
    func moveMouse(dx: Double, dy: Double) {
        let newPos = clampedPos(from: currentCGPos(), dx: dx, dy: dy)

        // CGWarpMouseCursorPosition is the most reliable way to move the cursor —
        // it works with just Accessibility permission, no Input Monitoring needed.
        CGWarpMouseCursorPosition(newPos)

        // Also post a mouse event so apps receive hover/drag notifications.
        // Post to cgSessionEventTap (NOT cghidEventTap — that needs Input Monitoring).
        let eventType: CGEventType
        let button: CGMouseButton
        if isLeftDown {
            eventType = .leftMouseDragged;  button = .left
        } else if isRightDown {
            eventType = .rightMouseDragged; button = .right
        } else {
            eventType = .mouseMoved;        button = .left
        }
        CGEvent(mouseEventSource: nil, mouseType: eventType,
                mouseCursorPosition: newPos, mouseButton: button)?
            .post(tap: .cgSessionEventTap)
    }

    func mouseDown(_ button: CGMouseButton) {
        let pos  = currentCGPos()
        let type: CGEventType = button == .left ? .leftMouseDown : .rightMouseDown
        if let ev = CGEvent(mouseEventSource: nil, mouseType: type,
                            mouseCursorPosition: pos, mouseButton: button) {
            ev.flags = []
            ev.post(tap: .cgSessionEventTap)
        }
        if button == .left { isLeftDown = true } else { isRightDown = true }
    }

    func mouseUp(_ button: CGMouseButton) {
        let pos  = currentCGPos()
        let type: CGEventType = button == .left ? .leftMouseUp : .rightMouseUp
        if let ev = CGEvent(mouseEventSource: nil, mouseType: type,
                            mouseCursorPosition: pos, mouseButton: button) {
            ev.flags = []
            ev.post(tap: .cgSessionEventTap)
        }
        if button == .left { isLeftDown = false } else { isRightDown = false }
    }

    func releaseAllButtons() {
        if isLeftDown  { mouseUp(.left) }
        if isRightDown { mouseUp(.right) }
    }

    // Pixel-based smooth scroll. Positive dy = scroll up.
    func scroll(dy: Double) {
        CGEvent(scrollWheelEvent2Source: nil, units: .pixel,
                wheelCount: 1, wheel1: Int32(dy), wheel2: 0, wheel3: 0)?
            .post(tap: .cgSessionEventTap)
    }

    // MARK: - Coordinate helpers

    func currentCGPos() -> CGPoint {
        let p = NSEvent.mouseLocation
        // NSEvent uses AppKit coords (origin bottom-left); CG uses top-left origin.
        let h = NSScreen.screens.first?.frame.height ?? 0
        return CGPoint(x: p.x, y: h - p.y)
    }

    private func clampedPos(from current: CGPoint, dx: Double, dy: Double) -> CGPoint {
        var x = current.x + dx
        var y = current.y + dy
        if let s = NSScreen.screens.first {
            x = max(0, min(x, s.frame.width  - 1))
            y = max(0, min(y, s.frame.height - 1))
        }
        return CGPoint(x: x, y: y)
    }
}
