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
  final _passwordFocusNode = FocusNode();
  String _keyboardStatus = 'Unknown';

  @override
  void initState() {
    super.initState();

    // 비밀번호 필드가 포커스를 받으면 영어 키보드로 변경
    _passwordFocusNode.addListener(() {
      if (_passwordFocusNode.hasFocus) {
        setEnglishKeyboard();
      }
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
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('로그인'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
              onPressed: () {
                // 로그인 처리 로직
              },
              child: const Text('로그인'),
            ),
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
          ],
        ),
      ),
    );
  }
}
