import Cocoa
import FlutterMacOS
import XCTest

// There is no longer anything native to test.
//
// This file used to unit-test the plugin's Swift classification helpers through
// `@testable import flutter_ime`. As of 3.0.0 flutter_ime is a pure Dart
// package with no Swift in it at all, and what this covered now lives in the
// Dart suite — `test/english_input_source_test.dart` for the classification and
// `test/change_stream_test.dart` for the change rules — where it runs under
// `dart test` on any host instead of needing Xcode and a macOS runner.
//
// The target itself is left in place rather than unpicked from the Xcode
// project by hand: it is woven through thirty-odd references in project.pbxproj,
// and a mistake there breaks the example app's build for everyone. An empty
// target costs nothing and is honest about there being nothing left to run.
// Deliberately empty. A placeholder assertion would be ceremony: no CI job runs
// this target any more, so it would never execute and would only look like
// coverage to anyone reading the file list.
class RunnerTests: XCTestCase {
}
