import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_ime/flutter_ime.dart';

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
