import Cocoa
import Carbon
import FlutterMacOS

/// Owns all input-source responsibilities on macOS: switching to English,
/// reading and restoring the input-source token, English-mode checks, and
/// emitting input-source-changed events. Serves as the stream handler for the
/// input-source-changed event channel.
class InputSourceManager: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?

  override init() {
    super.init()
    // Subscribe to input source change notifications.
    DistributedNotificationCenter.default().addObserver(
      self,
      selector: #selector(inputSourceChanged),
      name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
      object: nil
    )
  }

  @objc private func inputSourceChanged() {
    eventSink?(isEnglishKeyboard())
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  // MARK: - Input source operations

  /// Set IME to English keyboard.
  func setEnglishKeyboard() -> Bool {
    // English keyboard input source ID.
    let englishInputSourceID = "com.apple.keylayout.ABC"

    // Create filter to find English input source.
    let filter = [kTISPropertyInputSourceID: englishInputSourceID] as CFDictionary

    guard let sourceList = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let inputSource = sourceList.first else {
      return false
    }

    // Enable and select the input source.
    TISEnableInputSource(inputSource)
    let status = TISSelectInputSource(inputSource)

    return status == noErr
  }

  /// Check if current IME is English keyboard.
  func isEnglishKeyboard() -> Bool {
    guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
      return false
    }

    guard let sourceID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
      return false
    }

    let currentID = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String

    // Check if current input source is English.
    // Common English keyboard IDs: ABC, US, etc.
    return currentID.contains("com.apple.keylayout.ABC") ||
           currentID.contains("com.apple.keylayout.US")
  }

  /// Get current input source ID.
  func getCurrentInputSource() -> String? {
    guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
      return nil
    }

    guard let sourceID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
      return nil
    }

    return Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
  }

  /// Set input source by ID.
  func setInputSource(_ sourceId: String) -> Bool {
    let filter = [kTISPropertyInputSourceID: sourceId] as CFDictionary

    guard let sourceList = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let inputSource = sourceList.first else {
      return false
    }

    TISEnableInputSource(inputSource)
    let status = TISSelectInputSource(inputSource)

    return status == noErr
  }
}
