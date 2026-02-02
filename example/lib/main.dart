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
      home: const LoginPage(),
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _imeTestController = TextEditingController();
  final _inputSourceTestController = TextEditingController();
  final _macosImeTestController = TextEditingController();
  final _passwordFocusNode = FocusNode();
  final _imeTestFocusNode = FocusNode();
  final _inputSourceTestFocusNode = FocusNode();
  final _macosImeTestFocusNode = FocusNode();
  String _keyboardStatus = 'Unknown';
  String _passwordDisplay = '';

  // 한영전환 감지 (포커스 시에만)
  StreamSubscription<bool>? _inputSourceSubscription;
  String _inputSourceStatus = '';

  // macOS IME 비활성화용
  StreamSubscription<bool>? _macosImeSubscription;

  // Caps Lock 상태
  StreamSubscription<bool>? _capsLockSubscription;
  bool _isCapsLockOn = false;

  @override
  void initState() {
    super.initState();


    // IME 테스트 필드: 포커스 시 IME 비활성화, 포커스 해제 시 활성화
    _imeTestFocusNode.addListener(() {
      if (_imeTestFocusNode.hasFocus) {
        disableIME();
      } else {
        enableIME();
      }
    });

    // 한영전환 감지 테스트: 항상 구독 (디버깅용)
    _inputSourceSubscription = onInputSourceChanged().listen((isEnglish) {
      debugPrint('>>> 한영전환 감지: ${isEnglish ? "English" : "Korean"}');
      setState(() {
        _inputSourceStatus = isEnglish ? 'English' : 'Korean';
      });
    });

    // macOS용 IME 비활성화: 포커스 시 영어로 전환 + 한영전환 감지해서 되돌림
    _macosImeTestFocusNode.addListener(() {
      if (_macosImeTestFocusNode.hasFocus) {
        // 포커스 받으면 영어로 전환
        setEnglishKeyboard();
        // 한영전환 감지해서 영어로 되돌림
        _macosImeSubscription = onInputSourceChanged().listen((isEnglish) {
          if (!isEnglish) {
            setEnglishKeyboard();
          }
        });
      } else {
        // 포커스 잃으면 구독 취소
        _macosImeSubscription?.cancel();
        _macosImeSubscription = null;
      }
    });

    // 비밀번호 필드 포커스 시에만 Caps Lock 감지
    _passwordFocusNode.addListener(_onPasswordFocusChanged);
  }

  void _onPasswordFocusChanged() async {
    if (_passwordFocusNode.hasFocus) {
      // 포커스 시 영어 키보드로 변경 + Caps Lock 상태 확인
      setEnglishKeyboard();

      // 현재 Caps Lock 상태 확인
      final capsLock = await isCapsLockOn();
      setState(() {
        _isCapsLockOn = capsLock;
      });

      // 변경 감지 구독 시작
      _capsLockSubscription = onCapsLockChanged().listen((isOn) {
        debugPrint('>>> Caps Lock 상태 변경: ${isOn ? "ON" : "OFF"}');
        setState(() {
          _isCapsLockOn = isOn;
        });
      });
    } else {
      // 포커스 해제 시 구독 취소 및 상태 초기화
      _capsLockSubscription?.cancel();
      _capsLockSubscription = null;
      setState(() {
        _isCapsLockOn = false;
      });
    }
  }

  Future<void> _checkKeyboardStatus() async {
    final isEnglish = await isEnglishKeyboard();
    setState(() {
      _keyboardStatus = isEnglish ? 'English' : 'Non-English';
    });
  }

  @override
  void dispose() {
    _inputSourceSubscription?.cancel();
    _macosImeSubscription?.cancel();
    _capsLockSubscription?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _imeTestController.dispose();
    _inputSourceTestController.dispose();
    _macosImeTestController.dispose();
    _passwordFocusNode.dispose();
    _imeTestFocusNode.dispose();
    _inputSourceTestFocusNode.dispose();
    _macosImeTestFocusNode.dispose();
    super.dispose();
  }

  void _onLogin() {
    setState(() {
      _passwordDisplay = _passwordController.text;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: '이메일',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              focusNode: _passwordFocusNode,
              decoration: InputDecoration(
                labelText: '비밀번호',
                border: const OutlineInputBorder(),
                suffixIcon: _isCapsLockOn
                    ? const Tooltip(
                        message: 'Caps Lock이 켜져 있습니다',
                        child: Icon(Icons.keyboard_capslock, color: Colors.orange),
                      )
                    : null,
              ),
              obscureText: true,
            ),
            if (_isCapsLockOn)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Caps Lock이 켜져 있습니다',
                  style: TextStyle(color: Colors.orange, fontSize: 12),
                ),
              ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _onLogin,
              child: const Text('로그인'),
            ),
            if (_passwordDisplay.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('입력된 비밀번호: $_passwordDisplay'),
            ],
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _checkKeyboardStatus,
              child: const Text('현재 키보드 상태 확인'),
            ),
            const SizedBox(height: 8),
            Text(
              'Keyboard: $_keyboardStatus',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _imeTestController,
              focusNode: _imeTestFocusNode,
              decoration: const InputDecoration(
                labelText: 'IME 비활성화 테스트 (Windows only)',
                helperText: '포커스 시 한글 입력 불가',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _inputSourceTestController,
              focusNode: _inputSourceTestFocusNode,
              decoration: InputDecoration(
                labelText: '한영전환 감지 테스트',
                helperText: '포커스 중 한영전환 감지: $_inputSourceStatus',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            TextField(
              controller: _macosImeTestController,
              focusNode: _macosImeTestFocusNode,
              decoration: const InputDecoration(
                labelText: 'macOS용 IME 비활성화 테스트',
                helperText: '한영전환해도 영어로 되돌림 (Windows/macOS)',
                border: OutlineInputBorder(),
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(
                  RegExp(r'[a-zA-Z0-9!@#$%^&*()_+\-=\[\]{};:"\\|,.<>/?`~ ]'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
