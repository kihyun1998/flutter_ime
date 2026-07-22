import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ime/flutter_ime.dart';
import 'package:flutter_ime/flutter_ime_ffi.dart';
import 'package:flutter_ime/flutter_ime_platform_interface.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter IME Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _selectedIndex = 0;

  static const List<NavigationRailDestination> _destinations = [
    NavigationRailDestination(
      icon: Icon(Icons.keyboard_capslock_outlined),
      selectedIcon: Icon(Icons.keyboard_capslock),
      label: Text('Caps Lock'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.language_outlined),
      selectedIcon: Icon(Icons.language),
      label: Text('Keyboard Status'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.block_outlined),
      selectedIcon: Icon(Icons.block),
      label: Text('Disable IME'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.swap_horiz_outlined),
      selectedIcon: Icon(Icons.swap_horiz),
      label: Text('Input Source'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.memory_outlined),
      selectedIcon: Icon(Icons.memory),
      label: Text('FFI (opt-in)'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.lock_outline),
      selectedIcon: Icon(Icons.lock),
      label: Text('Force English'),
    ),
  ];

  static const List<Widget> _pages = [
    CapsLockPage(),
    KeyboardStatusPage(),
    ImeDisablePage(),
    InputSourceChangePage(),
    FfiPage(),
    ForceEnglishPage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: _selectedIndex,
            onDestinationSelected: (index) {
              setState(() {
                _selectedIndex = index;
              });
            },
            extended: true,
            minExtendedWidth: 180,
            destinations: _destinations,
          ),
          const VerticalDivider(thickness: 1, width: 1),
          Expanded(
            child: _pages[_selectedIndex],
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 1. Caps Lock Detection
// ============================================================
class CapsLockPage extends StatefulWidget {
  const CapsLockPage({super.key});

  @override
  State<CapsLockPage> createState() => _CapsLockPageState();
}

class _CapsLockPageState extends State<CapsLockPage> {
  final _passwordController = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription<bool>? _capsLockSubscription;
  bool _isCapsLockOn = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() async {
    if (_focusNode.hasFocus) {
      final capsLock = await isCapsLockOn();
      setState(() {
        _isCapsLockOn = capsLock;
      });

      _capsLockSubscription = onCapsLockChanged().listen((isOn) {
        setState(() {
          _isCapsLockOn = isOn;
        });
      });
    } else {
      _capsLockSubscription?.cancel();
      _capsLockSubscription = null;
      setState(() {
        _isCapsLockOn = false;
      });
    }
  }

  @override
  void dispose() {
    _capsLockSubscription?.cancel();
    _passwordController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Caps Lock Detection',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Detects Caps Lock status when entering password.\n'
            'API: isCapsLockOn(), onCapsLockChanged()',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 300,
            child: TextField(
              controller: _passwordController,
              focusNode: _focusNode,
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: _isCapsLockOn
                    ? const Tooltip(
                        message: 'Caps Lock is on',
                        child:
                            Icon(Icons.keyboard_capslock, color: Colors.orange),
                      )
                    : null,
              ),
              obscureText: true,
            ),
          ),
          if (_isCapsLockOn)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.orange, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Caps Lock is on',
                    style: TextStyle(color: Colors.orange),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ============================================================
// 2. Keyboard Status Check
// ============================================================
class KeyboardStatusPage extends StatefulWidget {
  const KeyboardStatusPage({super.key});

  @override
  State<KeyboardStatusPage> createState() => _KeyboardStatusPageState();
}

class _KeyboardStatusPageState extends State<KeyboardStatusPage> {
  String _status = 'Not checked';

  Future<void> _checkStatus() async {
    final isEnglish = await isEnglishKeyboard();
    setState(() {
      _status = isEnglish ? 'English' : 'Non-English (Korean, etc.)';
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Keyboard Status Check',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Checks if current input source is English.\n'
            'API: isEnglishKeyboard()',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _status.contains('English')
                        ? Icons.check_circle
                        : _status.contains('Non')
                            ? Icons.cancel
                            : Icons.help_outline,
                    color: _status.contains('English')
                        ? Colors.green
                        : _status.contains('Non')
                            ? Colors.orange
                            : Colors.grey,
                    size: 32,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _status,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _checkStatus,
            icon: const Icon(Icons.refresh),
            label: const Text('Check Status'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 3. Disable IME (Windows only)
// ============================================================
class ImeDisablePage extends StatefulWidget {
  const ImeDisablePage({super.key});

  @override
  State<ImeDisablePage> createState() => _ImeDisablePageState();
}

class _ImeDisablePageState extends State<ImeDisablePage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() {
      if (_focusNode.hasFocus) {
        disableIME();
      } else {
        enableIME();
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Disable IME',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Completely disables IME on Windows.\n'
            'Korean input is not possible when focused.\n'
            'API: disableIME(), enableIME()',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Windows only',
              style: TextStyle(color: Colors.blue),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 300,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                labelText: 'Disable IME Test',
                helperText: 'Korean input disabled when focused',
                border: OutlineInputBorder(),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 4. Input Source Change Detection
// ============================================================
class InputSourceChangePage extends StatefulWidget {
  const InputSourceChangePage({super.key});

  @override
  State<InputSourceChangePage> createState() => _InputSourceChangePageState();
}

class _InputSourceChangePageState extends State<InputSourceChangePage> {
  final _controller = TextEditingController();
  StreamSubscription<bool>? _subscription;
  String _currentSource = 'Detecting...';
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _subscription = onInputSourceChanged().listen((isEnglish) {
      final source = isEnglish ? 'English' : 'Korean';
      setState(() {
        _currentSource = source;
        _history.insert(
            0, '${DateTime.now().toString().split('.').first} → $source');
        if (_history.length > 10) _history.removeLast();
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Input Source Change Detection',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Detects input source (Korean/English) changes in real-time.\n'
            'API: onInputSourceChanged()',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 24),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _currentSource == 'English' ? Icons.abc : Icons.translate,
                    size: 32,
                    color: _currentSource == 'English'
                        ? Colors.blue
                        : Colors.green,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Current: $_currentSource',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: 300,
            child: TextField(
              controller: _controller,
              decoration: const InputDecoration(
                labelText: 'Test input source switching here',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Change History',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Expanded(
            child: Container(
              width: 350,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey[300]!),
                borderRadius: BorderRadius.circular(8),
              ),
              child: _history.isEmpty
                  ? const Center(child: Text('Try switching input source'))
                  : ListView.builder(
                      itemCount: _history.length,
                      itemBuilder: (context, index) {
                        return ListTile(
                          dense: true,
                          title: Text(
                            _history[index],
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        );
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 5. Force English Mode
// ============================================================
class ForceEnglishPage extends StatefulWidget {
  const ForceEnglishPage({super.key});

  @override
  State<ForceEnglishPage> createState() => _ForceEnglishPageState();
}

class _ForceEnglishPageState extends State<ForceEnglishPage> {
  // For checking current input source
  final _testController = TextEditingController();
  String? _currentInputSource;

  // For force English TextField
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription<bool>? _subscription;
  bool _isActive = false;
  String? _savedInputSource;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
    _refreshInputSource();
  }

  Future<void> _refreshInputSource() async {
    final source = await getCurrentInputSource();
    setState(() {
      _currentInputSource = source;
    });
  }

  void _onFocusChanged() async {
    if (_focusNode.hasFocus) {
      // 현재 키보드 저장 후 영어로 전환
      _savedInputSource = await getCurrentInputSource();
      setEnglishKeyboard();
      _subscription = onInputSourceChanged().listen((isEnglish) {
        if (!isEnglish) {
          setEnglishKeyboard();
        }
        _refreshInputSource();
      });
      setState(() {
        _isActive = true;
      });
      _refreshInputSource();
    } else {
      _subscription?.cancel();
      _subscription = null;
      // Restore to saved keyboard (direct set without isEnglish check - cost saving)
      if (_savedInputSource != null) {
        await setInputSource(_savedInputSource!);
      }
      setState(() {
        _isActive = false;
      });
      _refreshInputSource();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _testController.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Force English Mode',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Automatically switches back to English even when switching input sources while focused.\n'
            'Automatically restores to previous keyboard when unfocused.\n'
            'API: getCurrentInputSource(), setInputSource(), setEnglishKeyboard()',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.grey[600],
                ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.purple[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text(
              'Windows / macOS',
              style: TextStyle(color: Colors.purple),
            ),
          ),
          const SizedBox(height: 24),

          // 현재 Input Source 표시
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Current Input Source',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh, size: 20),
                        onPressed: _refreshInputSource,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SelectableText(
                    _currentInputSource ?? '(Unknown)',
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                  if (_savedInputSource != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Saved value: $_savedInputSource',
                      style: TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.blue[600],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          // 테스트용 일반 TextField
          SizedBox(
            width: 300,
            child: TextField(
              controller: _testController,
              decoration: const InputDecoration(
                labelText: 'Normal TextField (for testing)',
                helperText: 'Korean input allowed',
                border: OutlineInputBorder(),
              ),
              onTap: _refreshInputSource,
            ),
          ),
          const SizedBox(height: 16),

          // 영어 강제 TextField
          if (_isActive)
            Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.green[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check, color: Colors.green, size: 16),
                  SizedBox(width: 4),
                  Text(
                    'Force English active',
                    style: TextStyle(color: Colors.green),
                  ),
                ],
              ),
            ),
          SizedBox(
            width: 300,
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              decoration: const InputDecoration(
                labelText: 'English only',
                helperText: 'Restores to previous keyboard when unfocused',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};:"\\|,.<>/?`~ ]'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 6. FFI (opt-in) — Windows English keyboard through pure Dart
// ============================================================
//
// While the FFI migration is in progress the native plugin is still the
// default. This page installs the FFI implementation on entry and restores the
// previous one on exit, so the *public* API path is genuinely exercised
// end-to-end — top-level function, platform gating, platform interface, FFI —
// without rerouting the pages whose operations are not ported yet.
class FfiPage extends StatefulWidget {
  const FfiPage({super.key});

  @override
  State<FfiPage> createState() => _FfiPageState();
}

class _FfiPageState extends State<FfiPage> {
  FlutterImePlatform? _previous;
  String _log = '';
  bool _installed = false;

  /// Resolved once on entry rather than read during build: resolving walks the
  /// process's window tree on a cache miss.
  String _window = '(not resolved)';

  /// The selected macOS input source, its ID and the languages it types. Read
  /// on entry and on demand, not during build.
  String _inputSource = '(not read)';

  /// The token from the last save, awaiting a restore.
  String? _saved;

  String _comparison = '(not compared yet)';
  bool? _comparisonOk;

  /// Guarded by disableIME() while focused.
  final _guardedController = TextEditingController();
  final _guardedFocus = FocusNode();

  /// Never guarded. If Korean cannot be typed here either, a "no Hangul"
  /// result in the guarded field proves nothing — the IME simply was not
  /// running.
  final _controlController = TextEditingController();

  int _cycles = 0;

  StreamSubscription<bool>? _capsSub;
  StreamSubscription<bool>? _sourceSub;
  bool? _capsLive;
  final List<String> _streamLog = [];

  @override
  void initState() {
    super.initState();
    if (Platform.isWindows || Platform.isMacOS) {
      _previous = FlutterImePlatform.instance;
      final ffi = FfiFlutterIme();
      FlutterImePlatform.instance = ffi;
      _installed = true;
      _window = ffi.describeResolvedWindow() ?? '(none)';
      _inputSource = ffi.describeCurrentInputSource() ?? '(none)';
    }

    // The guarded field is guarded here, and only here. Without this the field
    // is guarded in name only: Hangul types through it normally and the readout
    // reports a failure that belongs to the demo, not to the implementation.
    _guardedFocus.addListener(() {
      if (_guardedFocus.hasFocus) {
        disableIME();
      } else {
        enableIME();
      }
    });

    // The readouts are computed during build, so they need a rebuild per
    // keystroke or they sit at "(nothing typed)" while text goes in.
    _guardedController.addListener(() => setState(() {}));
    _controlController.addListener(() => setState(() {}));

    // Windows only. Both streams are polled there, and nothing is polled until
    // these subscriptions exist. On macOS neither stream is ported yet, so
    // subscribing would only start the native plugin's monitors for a readout
    // this page does not show.
    if (Platform.isWindows) _subscribe();
  }

  void _subscribe() {
    if (_capsSub != null) return;
    _capsSub = onCapsLockChanged().listen((on) {
      setState(() {
        _capsLive = on;
        _streamLog.insert(0, 'onCapsLockChanged -> $on');
      });
    });
    _sourceSub = onInputSourceChanged().listen((english) {
      setState(() => _streamLog.insert(
          0, 'onInputSourceChanged -> ${english ? "English" : "non-English"}'));
    });
  }

  /// Drops the subscriptions without touching widget state, so it is safe from
  /// deactivate and dispose where setState would throw.
  void _cancelSubscriptions() {
    _capsSub?.cancel();
    _capsSub = null;
    _sourceSub?.cancel();
    _sourceSub = null;
  }

  bool get _streaming => _capsSub != null;

  @override
  void deactivate() {
    // Restore here rather than in dispose. A page transition runs the incoming
    // page's initState before the outgoing page's dispose, so restoring in
    // dispose would leave the FFI instance installed while the next page is
    // already using it — which matters for the Input Source page, whose whole
    // purpose here is to show what the *native* implementation reports.
    _detachFfi();
    super.deactivate();
  }

  @override
  void dispose() {
    _detachFfi();
    _guardedController.dispose();
    _guardedFocus.dispose();
    _controlController.dispose();
    super.dispose();
  }

  /// Detaches everything this page installed: the stream subscriptions and the
  /// FFI platform instance.
  ///
  /// Idempotent, because deactivate can run without a following dispose.
  void _detachFfi() {
    // Cancel first: these subscriptions belong to the FFI instance's pollers,
    // and leaving them attached would keep polling after this page is gone.
    _cancelSubscriptions();

    final previous = _previous;
    if (_installed && previous != null) {
      FlutterImePlatform.instance = previous;
      _installed = false;
    }
  }

  void _append(String line) => setState(() => _log = '$line\n$_log');

  Future<void> _check() async {
    final english = await isEnglishKeyboard();
    _append('isEnglishKeyboard() -> $english');
  }

  Future<void> _setEnglish() async {
    await setEnglishKeyboard();
    _append('setEnglishKeyboard() called');
    await _check();
  }

  /// Reports whether [text] contains Hangul and whether that matches
  /// [wantHangul], listing the code points either way.
  Widget _hangulReadout(String label, String text, {required bool wantHangul}) {
    final has = _containsHangul(text);
    final ok = has == wantHangul;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: text.isEmpty
            ? Colors.grey[200]
            : (ok ? Colors.green[50] : Colors.red[50]),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            text.isEmpty
                ? '$label: (nothing typed)'
                : (ok ? '$label: OK' : '$label: UNEXPECTED'),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: text.isEmpty
                  ? Colors.grey[800]
                  : (ok ? Colors.green[900] : Colors.red[900]),
            ),
          ),
          const SizedBox(height: 4),
          SelectableText(
            _runesOf(text),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
          ),
        ],
      ),
    );
  }

  Future<void> _setEnglishDelayed() async {
    _append('--- scheduled: switch to another app now ---');
    await Future<void>.delayed(const Duration(seconds: 3));
    final resolved = _resolveAgain();
    await setEnglishKeyboard();
    final english = await isEnglishKeyboard();
    _append('while unfocused: window=$resolved  isEnglish=$english');
  }

  /// Runs disable/enable back to back several times. The acceptance criterion
  /// is that the IME still works afterwards, which the control field shows.
  Future<void> _queryCapsLock() async {
    final on = await isCapsLockOn();
    _append('isCapsLockOn() -> $on');
  }

  Future<void> _runCycles() async {
    for (var i = 0; i < 5; i++) {
      await disableIME();
      await enableIME();
    }
    setState(() => _cycles += 5);
    _append('ran 5 disable/enable cycles (total: $_cycles)');
  }

  /// Syllables AC00-D7A3, compatibility jamo 3131-3163, conjoining jamo
  /// 1100-11FF. Checked by code point rather than by eye: a composing glyph
  /// can look like Hangul on screen without having been committed.
  static bool _containsHangul(String s) => s.runes.any((r) =>
      (r >= 0xAC00 && r <= 0xD7A3) ||
      (r >= 0x3131 && r <= 0x3163) ||
      (r >= 0x1100 && r <= 0x11FF));

  static String _runesOf(String s) => s.runes
      .map((r) => 'U+${r.toRadixString(16).toUpperCase().padLeft(4, '0')}')
      .join(' ');

  /// Reads the token through BOTH implementations back to back and reports
  /// whether they agree.
  ///
  /// The token format is a hard compatibility requirement — consumers persist
  /// these, so one written by 2.x must still restore after upgrading.
  /// `_previous` is the method-channel implementation this page displaced on
  /// entry, so both reads see the same keyboard state a moment apart.
  Future<void> _compareWithNative() async {
    final ffiToken = await getCurrentInputSource();
    final nativeToken = await _previous?.getCurrentInputSource();
    final match = ffiToken == nativeToken;
    setState(() {
      _comparison = '${match ? "MATCH" : "MISMATCH"}\n'
          '  ffi:    $ffiToken\n'
          '  native: $nativeToken';
      _comparisonOk = match;
    });
  }

  Future<void> _save() async {
    final token = await getCurrentInputSource();
    setState(() => _saved = token);
    _append('getCurrentInputSource() -> ${token ?? "null"}');
  }

  Future<void> _restore() async {
    final token = _saved;
    if (token == null) return;
    await setInputSource(token);
    _append('setInputSource("$token") called');
    await _check();
  }

  /// Feeds setInputSource a token it must reject. The app surviving this
  /// button is the point of it.
  ///
  /// [bad] comes from the caller because the two platforms fail for different
  /// reasons. Windows tokens have structure and can be malformed — 2.1.4 fixed
  /// a crash where one reached the numeric parser and threw across the method
  /// channel. macOS tokens are opaque identifiers with nothing to malform, so
  /// the failure worth showing there is the one a consumer actually hits: a
  /// token naming an input source that is no longer installed.
  Future<void> _restoreUnusable(String bad) async {
    await setInputSource(bad);
    _append('setInputSource("$bad") survived — rejected, no throw');
  }

  String _resolveAgain() {
    final instance = FlutterImePlatform.instance;
    return instance is FfiFlutterIme
        ? (instance.describeResolvedWindow() ?? '(none)')
        : '(not the FFI instance)';
  }

  /// Re-reads the selected input source through the FFI instance.
  void _readSource() {
    final instance = FlutterImePlatform.instance;
    setState(() => _inputSource = instance is FfiFlutterIme
        ? (instance.describeCurrentInputSource() ?? '(none)')
        : '(not the FFI instance)');
  }

  Future<void> _checkAndRead() async {
    await _check();
    _readSource();
  }

  Future<void> _setEnglishAndRead() async {
    await setEnglishKeyboard();
    _append('setEnglishKeyboard() called');
    await _checkAndRead();
  }

  Future<void> _saveAndRead() async {
    await _save();
    _readSource();
  }

  Future<void> _restoreAndRead() async {
    await _restore();
    _readSource();
  }

  @override
  Widget build(BuildContext context) {
    if (!_installed) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Text(
            'The FFI implementation currently supports Windows and macOS.'),
      );
    }
    if (Platform.isMacOS) return _buildMacos(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FFI (opt-in)',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'These calls go through dart:ffi to imm32.dll directly. No method '
            'channel and no native plugin code is involved.',
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.blueGrey[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Resolved window',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(
                    _window,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'flutterView is the handle the native plugin used. '
                    'runnerWindow or foregroundWindow means the preferred '
                    'lookup missed.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 420,
            child: TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type here, switch with Han/Yeong, then check',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Row(children: [
            FilledButton.icon(
              onPressed: _setEnglish,
              icon: const Icon(Icons.abc),
              label: const Text('setEnglishKeyboard()'),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _check,
              icon: const Icon(Icons.help_outline),
              label: const Text('isEnglishKeyboard()'),
            ),
            const SizedBox(width: 12),
            TextButton(
              onPressed: () => setState(() => _log = ''),
              child: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 24),
          Text('Live streams', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Polled, not pushed: Windows has no callback FFI can receive. '
            'Toggle Caps Lock, or switch layout with Han/Yeong, and watch the '
            'log. Neither stream emits the value it started from, and neither '
            'repeats a value.',
          ),
          const SizedBox(height: 12),
          Row(children: [
            Switch(
              value: _streaming,
              onChanged: (on) => setState(() {
                if (on) {
                  _subscribe();
                } else {
                  _cancelSubscriptions();
                  _capsLive = null;
                }
              }),
            ),
            const SizedBox(width: 8),
            Text(_streaming
                ? 'subscribed — polling every 50ms'
                : 'unsubscribed — nothing is polled'),
          ]),
          const SizedBox(height: 8),
          Row(children: [
            Icon(Icons.keyboard_capslock,
                color: _capsLive == true ? Colors.orange : Colors.grey),
            const SizedBox(width: 8),
            Text('stream says Caps Lock: '
                '${_capsLive == null ? "(no change seen yet)" : (_capsLive! ? "ON" : "OFF")}'),
            const SizedBox(width: 16),
            OutlinedButton.icon(
              onPressed: _queryCapsLock,
              icon: const Icon(Icons.help_outline),
              label: const Text('isCapsLockOn()'),
            ),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            height: 130,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: _streamLog.isEmpty
                ? const Text('(no events yet)')
                : ListView(
                    children: _streamLog
                        .take(20)
                        .map((line) => Text(line,
                            style: const TextStyle(
                                fontFamily: 'monospace', fontSize: 12)))
                        .toList(),
                  ),
          ),
          const SizedBox(height: 24),
          Text('Disable / enable IME',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Focusing the guarded field detaches the IME context, so '
            'composition cannot start. The control field is never guarded — if '
            'Korean cannot be typed there either, a clean guarded field proves '
            'nothing, because the IME simply was not running.',
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: 420,
            child: TextField(
              controller: _guardedController,
              focusNode: _guardedFocus,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Guarded — press Han/Yeong and type 안녕',
              ),
            ),
          ),
          _hangulReadout('guarded', _guardedController.text, wantHangul: false),
          const SizedBox(height: 16),
          SizedBox(
            width: 420,
            child: TextField(
              controller: _controlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Control — 안녕 must be typable here',
              ),
            ),
          ),
          _hangulReadout('control', _controlController.text, wantHangul: true),
          const SizedBox(height: 12),
          Row(children: [
            OutlinedButton.icon(
              onPressed: _runCycles,
              icon: const Icon(Icons.loop),
              label: const Text('Run 5 disable/enable cycles'),
            ),
            const SizedBox(width: 12),
            Text('cycles run: $_cycles',
                style: TextStyle(color: Colors.grey[600])),
          ]),
          const SizedBox(height: 24),
          _tokenCompatibilitySection(context),
          const SizedBox(height: 24),
          Text('Save and restore',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Save the current keyboard, switch it by hand with Han/Yeong, then '
            'restore. The token format is unchanged from 2.x, so one saved '
            'before upgrading still restores.',
          ),
          const SizedBox(height: 8),
          SelectableText(
            'saved token: ${_saved ?? "(nothing saved)"}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: _save,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('getCurrentInputSource()'),
            ),
            OutlinedButton.icon(
              onPressed: _saved == null ? null : _restore,
              icon: const Icon(Icons.restore),
              label: const Text('setInputSource(saved)'),
            ),
            OutlinedButton.icon(
              onPressed: () => _restoreUnusable('00000412:abc:0'),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('restore a malformed token'),
            ),
          ]),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _setEnglishDelayed,
            icon: const Icon(Icons.timer_outlined),
            label: const Text('Run in 3s (then click another app)'),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _log.isEmpty ? '(no calls yet)' : _log,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  /// The FFI-token-versus-native-token check, which reads the same on both
  /// platforms.
  ///
  /// The token format is a hard compatibility requirement everywhere — a
  /// consumer persists one under 2.x and has to be able to restore it under
  /// 3.x — so the two builds below show the identical panel rather than each
  /// wording it their own way.
  Widget _tokenCompatibilitySection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('2.x compatibility',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        const Text(
          'Reads the token through the FFI implementation and through the '
          'native plugin back to back. They must agree: consumers persist '
          'these tokens, so one saved under 2.x has to restore under 3.x.',
        ),
        const SizedBox(height: 8),
        FilledButton.icon(
          onPressed: _compareWithNative,
          icon: const Icon(Icons.compare_arrows),
          label: const Text('Compare FFI token vs native token'),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _comparisonOk == null
                ? Colors.grey[200]
                : (_comparisonOk! ? Colors.green[50] : Colors.red[50]),
            borderRadius: BorderRadius.circular(8),
          ),
          child: SelectableText(
            _comparison,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: _comparisonOk == null
                  ? Colors.grey[800]
                  : (_comparisonOk! ? Colors.green[900] : Colors.red[900]),
            ),
          ),
        ),
      ],
    );
  }

  /// The macOS half of this page.
  ///
  /// Separate from the Windows build rather than woven into it with platform
  /// checks: the two platforms have almost nothing in common here. Windows
  /// toggles a conversion mode inside one layout and needs a window handle to
  /// do it; macOS selects a whole layout and needs no window at all. Only
  /// setEnglishKeyboard and isEnglishKeyboard are ported on macOS so far, so
  /// the disable/enable, token and polled-stream sections have nothing to show.
  Widget _buildMacos(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('FFI (opt-in) — macOS',
              style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: 8),
          const Text(
            'These calls go through dart:ffi to Text Input Source Services '
            'directly. No method channel and no native plugin code is '
            'involved. Everything else on this page falls through to the '
            'native plugin for now.',
          ),
          const SizedBox(height: 20),
          Card(
            color: Colors.blueGrey[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Selected input source',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  SelectableText(
                    _inputSource,
                    style:
                        const TextStyle(fontFamily: 'monospace', fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'The first language listed is what decides the answer '
                    'below. It is read straight from the input source, not '
                    'guessed from its ID.',
                    style: TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const SizedBox(
            width: 480,
            child: TextField(
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: 'Type here, switch layout with Caps Lock or the '
                    'menu bar, then check',
              ),
            ),
          ),
          const SizedBox(height: 16),
          Wrap(spacing: 12, runSpacing: 8, children: [
            FilledButton.icon(
              onPressed: _setEnglishAndRead,
              icon: const Icon(Icons.abc),
              label: const Text('setEnglishKeyboard()'),
            ),
            OutlinedButton.icon(
              onPressed: _checkAndRead,
              icon: const Icon(Icons.help_outline),
              label: const Text('isEnglishKeyboard()'),
            ),
            TextButton(
              onPressed: () => setState(() => _log = ''),
              child: const Text('Clear'),
            ),
          ]),
          const SizedBox(height: 24),
          Card(
            color: Colors.amber[50],
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('The case 2.x got wrong',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text(
                    'In System Settings › Keyboard › Input Sources, add an '
                    'English layout that is not ABC or U.S. — Dvorak, Colemak, '
                    'British, Australian or Canadian. Select it, then press '
                    'isEnglishKeyboard().\n\n'
                    'It must answer true. 2.x answered false for every one of '
                    'them, and the "force English" recipe in the README reacts '
                    'to a false by switching the keyboard — so 2.x dragged '
                    'those users to ABC every time they focused a password '
                    'field.\n\n'
                    'Worth trying the other direction too: ABC — AZERTY types '
                    'French, and its ID starts with the exact string 2.x '
                    'matched on. It must answer false.',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text('Save and restore',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Save the current input source, switch it by hand from the menu '
            'bar or with setEnglishKeyboard(), then restore. Try it with a '
            'non-English source such as a Korean IME — the token is the input '
            'source ID and its format is unchanged from 2.x, so one saved '
            'before upgrading still restores.\n\n'
            'A source you have switched off in System Settings since saving is '
            'switched back on before being selected. A source you have removed '
            'outright cannot come back: that restore fails, leaves you on the '
            'keyboard you are already using, and does not throw.',
          ),
          const SizedBox(height: 12),
          SelectableText(
            'saved token: ${_saved ?? "(nothing saved)"}',
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(spacing: 12, runSpacing: 8, children: [
            FilledButton.tonalIcon(
              onPressed: _saveAndRead,
              icon: const Icon(Icons.bookmark_add_outlined),
              label: const Text('getCurrentInputSource()'),
            ),
            OutlinedButton.icon(
              onPressed: _saved == null ? null : _restoreAndRead,
              icon: const Icon(Icons.restore),
              label: const Text('setInputSource(saved)'),
            ),
            OutlinedButton.icon(
              onPressed: () =>
                  _restoreUnusable('com.apple.keylayout.NoSuchLayout'),
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('restore an uninstalled source'),
            ),
          ]),
          const SizedBox(height: 24),
          _tokenCompatibilitySection(context),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            constraints: const BoxConstraints(minHeight: 120),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(8),
            ),
            child: SelectableText(
              _log.isEmpty ? '(no calls yet)' : _log,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
