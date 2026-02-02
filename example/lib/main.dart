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
      label: Text('키보드 상태'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.block_outlined),
      selectedIcon: Icon(Icons.block),
      label: Text('IME 비활성화'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.swap_horiz_outlined),
      selectedIcon: Icon(Icons.swap_horiz),
      label: Text('한영전환 감지'),
    ),
    NavigationRailDestination(
      icon: Icon(Icons.lock_outline),
      selectedIcon: Icon(Icons.lock),
      label: Text('영어 강제'),
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
// 1. Caps Lock 감지
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
            'Caps Lock 감지',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '비밀번호 입력 시 Caps Lock 상태를 감지합니다.\n'
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
                labelText: '비밀번호',
                border: const OutlineInputBorder(),
                suffixIcon: _isCapsLockOn
                    ? const Tooltip(
                        message: 'Caps Lock이 켜져 있습니다',
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
                    'Caps Lock이 켜져 있습니다',
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
// 2. 키보드 상태 확인
// ============================================================
class KeyboardStatusPage extends StatefulWidget {
  const KeyboardStatusPage({super.key});

  @override
  State<KeyboardStatusPage> createState() => _KeyboardStatusPageState();
}

class _KeyboardStatusPageState extends State<KeyboardStatusPage> {
  String _status = '확인 전';

  Future<void> _checkStatus() async {
    final isEnglish = await isEnglishKeyboard();
    setState(() {
      _status = isEnglish ? 'English' : 'Non-English (한글 등)';
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
            '키보드 상태 확인',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '현재 입력 소스가 영어인지 확인합니다.\n'
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
            label: const Text('상태 확인'),
          ),
        ],
      ),
    );
  }
}

// ============================================================
// 3. IME 비활성화 (Windows only)
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
            'IME 비활성화',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Windows에서 IME를 완전히 비활성화합니다.\n'
            '포커스 시 한글 입력이 불가능합니다.\n'
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
                labelText: 'IME 비활성화 테스트',
                helperText: '포커스 시 한글 입력 불가',
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
// 4. 한영전환 감지
// ============================================================
class InputSourceChangePage extends StatefulWidget {
  const InputSourceChangePage({super.key});

  @override
  State<InputSourceChangePage> createState() => _InputSourceChangePageState();
}

class _InputSourceChangePageState extends State<InputSourceChangePage> {
  final _controller = TextEditingController();
  StreamSubscription<bool>? _subscription;
  String _currentSource = '감지 중...';
  final List<String> _history = [];

  @override
  void initState() {
    super.initState();
    _subscription = onInputSourceChanged().listen((isEnglish) {
      final source = isEnglish ? 'English' : 'Korean';
      setState(() {
        _currentSource = source;
        _history.insert(0, '${DateTime.now().toString().split('.').first} → $source');
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
            '한영전환 감지',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '입력 소스(한/영) 변경을 실시간으로 감지합니다.\n'
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
                    '현재: $_currentSource',
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
                labelText: '여기서 한영전환 테스트',
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            '변경 기록',
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
                  ? const Center(child: Text('한영전환을 해보세요'))
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
// 5. 영어 강제 유지
// ============================================================
class ForceEnglishPage extends StatefulWidget {
  const ForceEnglishPage({super.key});

  @override
  State<ForceEnglishPage> createState() => _ForceEnglishPageState();
}

class _ForceEnglishPageState extends State<ForceEnglishPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  StreamSubscription<bool>? _subscription;
  bool _isActive = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocusChanged);
  }

  void _onFocusChanged() {
    if (_focusNode.hasFocus) {
      setEnglishKeyboard();
      _subscription = onInputSourceChanged().listen((isEnglish) {
        if (!isEnglish) {
          setEnglishKeyboard();
        }
      });
      setState(() {
        _isActive = true;
      });
    } else {
      _subscription?.cancel();
      _subscription = null;
      setState(() {
        _isActive = false;
      });
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
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
            '영어 강제 유지',
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '포커스 중 한영전환을 해도 자동으로 영어로 되돌립니다.\n'
            'macOS에서 IME 비활성화 대신 사용합니다.\n'
            'API: setEnglishKeyboard() + onInputSourceChanged()',
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
                    '영어 강제 활성화 중',
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
                labelText: '영어만 입력 가능',
                helperText: '한영전환해도 영어로 되돌아옴',
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
