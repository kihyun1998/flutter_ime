import Cocoa
import FlutterMacOS

/// Thin plugin shell: registers the channels and dispatches method calls to the
/// feature managers. Input-source and Caps Lock responsibilities live in
/// [InputSourceManager] and [CapsLockManager].
public class FlutterImePlugin: NSObject, FlutterPlugin {
  private let inputSourceManager = InputSourceManager()
  private let capsLockManager = CapsLockManager()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: ImeChannels.method, binaryMessenger: registrar.messenger)
    let eventChannel = FlutterEventChannel(name: ImeChannels.inputSourceChangedEvent, binaryMessenger: registrar.messenger)
    let capsLockEventChannel = FlutterEventChannel(name: ImeChannels.capsLockChangedEvent, binaryMessenger: registrar.messenger)

    let instance = FlutterImePlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
    eventChannel.setStreamHandler(instance.inputSourceManager)
    capsLockEventChannel.setStreamHandler(instance.capsLockManager)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case ImeMethods.setEnglishKeyboard:
      if inputSourceManager.setEnglishKeyboard() {
        result(nil)
      } else {
        result(FlutterError(code: "IME_ERROR", message: "Failed to set English keyboard", details: nil))
      }
    case ImeMethods.isEnglishKeyboard:
      result(inputSourceManager.isEnglishKeyboard())
    case ImeMethods.getCurrentInputSource:
      result(inputSourceManager.getCurrentInputSource())
    case ImeMethods.setInputSource:
      guard let args = call.arguments as? [String: Any],
            let sourceId = args[ImeArguments.sourceId] as? String else {
        result(FlutterError(code: "INVALID_ARGUMENT", message: "sourceId is required", details: nil))
        return
      }
      if inputSourceManager.setInputSource(sourceId) {
        result(nil)
      } else {
        result(FlutterError(code: "IME_ERROR", message: "Failed to set input source: \(sourceId)", details: nil))
      }
    case "getPlatformVersion":
      result("macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
    case ImeMethods.disableIme, ImeMethods.enableIme:
      // Not supported on macOS
      result(FlutterMethodNotImplemented)
    case ImeMethods.isCapsLockOn:
      result(capsLockManager.queryAndSyncState())
    default:
      result(FlutterMethodNotImplemented)
    }
  }
}
