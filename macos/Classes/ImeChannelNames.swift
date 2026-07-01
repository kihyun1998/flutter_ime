// Swift mirror of the Dart-side channel contract
// (lib/src/flutter_ime_channels.dart). These strings MUST match the Dart
// constants exactly; a change here is a breaking change to the contract and
// must be applied on both sides together.

enum ImeChannels {
  static let method = "flutter_ime"
  static let inputSourceChangedEvent = "flutter_ime/input_source_changed"
  static let capsLockChangedEvent = "flutter_ime/caps_lock_changed"
}

enum ImeMethods {
  static let setEnglishKeyboard = "setEnglishKeyboard"
  static let isEnglishKeyboard = "isEnglishKeyboard"
  static let getCurrentInputSource = "getCurrentInputSource"
  static let setInputSource = "setInputSource"
  static let disableIme = "disableIME"
  static let enableIme = "enableIME"
  static let isCapsLockOn = "isCapsLockOn"
}

enum ImeArguments {
  static let sourceId = "sourceId"
}
