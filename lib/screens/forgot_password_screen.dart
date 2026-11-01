import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import LoadingHelper global Anda
import '../helpers/loading_helper.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String languageCode;

  const ForgotPasswordScreen({super.key, required this.languageCode});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _resetPassword() async {
    final isEn = widget.languageCode == 'en';
    final email = _emailController.text.trim();

    if (email.isEmpty || !email.contains('@')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(isEn ? 'Please enter a valid email address!' : 'Masukkan alamat email yang valid!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    // Tampilkan LoadingHelper global saat proses pengiriman tautan reset
    LoadingHelper.show(
      context, 
      message: isEn ? 'Sending reset link...' : 'Mengirim tautan reset...',
    );

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      
      if (!mounted) return;
      // Tutup LoadingHelper sebelum memunculkan dialog berhasil
      LoadingHelper.hide(context);

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(isEn ? 'Success' : 'Berhasil'),
          content: Text(
            isEn 
              ? 'A password reset link has been sent to $email. Please check your inbox or spam folder.'
              : 'Tautan pemulihan kata sandi telah dikirim ke $email. Silakan periksa kotak masuk atau folder spam Anda.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context); // Tutup dialog
                Navigator.pop(context); // Kembali ke halaman Login
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      LoadingHelper.hide(context);
      
      String message = isEn ? 'Failed to send password reset email.' : 'Gagal mengirim email reset password.';
      if (e is FirebaseAuthException) {
        if (e.code == 'user-not-found') {
          message = isEn ? 'Email is not registered in the system.' : 'Email tidak terdaftar dalam sistem.';
        } else if (e.code == 'invalid-email') {
          message = isEn ? 'Invalid email format.' : 'Format email tidak valid.';
        }
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.languageCode == 'en';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEn ? 'Forgot Password' : 'Lupa Kata Sandi', 
          style: const TextStyle(fontSize: 16),
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
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A237E).withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.lock_reset_rounded, size: 40, color: Color(0xFF1A237E)),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  isEn ? 'Reset Password' : 'Reset Kata Sandi',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                ),
                const SizedBox(height: 8),
                Text(
                  isEn 
                    ? 'Enter your account email. We will send you a link to reset your password.'
                    : 'Masukkan email akun Anda. Kami akan mengirimkan tautan untuk mengatur ulang kata sandi Anda.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: isEn ? 'Email Address' : 'Alamat Email',
                    prefixIcon: const Icon(Icons.email_outlined, color: Color(0xFF1A237E)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1A237E),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    ),
                    onPressed: _resetPassword,
                    child: Text(
                      isEn ? 'Send Reset Link' : 'Kirim Tautan Reset', 
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
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