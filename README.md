# MouseKeyboard

Control your Mac's mouse entirely from the keyboard — no trackpad or mouse needed.

Hold your activation key and use WASD (or arrow keys) to move the cursor, click, scroll, and drag.

## Download

**[⬇ Download latest release](https://github.com/nicoespa/mouse-keyboard/releases/latest)**

> Requires macOS 13 or later. Grant **Accessibility** permission when prompted.

---

## Default key bindings

Hold the activation key (default: **Right ⌘**), then:

| Key | Action |
|-----|--------|
| `W` `A` `S` `D` | Move cursor |
| `↑` `←` `↓` `→` | Move cursor (always available) |
| `Shift` + movement | Fast movement (3×) |
| `Space` | Left click |
| `F` | Right click |
| `E` | Scroll up |
| `Q` | Scroll down |

> **Hold** Space or F while moving = **drag**.

All bindings and speeds are fully customizable from the menu bar.

---

## Installation

1. Download `MouseKeyboard.zip` from the [latest release](https://github.com/nicoespa/mouse-keyboard/releases/latest)
2. Unzip and move `MouseKeyboard.app` to your **Applications** folder
3. Open it — a keyboard icon `⌨` will appear in the menu bar
4. When prompted, grant **Accessibility** permission in System Settings → Privacy & Security → Accessibility
5. Quit and reopen the app after granting permission

---

## Customization

Click the `⌨` icon in the menu bar → **Ajustes…**

- Change the activation key to any key (modifier or regular)
- Rebind every action key individually
- Adjust movement speed, fast multiplier, and scroll speed
- Restore defaults at any time

---

## Build from source

Requires Xcode Command Line Tools.

```bash
git clone https://github.com/nicoespa/mouse-keyboard.git
cd mouse-keyboard
./build.sh
open MouseKeyboard.app
```

---

## How it works

MouseKeyboard uses a **CGEventTap** at the macOS session level to intercept keyboard events before they reach any application. When the activation key is held, movement key events are consumed and translated into smooth cursor movement at 60 fps using velocity interpolation.

This requires the **Accessibility** permission (System Settings → Privacy & Security → Accessibility).

---

## License

MIT
