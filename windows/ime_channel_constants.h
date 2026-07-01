#ifndef FLUTTER_PLUGIN_IME_CHANNEL_CONSTANTS_H_
#define FLUTTER_PLUGIN_IME_CHANNEL_CONSTANTS_H_

// C++ mirror of the Dart-side channel contract (lib/src/flutter_ime_channels.dart).
// These strings MUST match the Dart constants exactly; a change here is a
// breaking change to the contract and must be applied on both sides together.
namespace flutter_ime {

namespace channels {
constexpr char kMethod[] = "flutter_ime";
constexpr char kInputSourceChangedEvent[] = "flutter_ime/input_source_changed";
constexpr char kCapsLockChangedEvent[] = "flutter_ime/caps_lock_changed";
}  // namespace channels

namespace methods {
constexpr char kSetEnglishKeyboard[] = "setEnglishKeyboard";
constexpr char kIsEnglishKeyboard[] = "isEnglishKeyboard";
constexpr char kGetCurrentInputSource[] = "getCurrentInputSource";
constexpr char kSetInputSource[] = "setInputSource";
constexpr char kDisableIme[] = "disableIME";
constexpr char kEnableIme[] = "enableIME";
constexpr char kIsCapsLockOn[] = "isCapsLockOn";
}  // namespace methods

namespace arguments {
constexpr char kSourceId[] = "sourceId";
}  // namespace arguments

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_IME_CHANNEL_CONSTANTS_H_
