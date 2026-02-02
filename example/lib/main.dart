import 'dart:async';

import 'package:flutter/material.dart';
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
  final _passwordFocusNode = FocusNode();
  final _imeTestFocusNode = FocusNode();
  final _inputSourceTestFocusNode = FocusNode();
  String _keyboardStatus = 'Unknown';
  String _passwordDisplay = '';

  // 한영전환 감지 (포커스 시에만)
  StreamSubscription<bool>? _inputSourceSubscription;
  String _inputSourceStatus = '';

  @override
  void initState() {
    super.initState();

    // 비밀번호 필드가 포커스를 받으면 영어 키보드로 변경
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        setEnglishKeyboard();
      }
    });

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
    _emailController.dispose();
    _passwordController.dispose();
    _imeTestController.dispose();
    _inputSourceTestController.dispose();
    _passwordFocusNode.dispose();
    _imeTestFocusNode.dispose();
    _inputSourceTestFocusNode.dispose();
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
              decoration: const InputDecoration(
                labelText: '비밀번호',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
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
          ],
        ),
      ),
    );
  }
}
