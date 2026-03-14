import Foundation

class AppSettings {
    static let shared = AppSettings()
    private let defaults = UserDefaults.standard

    // Modifier key
    var modifierKeyCode: Int = 54      // Right Command (⌘) — default, rarely used for shortcuts
    var modifierRawMask: Int = 0x0010  // NX_DEVICERCMDKEYMASK

    // Movement keys
    var upKeyCode: Int    = 13   // W
    var downKeyCode: Int  = 1    // S
    var leftKeyCode: Int  = 0    // A
    var rightKeyCode: Int = 2    // D

    // Action keys
    var leftClickKeyCode: Int  = 49   // Space
    var rightClickKeyCode: Int = 3    // F
    var scrollUpKeyCode: Int   = 14   // E
    var scrollDownKeyCode: Int = 12   // Q

    // Speed
    var normalSpeed: Double      = 15.0
    var fastMultiplier: Double   = 3.0
    var scrollSpeed: Double      = 8.0

    // -------------------------------------------------------------------------
    // Modifier key type detection
    //
    // "Modifier keys" generate flagsChanged events (no keyDown/keyUp).
    // "Regular keys" generate keyDown/keyUp and are consumed directly.
    // We track the activation key differently depending on its type.
    // -------------------------------------------------------------------------

    /// True when the configured modifier key is a hardware modifier
    /// (Option, Command, Control, Shift, Caps Lock) that uses flagsChanged.
    var modifierIsHardwareModifier: Bool {
        return Self.hardwareModifierKeyCodes.contains(modifierKeyCode)
    }

    /// Raw flag masks for hardware modifier keys (from IOKit NX device masks).
    static let modifierRawMasks: [Int: Int] = [
        54: 0x0010,   // Right Command
        55: 0x0008,   // Left Command
        56: 0x0002,   // Left Shift
        58: 0x0020,   // Left Option
        59: 0x0001,   // Left Control
        60: 0x0200,   // Right Shift
        61: 0x0040,   // Right Option
        62: 0x2000,   // Right Control
    ]

    static let hardwareModifierKeyCodes: Set<Int> = Set(modifierRawMasks.keys)

    func load() {
        if let v = defaults.object(forKey: "modifierKeyCode") as? Int { modifierKeyCode = v }
        if let v = defaults.object(forKey: "modifierRawMask") as? Int { modifierRawMask = v }
        if let v = defaults.object(forKey: "upKeyCode")       as? Int { upKeyCode = v }
        if let v = defaults.object(forKey: "downKeyCode")     as? Int { downKeyCode = v }
        if let v = defaults.object(forKey: "leftKeyCode")     as? Int { leftKeyCode = v }
        if let v = defaults.object(forKey: "rightKeyCode")    as? Int { rightKeyCode = v }
        if let v = defaults.object(forKey: "leftClickKeyCode")  as? Int { leftClickKeyCode = v }
        if let v = defaults.object(forKey: "rightClickKeyCode") as? Int { rightClickKeyCode = v }
        if let v = defaults.object(forKey: "scrollUpKeyCode")   as? Int { scrollUpKeyCode = v }
        if let v = defaults.object(forKey: "scrollDownKeyCode") as? Int { scrollDownKeyCode = v }
        if let v = defaults.object(forKey: "normalSpeed")     as? Double { normalSpeed = v }
        if let v = defaults.object(forKey: "fastMultiplier")  as? Double { fastMultiplier = v }
        if let v = defaults.object(forKey: "scrollSpeed")     as? Double { scrollSpeed = v }
    }

    func save() {
        defaults.set(modifierKeyCode,    forKey: "modifierKeyCode")
        defaults.set(modifierRawMask,    forKey: "modifierRawMask")
        defaults.set(upKeyCode,          forKey: "upKeyCode")
        defaults.set(downKeyCode,        forKey: "downKeyCode")
        defaults.set(leftKeyCode,        forKey: "leftKeyCode")
        defaults.set(rightKeyCode,       forKey: "rightKeyCode")
        defaults.set(leftClickKeyCode,   forKey: "leftClickKeyCode")
        defaults.set(rightClickKeyCode,  forKey: "rightClickKeyCode")
        defaults.set(scrollUpKeyCode,    forKey: "scrollUpKeyCode")
        defaults.set(scrollDownKeyCode,  forKey: "scrollDownKeyCode")
        defaults.set(normalSpeed,        forKey: "normalSpeed")
        defaults.set(fastMultiplier,     forKey: "fastMultiplier")
        defaults.set(scrollSpeed,        forKey: "scrollSpeed")
    }

    func setModifierKey(keyCode: Int, rawMask: Int) {
        modifierKeyCode = keyCode
        modifierRawMask = rawMask
        save()
    }

    func resetToDefaults() {
        modifierKeyCode = 54; modifierRawMask = 0x0010
        upKeyCode = 13; downKeyCode = 1; leftKeyCode = 0; rightKeyCode = 2
        leftClickKeyCode = 49; rightClickKeyCode = 3
        scrollUpKeyCode = 14; scrollDownKeyCode = 12
        normalSpeed = 15.0; fastMultiplier = 3.0; scrollSpeed = 8.0
        save()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Human-readable key names
// ─────────────────────────────────────────────────────────────────────────────

func keyName(for keyCode: Int) -> String {
    let map: [Int: String] = [
        // Letters
        0:"A", 1:"S", 2:"D", 3:"F", 4:"H", 5:"G", 6:"Z", 7:"X", 8:"C", 9:"V",
        11:"B", 12:"Q", 13:"W", 14:"E", 15:"R", 16:"Y", 17:"T",
        31:"O", 32:"U", 34:"I", 35:"P", 37:"L", 38:"J", 40:"K",
        45:"N", 46:"M",
        // Numbers & symbols
        18:"1", 19:"2", 20:"3", 21:"4", 22:"6", 23:"5",
        24:"=", 25:"9", 26:"7", 27:"-", 28:"8", 29:"0",
        30:"]", 33:"[", 39:"'", 41:";", 42:"\\", 43:",", 44:"/", 47:".",
        10:"§",
        // Special
        36:"↩", 48:"⇥", 49:"Space", 50:"`", 51:"⌫", 53:"Esc",
        // Arrows
        123:"←", 124:"→", 125:"↓", 126:"↑",
        // Navigation
        115:"Home", 116:"PgUp", 117:"Del", 119:"End", 121:"PgDn",
        // Function keys
        96:"F5", 97:"F6", 98:"F7", 99:"F3", 100:"F8", 101:"F9",
        103:"F11", 105:"F13", 107:"F14", 109:"F10", 111:"F12",
        113:"F15", 106:"F16", 64:"F17", 79:"F18", 80:"F19",
        122:"F1", 120:"F2",
        // Modifier keys (shown when used as activation key)
        54:"⌘R", 55:"⌘L", 56:"⇧L", 57:"Caps", 58:"⌥L",
        59:"⌃L", 60:"⇧R", 61:"⌥R", 62:"⌃R",
    ]
    return map[keyCode] ?? "(\(keyCode))"
}
