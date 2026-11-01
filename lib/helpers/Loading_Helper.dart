import 'package:flutter/material.dart';

class LoadingHelper {
  static bool _isLoading = false;

  /// Menampilkan Loading Dialog secara global
  static void show(BuildContext context, {String message = 'Memproses...'}) {
    if (_isLoading) return; // Cegah double dialog
    _isLoading = true;

    showDialog(
      context: context,
      barrierDismissible: false, // User tidak bisa menutup dengan klik di luar
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false, // Cegah tombol back fisik menutup loading
          child: Dialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      message,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  /// Menutup Loading Dialog secara global
  static void hide(BuildContext context) {
    if (_isLoading) {
      _isLoading = false;
      if (Navigator.canPop(context)) {
        Navigator.pop(context);
      }
    }
  }
}