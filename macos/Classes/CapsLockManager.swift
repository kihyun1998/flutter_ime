import Cocoa
import FlutterMacOS

/// Owns Caps Lock state querying and change monitoring on macOS, and emits Caps
/// Lock change events. Serves as the stream handler for the caps-lock-changed
/// event channel.
///
/// NOTE: The event-monitor lifecycle here intentionally mirrors the previous
/// implementation (including its leak of the local monitor). Fixing that leak
/// is tracked separately and must not be conflated with this structural split.
class CapsLockManager: NSObject, FlutterStreamHandler {
  private var capsLockEventSink: FlutterEventSink?
  private var lastCapsLockState: Bool = false
  private var flagsChangedMonitor: Any?

  /// Check if Caps Lock is on.
  func isCapsLockOn() -> Bool {
    return NSEvent.modifierFlags.contains(.capsLock)
  }

  /// Reads the live state and syncs the cached value, so the next monitored
  /// change compares against a fresh baseline. Backs the isCapsLockOn method
  /// call.
  func queryAndSyncState() -> Bool {
    let state = isCapsLockOn()
    lastCapsLockState = state
    return state
  }

  // MARK: - FlutterStreamHandler

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    capsLockEventSink = events
    startMonitoring()
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    stopMonitoring()
    capsLockEventSink = nil
    return nil
  }

  // MARK: - Monitoring

  private func startMonitoring() {
    lastCapsLockState = isCapsLockOn()
    flagsChangedMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.handleFlagsChanged(event)
    }
    // Also monitor local events (when app has focus).
    NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.handleFlagsChanged(event)
      return event
    }
  }

  private func stopMonitoring() {
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
