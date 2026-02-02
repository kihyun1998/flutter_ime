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
