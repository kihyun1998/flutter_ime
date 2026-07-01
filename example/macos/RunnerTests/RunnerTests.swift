import Cocoa
import FlutterMacOS
import XCTest


@testable import flutter_ime

// This demonstrates a simple unit test of the Swift portion of this plugin's implementation.
//
// See https://developer.apple.com/documentation/xctest for more information about using XCTest.

class RunnerTests: XCTestCase {

  func testGetPlatformVersion() {
    let plugin = FlutterImePlugin()

    let call = FlutterMethodCall(methodName: "getPlatformVersion", arguments: [])

    let resultExpectation = expectation(description: "result block must be called.")
    plugin.handle(call) { result in
      XCTAssertEqual(result as! String,
                     "macOS " + ProcessInfo.processInfo.operatingSystemVersionString)
      resultExpectation.fulfill()
    }
    waitForExpectations(timeout: 1)
  }

  // The ABC and US layouts are English; other input sources (e.g. Korean) are
  // not. Expected values come from the domain, not the implementation.
  func testEnglishInputSourceIdClassification() {
    XCTAssertTrue(isEnglishInputSourceId("com.apple.keylayout.ABC"))
    XCTAssertTrue(isEnglishInputSourceId("com.apple.keylayout.US"))
    XCTAssertFalse(
      isEnglishInputSourceId("com.apple.inputmethod.Korean.2SetKorean"))
  }

  // A Caps Lock change is emitted only when the state flips.
  func testCapsLockDidChangeOnlyOnFlip() {
    XCTAssertTrue(capsLockDidChange(current: true, last: false))
    XCTAssertTrue(capsLockDidChange(current: false, last: true))
    XCTAssertFalse(capsLockDidChange(current: true, last: true))
    XCTAssertFalse(capsLockDidChange(current: false, last: false))
  }

}
