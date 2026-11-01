import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../helpers/loading_helper.dart'; // Import LoadingHelper global

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

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _getFirebaseEmail(String usernameOrEmail) {
    return usernameOrEmail.contains('@') 
        ? usernameOrEmail.trim() 
        : '${usernameOrEmail.replaceAll(RegExp(r'\s+'), '').toLowerCase().trim()}@dukeduk.com';
  }

  void _register() async {
    final name = _nameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();

    if (name.isEmpty || username.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Semua kolom harus diisi!')),
      );
      return;
    }

    // Validasi aturan bawaan Firebase: Password minimal 6 karakter
    if (password.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Password minimal harus 6 karakter untuk keamanan Cloud!'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    // Tampilkan Loading Panel Global
    LoadingHelper.show(context, message: 'Mendaftarkan akun ke Cloud...');

    try {
      String emailForFirebase = _getFirebaseEmail(username);
      
      // 1. Daftarkan akun langsung ke Firebase Authentication[cite: 11]
      UserCredential userCredential = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailForFirebase,
        password: password,
      );

      // 2. Update nama tampilan (display name) pada Firebase Auth
      await userCredential.user?.updateDisplayName(name);

      // 3. Simpan data profil pengguna ke Cloud Firestore
      if (userCredential.user != null) {
        await FirebaseFirestore.instance.collection('users').doc(userCredential.user!.uid).set({
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
      if (e.code == 'email-already-in-use' || e.code == 'weak-password') {
        errorMessage = 'Username/Email sudah terdaftar atau password terlalu lemah.';
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
        SnackBar(content: Text('Terjadi kesalahan: $e'), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: const Text('Daftar Akun Baru', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 20, offset: const Offset(0, 8))],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Buat Akun Dukeduk', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                const SizedBox(height: 6),
                const Text('Lengkapi data Anda untuk mulai mencatat keuangan.', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 24),
                TextField(
                  controller: _nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Lengkap',
                    prefixIcon: const Icon(Icons.person_outline_rounded, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _usernameController,
                  decoration: InputDecoration(
                    labelText: 'Email atau Username',
                    helperText: 'Gunakan email aktif agar fitur Lupa Password bisa digunakan',
                    helperStyle: const TextStyle(fontSize: 10),
                    prefixIcon: const Icon(Icons.alternate_email_rounded, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Password (Minimal 6 Karakter)',
                    prefixIcon: const Icon(Icons.lock_outline_rounded, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
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
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _register,
                    child: const Text('Daftar Sekarang', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
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