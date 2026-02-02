import Cocoa
import FlutterMacOS
import Carbon

public class FlutterImePlugin: NSObject, FlutterPlugin, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  fileprivate var capsLockEventSink: FlutterEventSink?
  private var lastCapsLockState: Bool = false
  private var flagsChangedMonitor: Any?

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_ime", binaryMessenger: registrar.messenger)
    let eventChannel = FlutterEventChannel(name: "flutter_ime/input_source_changed", binaryMessenger: registrar.messenger)
    let capsLockEventChannel = FlutterEventChannel(name: "flutter_ime/caps_lock_changed", binaryMessenger: registrar.messenger)

    let instance = FlutterImePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance)
    capsLockEventChannel.setStreamHandler(CapsLockStreamHandler(plugin: instance))

    // Subscribe to input source change notifications
    DistributedNotificationCenter.default().addObserver(
      instance,
      selector: #selector(inputSourceChanged),
      name: NSNotification.Name(kTISNotifySelectedKeyboardInputSourceChanged as String),
      object: nil
    )
  }

  @objc private func inputSourceChanged() {
    let isEnglish = isEnglishKeyboard()
    eventSink?(isEnglish)
  }

  // MARK: - FlutterStreamHandler

  public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    self.eventSink = events
    return nil
  }

  public func onCancel(withArguments arguments: Any?) -> FlutterError? {
    self.eventSink = nil
    return nil
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setEnglishKeyboard":
      let success = setEnglishKeyboard()
      if success {
        result(nil)
      } else {
        result(FlutterError(code: "IME_ERROR", message: "Failed to set English keyboard", details: nil))
      }
    case "isEnglishKeyboard":
      result(isEnglishKeyboard())
    case "getCurrentInputSource":
      result(getCurrentInputSource())
    case "setInputSource":
      guard let args = call.arguments as? [String: Any],
            let sourceId = args["sourceId"] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "sourceId is required", details: nil))
        return
      }
      let success = setInputSource(sourceId)
      if success {
        result(nil)
      } else {
        result(FlutterError(code: "IME_ERROR", message: "Failed to set input source: \(sourceId)", details: nil))
      }
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case "disableIME", "enableIME":
      // Not supported on macOS
      result(FlutterMethodNotImplemented)
    case "isCapsLockOn":
      result(isCapsLockOn())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Set IME to English keyboard
  private func setEnglishKeyboard() -> Bool {
    // English keyboard input source ID
    let englishInputSourceID = "com.apple.keylayout.ABC"

    // Create filter to find English input source
    let filter = [kTISPropertyInputSourceID: englishInputSourceID] as CFDictionary

    guard let sourceList = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let inputSource = sourceList.first else {
      return false
    }

    // Enable and select the input source
    TISEnableInputSource(inputSource)
    let status = TISSelectInputSource(inputSource)

    return status == noErr
  }

  /// Check if current IME is English keyboard
  private func isEnglishKeyboard() -> Bool {
    guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
      return false
    }

    guard let sourceID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
      return false
    }

    let currentID = Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String

    // Check if current input source is English
    // Common English keyboard IDs: ABC, US, etc.
    return currentID.contains("com.apple.keylayout.ABC") ||
           currentID.contains("com.apple.keylayout.US")
  }

  /// Get current input source ID
  private func getCurrentInputSource() -> String? {
    guard let currentSource = TISCopyCurrentKeyboardInputSource()?.takeRetainedValue() else {
      return nil
    }

    guard let sourceID = TISGetInputSourceProperty(currentSource, kTISPropertyInputSourceID) else {
      return nil
    }

    return Unmanaged<CFString>.fromOpaque(sourceID).takeUnretainedValue() as String
  }

  /// Set input source by ID
  private func setInputSource(_ sourceId: String) -> Bool {
    let filter = [kTISPropertyInputSourceID: sourceId] as CFDictionary

    guard let sourceList = TISCreateInputSourceList(filter, false)?.takeRetainedValue() as? [TISInputSource],
          let inputSource = sourceList.first else {
      return false
    }

    TISEnableInputSource(inputSource)
    let status = TISSelectInputSource(inputSource)

    return status == noErr
  }

  /// Check if Caps Lock is on
  private func isCapsLockOn() -> Bool {
    return NSEvent.modifierFlags.contains(.capsLock)
  }

  /// Starts monitoring Caps Lock state changes.
  func startCapsLockMonitoring() {
    lastCapsLockState = isCapsLockOn()
    flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.handleFlagsChanged(event)
    }
    // Also monitor local events (when app has focus)
    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.handleFlagsChanged(event)
      return event
    }
  }

  /// Stops monitoring Caps Lock state changes.
  func stopCapsLockMonitoring() {
    if let monitor = flagsChangedMonitor {
      NSEvent.removeMonitor(monitor)
      flagsChangedMonitor = nil
    }
  }

  private func handleFlagsChanged(_ event: NSEvent) {
    let currentCapsLock = event.modifierFlags.contains(.capsLock)
    if currentCapsLock != lastCapsLockState {
      lastCapsLockState = currentCapsLock
      capsLockEventSink?(currentCapsLock)
    }
  }
}

/// Stream handler for Caps Lock state changes.
class CapsLockStreamHandler: NSObject, FlutterStreamHandler {
  private weak var plugin: FlutterImePlugin?

  init(plugin: FlutterImePlugin) {
    self.plugin = plugin
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    plugin?.capsLockEventSink = events
    plugin?.startCapsLockMonitoring()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    plugin?.stopCapsLockMonitoring()
    plugin?.capsLockEventSink = nil
    return nil
  }
}
