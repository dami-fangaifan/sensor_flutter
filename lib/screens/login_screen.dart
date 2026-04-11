import 'dart:async';
import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../services/session_service.dart';
import '../models/auth_models.dart';
import 'main_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  
  // 登录表单
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();
  final _loginCodeController = TextEditingController();
  bool _isPasswordLogin = true;
  bool _obscurePassword = true;
  bool _rememberPassword = false;
  bool _isLoading = false;
  
  // 注册表单
  final _registerEmailController = TextEditingController();
  final _registerPasswordController = TextEditingController();
  final _registerConfirmController = TextEditingController();
  final _registerCodeController = TextEditingController();
  bool _obscureRegisterPassword = true;
  bool _obscureConfirmPassword = true;
  
  // 验证码倒计时
  int _loginCountdown = 0;
  int _registerCountdown = 0;
  Timer? _loginTimer;
  Timer? _registerTimer;

  String? _loginError;
  String? _registerError;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadSavedCredentials();
  }

  void _loadSavedCredentials() {
    if (SessionService.isRememberPassword()) {
      _loginEmailController.text = SessionService.getSavedEmail() ?? '';
      _loginPasswordController.text = SessionService.getSavedPassword() ?? '';
      _rememberPassword = true;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginTimer?.cancel();
    _registerTimer?.cancel();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _loginCodeController.dispose();
    _registerEmailController.dispose();
    _registerPasswordController.dispose();
    _registerConfirmController.dispose();
    _registerCodeController.dispose();
    super.dispose();
  }

  // 发送验证码
  Future<void> _sendCode(TextEditingController emailController, bool isLogin) async {
    final email = emailController.text.trim();
    if (email.isEmpty || !_isValidEmail(email)) {
      _showError('请输入有效的邮箱地址');
      return;
    }

    setState(() => _isLoading = true);
    
    final response = await AuthApiService.sendVerificationCode(email);
    
    setState(() => _isLoading = false);
    
    if (response.isSuccess) {
      _showSuccess('验证码已发送到 $email');
      _startCountdown(isLogin);
    } else {
      _showError(response.message);
    }
  }

  void _startCountdown(bool isLogin) {
    final timer = isLogin ? _loginTimer : _registerTimer;
    timer?.cancel();
    
    setState(() {
      if (isLogin) {
        _loginCountdown = 60;
      } else {
        _registerCountdown = 60;
      }
    });

    final t = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (isLogin) {
          _loginCountdown--;
          if (_loginCountdown <= 0) {
            _loginTimer?.cancel();
          }
        } else {
          _registerCountdown--;
          if (_registerCountdown <= 0) {
            _registerTimer?.cancel();
          }
        }
      });
    });

    if (isLogin) {
      _loginTimer = t;
    } else {
      _registerTimer = t;
    }
  }

  // 密码登录
  Future<void> _loginWithPassword() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text;

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _loginError = '请输入有效的邮箱地址');
      return;
    }
    if (password.isEmpty) {
      setState(() => _loginError = '请输入密码');
      return;
    }

    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    final response = await AuthApiService.login(
      email: email,
      loginType: 'password',
      credential: password,
    );

    setState(() => _isLoading = false);

    if (response.status == 'unregistered') {
      // 未注册，提示用户
      _showRegisterDialog(email);
    } else if (response.isSuccess) {
      await _handleLoginSuccess(response, email, rememberPassword: _rememberPassword, password: password);
    } else {
      setState(() => _loginError = response.message);
    }
  }

  // 验证码登录
  Future<void> _loginWithCode() async {
    final email = _loginEmailController.text.trim();
    final code = _loginCodeController.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _loginError = '请输入有效的邮箱地址');
      return;
    }
    if (code.isEmpty) {
      setState(() => _loginError = '请输入验证码');
      return;
    }

    setState(() {
      _isLoading = true;
      _loginError = null;
    });

    final response = await AuthApiService.login(
      email: email,
      loginType: 'code',
      credential: code,
    );

    setState(() => _isLoading = false);

    if (response.isSuccess) {
      // 检查是否是新用户（需要设置密码）
      if (response.data?.isNewUser == true) {
        _showSetPasswordDialog(email, response.data!.token);
      } else {
        await _handleLoginSuccess(response, email);
      }
    } else {
      setState(() => _loginError = response.message);
    }
  }

  // 注册
  Future<void> _register() async {
    final email = _registerEmailController.text.trim();
    final password = _registerPasswordController.text;
    final confirm = _registerConfirmController.text;
    final code = _registerCodeController.text.trim();

    if (email.isEmpty || !_isValidEmail(email)) {
      setState(() => _registerError = '请输入有效的邮箱地址');
      return;
    }
    if (password.isEmpty || password.length < 6) {
      setState(() => _registerError = '密码至少需要6位');
      return;
    }
    if (password != confirm) {
      setState(() => _registerError = '两次输入的密码不一致');
      return;
    }
    if (code.isEmpty) {
      setState(() => _registerError = '请输入验证码');
      return;
    }

    setState(() {
      _isLoading = true;
      _registerError = null;
    });

    final response = await AuthApiService.register(
      email: email,
      password: password,
      code: code,
    );

    setState(() => _isLoading = false);

    if (response.isSuccess) {
      _showSuccess('注册成功，请登录');
      _tabController.animateTo(0);
      _loginEmailController.text = email;
    } else {
      setState(() => _registerError = response.message);
    }
  }

  Future<void> _handleLoginSuccess(AuthResponse response, String email, {bool rememberPassword = false, String password = ''}) async {
    final session = UserSession(
      email: email,
      token: response.data?.token ?? '',
    );
    await SessionService.saveSession(session);
    
    if (rememberPassword && password.isNotEmpty) {
      await SessionService.saveRememberPassword(email: email, password: password);
    } else {
      await SessionService.clearRememberPassword();
    }

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainScreen()),
      );
    }
  }

  void _showRegisterDialog(String email) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('提示'),
        content: const Text('该邮箱尚未注册，是否前往注册？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _tabController.animateTo(1);
              _registerEmailController.text = email;
            },
            child: const Text('去注册'),
          ),
        ],
      ),
    );
  }

  void _showSetPasswordDialog(String email, String token) {
    final passwordController = TextEditingController();
    final confirmController = TextEditingController();
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('设置密码'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('欢迎使用传感器监测系统，$email'),
            const SizedBox(height: 16),
            TextField(
              controller: passwordController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '设置密码',
                hintText: '至少6位',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: confirmController,
              obscureText: true,
              decoration: const InputDecoration(
                labelText: '确认密码',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('跳过'),
          ),
          ElevatedButton(
            onPressed: () async {
              final password = passwordController.text;
              if (password.length < 6) {
                _showError('密码至少需要6位');
                return;
              }
              if (password != confirmController.text) {
                _showError('两次输入的密码不一致');
                return;
              }
              
              final response = await AuthApiService.setPassword(
                email: email,
                password: password,
                token: token,
              );
              
              if (response.isSuccess) {
                Navigator.pop(context);
                _showSuccess('密码设置成功');
              } else {
                _showError(response.message);
              }
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 40),
              // Logo
              Icon(
                Icons.sensors,
                size: 80,
                color: Theme.of(context).primaryColor,
              ),
              const SizedBox(height: 16),
              const Text(
                '传感器监测系统',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                '实时监测 · 历史分析 · 智能预警',
                style: TextStyle(color: Colors.grey[600]),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // 标签栏
              Container(
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey[700],
                  indicator: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: '登录'),
                    Tab(text: '注册'),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              
              // 表单
              SizedBox(
                height: 400,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginForm(),
                    _buildRegisterForm(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginForm() {
    return Column(
      children: [
        // 邮箱
        TextField(
          controller: _loginEmailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: '邮箱',
            prefixIcon: Icon(Icons.email_outlined),
          ),
        ),
        const SizedBox(height: 16),
        
        // 登录方式切换
        Row(
          children: [
            const Text('登录方式：'),
            Radio<bool>(
              value: true,
              groupValue: _isPasswordLogin,
              onChanged: (v) => setState(() => _isPasswordLogin = v!),
            ),
            const Text('密码'),
            Radio<bool>(
              value: false,
              groupValue: _isPasswordLogin,
              onChanged: (v) => setState(() => _isPasswordLogin = v!),
            ),
            const Text('验证码'),
          ],
        ),
        const SizedBox(height: 8),
        
        // 密码或验证码
        if (_isPasswordLogin)
          TextField(
            controller: _loginPasswordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          )
        else
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _loginCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: ElevatedButton(
                  onPressed: _loginCountdown > 0 || _isLoading
                      ? null
                      : () => _sendCode(_loginEmailController, true),
                  child: Text(_loginCountdown > 0 ? '${_loginCountdown}s' : '发送'),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        
        // 记住密码（仅密码登录时显示）
        if (_isPasswordLogin)
          Row(
            children: [
              Checkbox(
                value: _rememberPassword,
                onChanged: (v) => setState(() => _rememberPassword = v!),
              ),
              const Text('记住密码'),
            ],
          ),
        
        // 错误提示
        if (_loginError != null)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(4),
            ),
            child: Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_loginError!, style: const TextStyle(color: Colors.red)),
                ),
              ],
            ),
          ),
        const SizedBox(height: 24),
        
        // 登录按钮
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton(
            onPressed: _isLoading
                ? null
                : () => _isPasswordLogin ? _loginWithPassword() : _loginWithCode(),
            child: _isLoading
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('登录', style: TextStyle(fontSize: 16)),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterForm() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // 邮箱
          TextField(
            controller: _registerEmailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '邮箱',
              prefixIcon: Icon(Icons.email_outlined),
            ),
          ),
          const SizedBox(height: 16),
          
          // 验证码
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _registerCodeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: '验证码',
                    prefixIcon: Icon(Icons.message_outlined),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: ElevatedButton(
                  onPressed: _registerCountdown > 0 || _isLoading
                      ? null
                      : () => _sendCode(_registerEmailController, false),
                  child: Text(_registerCountdown > 0 ? '${_registerCountdown}s' : '发送'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // 密码
          TextField(
            controller: _registerPasswordController,
            obscureText: _obscureRegisterPassword,
            decoration: InputDecoration(
              labelText: '密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureRegisterPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureRegisterPassword = !_obscureRegisterPassword),
              ),
            ),
          ),
          const SizedBox(height: 16),
          
          // 确认密码
          TextField(
            controller: _registerConfirmController,
            obscureText: _obscureConfirmPassword,
            decoration: InputDecoration(
              labelText: '确认密码',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                icon: Icon(_obscureConfirmPassword ? Icons.visibility : Icons.visibility_off),
                onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
              ),
            ),
          ),
          const SizedBox(height: 8),
          
          // 错误提示
          if (_registerError != null)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red[50],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_registerError!, style: const TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 24),
          
          // 注册按钮
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _register,
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('注册', style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}
