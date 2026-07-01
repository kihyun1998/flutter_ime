// Pure, side-effect-free classification helpers extracted from the managers so
// they can be unit-tested without live Text Input Source (TIS) or NSEvent APIs.

/// Whether an input-source ID denotes an English keyboard layout.
///
/// The macOS ABC and US layouts are treated as English.
func isEnglishInputSourceId(_ id: String) -> Bool {
  return id.contains("com.apple.keylayout.ABC") ||
         id.contains("com.apple.keylayout.US")
}

/// Whether a Caps Lock change should be emitted: only when the state actually
/// flips relative to the last known value.
func capsLockDidChange(current: Bool, last: Bool) -> Bool {
  return current != last
}
