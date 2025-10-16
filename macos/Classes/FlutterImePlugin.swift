import Cocoa
import FlutterMacOS
import Carbon

public class FlutterImePlugin: NSObject, FlutterPlugin {
  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "flutter_ime", binaryMessenger: registrar.messenger)
    let instance = FlutterImePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
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
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
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
}
