import Cocoa
import FlutterMacOS

/// Owns Caps Lock state querying and change monitoring on macOS, and emits Caps
/// Lock change events. Serves as the stream handler for the caps-lock-changed
/// event channel.
///
/// Both the global and local flags-changed monitors are retained and removed
/// together; starting is idempotent, and monitors are also torn down on deinit,
/// so no monitor is leaked across onListen/onCancel cycles.
class CapsLockManager: NSObject, FlutterStreamHandler {
  private var capsLockEventSink: FlutterEventSink?
  private var lastCapsLockState: Bool = false
  private var globalFlagsMonitor: Any?
  private var localFlagsMonitor: Any?

  deinit {
    stopMonitoring()
  }

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
    // Remove any existing monitors first so a repeated start (e.g. onListen
    // called again without an onCancel) does not orphan the previous ones.
    stopMonitoring()

    lastCapsLockState = isCapsLockOn()
    globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.handleFlagsChanged(event)
    }
    // Also monitor local events (when app has focus).
    localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
      self?.handleFlagsChanged(event)
      return event
    }
  }

  private func stopMonitoring() {
    if let monitor = globalFlagsMonitor {
      NSEvent.removeMonitor(monitor)
      globalFlagsMonitor = nil
    }
    if let monitor = localFlagsMonitor {
      NSEvent.removeMonitor(monitor)
      localFlagsMonitor = nil
    }
  }

  private func handleFlagsChanged(_ event: NSEvent) {
    let currentCapsLock = event.modifierFlags.contains(.capsLock)
    if capsLockDidChange(current: currentCapsLock, last: lastCapsLockState) {
      lastCapsLockState = currentCapsLock
      capsLockEventSink?(currentCapsLock)
    }
  }
}
