## 2.1.4

* **fix**: Windows `setInputSource()` no longer crashes on a malformed saved input-source token (the conversion/sentence segments are now parsed defensively instead of throwing)
* **fix**: macOS — stop leaking Caps Lock event monitors and the input-source notification observer across listen/cancel cycles
* **fix**: Windows — subclass the window procedure via `SetWindowSubclass` so the hook no longer relies on mutable static state (safer with multiple windows)
* **docs**: Document the value from `getCurrentInputSource()` as an opaque, platform-specific token that must only be round-tripped; fix platform-support doc drift
* **chore**: Internal refactor into focused native managers (input source / Caps Lock) with a single source of truth for the channel contract
* **test**: Add Dart unit tests, a Windows GoogleTest harness, and a macOS XCTest target, run across a 3-platform GitHub Actions CI

## 2.1.3

* **fix**: Sync `last_caps_lock_state` when `isCapsLockOn()` is called via method channel (Windows, macOS)

## 2.1.2

* **chore**: Translate example app UI from Korean to English

## 2.1.1

* **feat**: Add `getCurrentInputSource()` to get current keyboard input source ID (Windows, macOS)
* **feat**: Add `setInputSource()` to restore previously saved input source (Windows, macOS)
* **fix**: Fix macOS build error due to `capsLockEventSink` private access level

## 2.1.0

* **feat**: Add `disableIME()` and `enableIME()` functions (Windows only)
* **feat**: Disable IME to prevent non-English input on focused TextField
* **feat**: Add `onInputSourceChanged()` stream to detect keyboard layout changes (Windows, macOS)
* **feat**: Add `isCapsLockOn()` to check Caps Lock state (Windows, macOS)
* **feat**: Add `onCapsLockChanged()` stream to detect Caps Lock state changes (Windows, macOS)
* **fix**: Fix `isEnglishKeyboard()` always returning false due to incorrect flag check

## 2.0.0

* **breaking**: Refactor to top-level functions (removed FlutterIme class)
* **feat**: Simplified API - call `setEnglishKeyboard()` directly without instantiation

## 1.1.0

* **feat**: Add macOS support
* **feat**: Support English keyboard switching on macOS

## 1.0.3

* **fix**: Update license

## 1.0.2

* **fix**: Update license

## 1.0.1

* **fix**: Lower SDK constraint to >=3.0.0
* **chore**: Update flutter_lints to ^4.0.0

## 1.0.0

* **feat**: Initial release
* **feat**: Windows IME English switching function
* **feat**: IME status checking function
