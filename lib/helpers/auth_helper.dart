import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'notification_helper.dart';
import 'local_sync.dart';

class AuthHelper {
  static final LocalAuthentication _auth = LocalAuthentication();
  static String get _uid =>
      FirebaseAuth.instance.currentUser?.uid ?? 'signed_out';

  static Future<void> setBiometricEnabled(bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('biometric_enabled_$_uid', enabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    final scoped = prefs.getBool('biometric_enabled_$_uid');
    if (scoped != null) return scoped;
    final legacy = prefs.getBool('biometric_enabled_key') ?? false;
    await prefs.setBool('biometric_enabled_$_uid', legacy);
    await prefs.remove('biometric_enabled_key');
    return legacy;
  }

  static Future<void> rememberSession(bool remember) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('remember_me_$_uid', remember);
  }

  static Future<bool> isRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    // Preserve existing Firebase sessions on upgrade; an explicit unchecked
    // Remember Me from this version takes precedence.
    return prefs.getBool('remember_me_$_uid') ?? true;
  }

  static Future<Map<String, dynamic>?> getActiveUser() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return null;
    final prefs = await SharedPreferences.getInstance();
    final cached =
        jsonDecode(prefs.getString('profile_cache_${user.uid}') ?? '{}') as Map;
    return {
      'name':
          cached['name'] ??
          user.displayName ??
          user.email?.split('@').first ??
          'User',
      'profileImage': cached['profile_image'] ?? '',
      'appLogo': cached['app_logo'] ?? '',
    };
  }

  static Future<bool> authenticateBiometric() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      return await _auth.authenticate(
        localizedReason: 'Verifikasi identitas untuk membuka Dompet Harian',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  static Future<void> logout() => LocalSync.serial(() async {
    // Cancel before signing out so the next account never sees old reminders.
    await NotificationHelper.cancelAll();
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('active_user_key_v2');
    // Retired local authentication stored plaintext passwords. It is no longer
    // used by Firebase login and must not remain on the device after upgrade.
    await prefs.remove('registered_users_key_v2');
  });
}
