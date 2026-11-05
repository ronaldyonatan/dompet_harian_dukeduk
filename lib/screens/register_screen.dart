import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../helpers/Loading_Helper.dart'; // Import LoadingHelper global

class RegisterScreen extends StatefulWidget {
  final String languageCode;
  const RegisterScreen({super.key, required this.languageCode});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  final _confirmPasswordController = TextEditingController();
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;
  bool _submitted = false;

  String get _passwordStrength {
    final password = _passwordController.text;
    final variety = [
      RegExp(r'[a-z]'),
      RegExp(r'[A-Z]'),
      RegExp(r'[0-9]'),
      RegExp(r'[^a-zA-Z0-9]'),
    ].where((pattern) => pattern.hasMatch(password)).length;
    if (password.length < 8 || variety < 2) return 'Lemah';
    if (password.length < 12 || variety < 3) return 'Sedang';
    return 'Kuat';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _getFirebaseEmail(String usernameOrEmail) {
    return usernameOrEmail.contains('@')
        ? usernameOrEmail.trim()
        : '${usernameOrEmail.replaceAll(RegExp(r'\s+'), '').toLowerCase().trim()}@dukeduk.com';
  }

  void _register() async {
    setState(() => _submitted = true);
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Semua kolom harus diisi!')));
      return;
    }

    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(username)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Gunakan email aktif agar akun dapat dipulihkan saat lupa password.',
          ),
        ),
      );
      return;
    }

    // Validasi aturan bawaan Firebase: Password minimal 6 karakter
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Password minimal harus 6 karakter untuk keamanan Cloud!',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (password != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Konfirmasi password belum sama.')),
      );
      return;
    }

    // Tampilkan Loading Panel Global
    LoadingHelper.show(context, message: 'Mendaftarkan akun ke Cloud...');

    try {
      String emailForFirebase = _getFirebaseEmail(username);

      // 1. Daftarkan akun langsung ke Firebase Authentication[cite: 11]
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
            email: emailForFirebase,
            password: password,
          );

      // 2. Update nama tampilan (display name) pada Firebase Auth
      await userCredential.user?.updateDisplayName(name);

      // 3. Simpan data profil pengguna ke Cloud Firestore
      if (userCredential.user != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
              'uid': userCredential.user!.uid,
              'name': name,
              'username': username,
              'email': emailForFirebase,
              'created_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
      }

      if (!mounted) return;
      LoadingHelper.hide(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Registrasi Berhasil! Silakan Masuk.'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      LoadingHelper.hide(context);

      String errorMessage = 'Registrasi gagal.';
      if (e.code == 'email-already-in-use') {
        errorMessage = 'Email sudah terdaftar di Firebase Authentication. Silakan login atau gunakan Lupa Password.';
      } else if (e.code == 'weak-password' ||
          e.code == 'password-does-not-meet-requirements') {
        errorMessage = 'Password ditolak karena tidak memenuhi kebijakan keamanan Firebase. Gunakan password lebih panjang dengan kombinasi huruf besar, huruf kecil, angka, dan simbol.';
      } else {
        errorMessage = e.message ?? errorMessage;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } catch (e) {
      if (!mounted) return;
      LoadingHelper.hide(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Terjadi kesalahan: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text(
          'Daftar Akun Baru',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Container(
            constraints: const BoxConstraints(maxWidth: 420),
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Buat Akun Dukeduk',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Lengkapi data Anda untuk mulai mencatat keuangan.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: const Icon(
                      Icons.person_outline_rounded,
                      color: Color(0xFF1A237E),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Email aktif',
                    helperText: 'Gunakan email aktif agar fitur Lupa Password bisa digunakan',
                    helperStyle: const TextStyle(fontSize: 10),
                    prefixIcon: const Icon(
                      Icons.alternate_email_rounded,
                      color: Color(0xFF1A237E),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Password',
                    helperText: 'Minimal 6 karakter. Disarankan 12+ karakter dengan kombinasi huruf, angka, dan simbol.',
                    helperMaxLines: 3,
                    errorText:
                        (_submitted || _passwordController.text.isNotEmpty) &&
                            _passwordController.text.length < 6
                        ? 'Password minimal 6 karakter.'
                        : null,
                    suffixIcon: IconButton(
                      tooltip: _obscurePassword
                          ? 'Tampilkan password'
                          : 'Sembunyikan password',
                      onPressed: () =>
                          setState(() => _obscurePassword = !_obscurePassword),
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF1A237E),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                if (_passwordController.text.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Kekuatan password: $_passwordStrength (perkiraan)',
                    style: TextStyle(
                      fontSize: 12,
                      color: _passwordStrength == 'Lemah'
                          ? Colors.red.shade700
                          : _passwordStrength == 'Sedang'
                          ? Colors.orange.shade900
                          : Colors.green.shade700,
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                TextField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmation,
                  autocorrect: false,
                  enableSuggestions: false,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Ulangi Password',
                    prefixIcon: const Icon(
                      Icons.lock_outline_rounded,
                      color: Color(0xFF1A237E),
                    ),
                    suffixIcon: IconButton(
                      tooltip: _obscureConfirmation
                          ? 'Tampilkan konfirmasi password'
                          : 'Sembunyikan konfirmasi password',
                      onPressed: () => setState(
                        () => _obscureConfirmation = !_obscureConfirmation,
                      ),
                      icon: Icon(
                        _obscureConfirmation
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                      ),
                    ),
                    errorText:
                        (_submitted ||
                                _confirmPasswordController.text.isNotEmpty) &&
                            _confirmPasswordController.text !=
                                _passwordController.text
                        ? 'Konfirmasi password belum sama.'
                        : null,
                    helperText:
                        _confirmPasswordController.text.isNotEmpty &&
                            _confirmPasswordController.text ==
                                _passwordController.text
                        ? 'Password sudah sama.'
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 28),
                SizedBox(
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _register,
                    child: const Text(
                      'Daftar Sekarang',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
