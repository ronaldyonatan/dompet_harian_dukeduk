import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../helpers/auth_helper.dart';
import '../helpers/localization_helper.dart';
import 'main_navigation.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import '../helpers/loading_helper.dart';

class LoginScreen extends StatefulWidget {
  final String currentLanguage;
  final Function(String) onLanguageChanged;

  const LoginScreen({
    super.key,
    required this.currentLanguage,
    required this.onLanguageChanged,
  });

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  late String _selectedLang;
  bool _rememberMe = false;
  bool _showBiometricButton = false;

  @override
  void initState() {
    super.initState();
    _selectedLang = widget.currentLanguage;
    _checkInitialLoginState();
  }

  @override
  void didUpdateWidget(covariant LoginScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentLanguage != widget.currentLanguage) {
      setState(() {
        _selectedLang = widget.currentLanguage;
      });
    }
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  // Cek apakah ada pengguna yang aktif langsung dari Firebase Authentication
  void _checkInitialLoginState() async {
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null && mounted) {
      String displayName = firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User';
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainNavigation(
            userName: displayName,
            initialLanguage: _selectedLang,
          ),
        ),
      );
      return;
    }

    bool biometricActive = await AuthHelper.isBiometricEnabled();
    if (mounted) {
      setState(() {
        _showBiometricButton = biometricActive;
      });
    }
  }

  String _getFirebaseEmail(String usernameOrEmail) {
    return usernameOrEmail.contains('@') 
        ? usernameOrEmail.trim() 
        : '${usernameOrEmail.replaceAll(RegExp(r'\s+'), '').toLowerCase().trim()}@dukeduk.com';
  }

  // Login dengan Google via Firebase Authentication Direct
  void _loginWithGoogle() async {
    final isEn = _selectedLang == 'en';
    LoadingHelper.show(context, message: isEn ? 'Signing in with Google...' : 'Masuk dengan Google...');

    try {
      final GoogleSignIn googleSignIn = GoogleSignIn(
        serverClientId: '695569336979-ogo720erocnitfk1atlm9dm9kg5b1075.apps.googleusercontent.com',
        clientId: '695569336979-ogo720erocnitfk1atlm9dg5b1075.apps.googleusercontent.com',
      );

      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        if (mounted) LoadingHelper.hide(context);
        return;
      }

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      var firebaseUser = userCredential.user;

      if (firebaseUser != null) {
        if (!mounted) return;
        LoadingHelper.hide(context);

        String displayName = firebaseUser.displayName ?? googleUser.displayName ?? 'Google User';

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userName: displayName,
              initialLanguage: _selectedLang,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      LoadingHelper.hide(context);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Login Google Gagal: $e'), 
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  // Login dengan Email/Password via Firebase Authentication Direct
  void _loginWithPassword() async {
    final isEn = _selectedLang == 'en';
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Please enter email/username and password!' : 'Masukkan email/username dan password!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    LoadingHelper.show(context, message: isEn ? 'Signing in...' : 'Sedang masuk...');
    String emailForFirebase = _getFirebaseEmail(username);

    try {
      UserCredential userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: emailForFirebase,
        password: password,
      );

      var firebaseUser = userCredential.user;
      if (firebaseUser != null) {
        if (!mounted) return;
        LoadingHelper.hide(context);

        String displayName = firebaseUser.displayName ?? username;

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MainNavigation(
              userName: displayName,
              initialLanguage: _selectedLang,
            ),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      LoadingHelper.hide(context);
      
      String friendlyMessage = isEn ? 'Failed to connect.' : 'Login Gagal.';
      if (e is FirebaseAuthException) {
        if (e.code == 'invalid-credential' || e.code == 'wrong-password' || e.code == 'user-not-found') {
          friendlyMessage = isEn ? 'Incorrect email/username or password.' : 'Email/Username atau Password salah.';
        } else if (e.code == 'network-request-failed') {
          friendlyMessage = isEn ? 'Please check your internet connection.' : 'Periksa kembali koneksi internet Anda.';
        } else {
          friendlyMessage = e.message ?? friendlyMessage;
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyMessage), backgroundColor: Colors.red),
      );
    }
  }

  // Login dengan Biometrik (Mengamankan sesi akun yang sedang aktif di Firebase)
  void _loginWithBiometric() async {
    final isEn = _selectedLang == 'en';
    final firebaseUser = FirebaseAuth.instance.currentUser;

    if (firebaseUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'No active Firebase session. Please log in with password first.' : 'Sesi pengguna tidak ditemukan. Silakan login manual lebih dahulu.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    bool authenticated = await AuthHelper.authenticateBiometric();
    if (authenticated) {
      if (!mounted) return;
      String displayName = firebaseUser.displayName ?? firebaseUser.email?.split('@')[0] ?? 'User';

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MainNavigation(
            userName: displayName,
            initialLanguage: _selectedLang,
          ),
        ),
      );
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Biometric verification cancelled or failed.' : 'Verifikasi biometrik dibatalkan atau gagal.'),
          backgroundColor: Colors.orange,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = _selectedLang == 'en';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: Colors.grey.shade100, borderRadius: BorderRadius.circular(12)),
                      child: DropdownButton<String>(
                        value: _selectedLang,
                        underline: const SizedBox(),
                        isDense: true,
                        items: const [
                          DropdownMenuItem(value: 'id', child: Text('🇮🇩 ID', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'en', child: Text('🇬🇧 EN', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setState(() => _selectedLang = val);
                            widget.onLanguageChanged(val);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: const Color(0xFF1A237E).withOpacity(0.1), shape: BoxShape.circle),
                    child: const Icon(Icons.security_rounded, size: 40, color: Color(0xFF1A237E)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEn ? 'Dukeduk Daily Wallet' : 'Dompet Harian Dukeduk', 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 6),
                Text(
                  isEn ? 'Please log in to manage your finances' : 'Silakan login untuk mengelola keuangan', 
                  textAlign: TextAlign.center, 
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Email or Username' : 'Email atau Username',
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Password' : 'Password',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => ForgotPasswordScreen(languageCode: _selectedLang)),
                      );
                    },
                    child: Text(
                      isEn ? 'Forgot Password?' : 'Lupa Password?', 
                      style: const TextStyle(fontSize: 12, color: Color(0xFF1A237E), fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                Row(
                  children: [
                    SizedBox(
                      height: 24,
                      width: 24,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (val) {
                          setState(() => _rememberMe = val ?? false);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Remember Me', style: TextStyle(fontSize: 12, color: Colors.black87)),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _loginWithPassword,
                    child: Text(
                      isEn ? 'Sign In (Login)' : 'Masuk (Login)', 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                if (_showBiometricButton) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: Color(0xFF1A237E)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _loginWithBiometric,
                      icon: const Icon(Icons.fingerprint_rounded, color: Color(0xFF1A237E)),
                      label: Text(
                        isEn ? 'Login with Biometrics' : 'Login dengan Biometrik', 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      isEn ? "Don't have an account?" : 'Belum punya akun?', 
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => RegisterScreen(languageCode: _selectedLang)),
                        );
                      },
                      child: Text(
                        isEn ? 'Register here' : 'Daftar di sini', 
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}