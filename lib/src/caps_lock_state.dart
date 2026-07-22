/// Pure interpretation of the macOS Caps Lock hardware state.
///
/// Kept free of `dart:ffi` so it can be unit-tested on any platform, and so the
/// FFI layer stays a thin adapter with no branching logic of its own.
library;

/// Whether Caps Lock is on, or null while the answer is still a transient.
///
/// [alphaShiftSet] is the Caps Lock bit of the event-source modifier flags, and
/// [keyIsDown] whether the Caps Lock key is physically held.
///
/// **The flag alone is not the answer, because on macOS the Caps Lock key is
/// also the input-source switch.** Tapping it to change language sets the
/// alpha-shift flag for as long as the key is down and clears it on release.
/// Measured on a real machine, that is about twelve milliseconds:
///
///     9655ms  alphaShift=true   keyDown=true
///     9667ms  alphaShift=false  keyDown=false
///
/// A fifty-millisecond poll lands inside that window perhaps one time in four,
/// which is exactly what the bug looked like from outside: switching to Korean
/// *sometimes* announced that Caps Lock had turned on and immediately off. A
/// consumer showing a Caps Lock warning on a password field — the thing this
/// package mostly exists for — saw it flash for no reason.
///
/// The rule is not "a short press is a language switch". Nothing here measures
/// time, and it must not: whether a tap latches Caps Lock or changes language
/// is a keyboard setting, so any rule based on duration would be right for one
/// user's configuration and wrong for the next one's. The rule is that **a
/// reading only counts once the key is up**, which works for every
/// configuration because it follows from what Caps Lock *is*. A lock that did
/// not outlast the key being released would not be a lock.
///
/// So a held key has no answer yet. Returning null rather than guessing lets
/// the change stream hold its previous value and ask again — the same
/// treatment it gives a Windows IME context that is momentarily unreadable.
bool? capsLockState({required bool alphaShiftSet, required bool keyIsDown}) {
  if (keyIsDown) return null;
  return alphaShiftSet;
}
