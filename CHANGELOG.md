## 3.0.0

**flutter_ime is now a plain Dart package.** It calls the system libraries
directly through `dart:ffi` instead of shipping a native plugin, so there is no
native code to compile, no plugin to register, and no CMake or CocoaPods in your
build. It also no longer depends on Flutter, so it can be used from a plain Dart
program.

The API is unchanged — every function keeps its name, parameters and return
type, and input-source tokens saved under 2.x still restore — so most apps
upgrade by changing the version constraint.

### Behaviour changes

* **breaking**: Failures are silent. `setEnglishKeyboard()`, `setInputSource()`,
  `disableIME()` and `enableIME()` no longer raise a `PlatformException` when
  the operation cannot be performed; they do nothing instead. These are usually
  wired to focus listeners, where an unhandled async error is worse than a
  keyboard that did not switch, and a failed restore is expected rather than
  exceptional — a saved token can name a layout the user has since removed. Code
  that caught the exception simply stops seeing it.
* **breaking**: macOS `isEnglishKeyboard()` now answers `true` for English
  layouts other than ABC and US. It asks the layout which languages it types
  rather than matching identifiers, so **Dvorak, Colemak, British, Australian
  and Canadian are recognised as English**. Under 2.x they were reported as
  non-English, which made the documented "force English" recipe drag those users
  onto ABC against their will.
* **breaking**: `onInputSourceChanged()` emits only when the value actually
  changes. 2.x emitted on every keyboard-change message, so two switches landing
  on the same answer — Korean to Japanese, say — emitted twice. Neither stream
  emits the value current when you subscribe; use `isCapsLockOn()` or
  `isEnglishKeyboard()` for that.
* **breaking**: The method-channel implementation (`MethodChannelFlutterIme`)
  and the channel-name constants are removed. They were transport details of the
  plugin that no longer exists. The platform interface and its `instance` setter
  are unchanged.
* macOS `setInputSource()` enables an installed-but-disabled input source before
  selecting it, which adds a keyboard to the user's input menu and persists
  after your app exits. This is what makes restoring reliable — the source was
  theirs to begin with — but pass only tokens that came from
  `getCurrentInputSource()`.
* macOS Caps Lock no longer needs Accessibility permission. 2.x used a global
  event monitor that silently delivered nothing unless the user had granted one.
* On macOS, a language switch can report a Caps Lock toggle. The Caps Lock key
  doubles as the input-source switch there, so changing language really does
  toggle the lock for about twelve milliseconds and a polled stream sometimes
  catches it. There is no state that distinguishes the two cases, only duration.
* macOS only: only one instance can observe input-source changes per process.
  A second one that subscribes while another still holds the observer throws a
  `StateError` rather than silently killing the first listener. (Windows has no
  such limit — it polls, with nothing process-global to contend over.)

### Documentation

* **fix**: `disableIME()` no longer claims to make non-English input
  "impossible". It detaches the IME context so composition cannot start, and it
  does not prevent pasted text — which was equally true in 2.x. Use an
  `inputFormatter` if you need a guarantee about a field's value.
* Windows event streams are polled and macOS input-source changes are pushed;
  the difference and the reason for it are documented.
* The per-platform meaning of `isEnglishKeyboard()` is stated rather than
  implied.

### Internal

* Windows uses IMM32, user32 and kernel32 directly; macOS uses Text Input Source
  Services, CoreFoundation and CoreGraphics directly.
* The Windows window-procedure hook and IME message filter are gone. A spike
  established that they never contributed anything the IME-context detach did
  not already do.
* Tests moved from `flutter_test` to `test`, and the GoogleTest and XCTest
  harnesses are deleted — all logic is now covered by `dart test`.

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
