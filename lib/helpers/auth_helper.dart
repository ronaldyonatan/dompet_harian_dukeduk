import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';

class AuthHelper {
  static const String _keyRegisteredUsers = 'registered_users_key_v2';
  static const String _keyActiveUser = 'active_user_key_v2';
  
  static final LocalAuthentication _auth = LocalAuthentication();

  // --- Biometric Activation Status ---
  static const String _keyBiometricEnabled = 'biometric_enabled_key';

  static Future<void> setBiometricEnabled(bool isEnabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyBiometricEnabled, isEnabled);
  }

  static Future<bool> isBiometricEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyBiometricEnabled) ?? false;
  }

  // --- Remember Me & Session Management ---
  static const String _keyRememberMe = 'remember_me_key';

  static Future<void> saveLoginSession(Map<String, dynamic> user, bool rememberMe) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, rememberMe);
    await prefs.setString(_keyActiveUser, jsonEncode(user));
  }

  static Future<bool> isRemembered() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? false;
  }  

  static Future<bool> registerUser({
    required String name,
    required String username,
    required String password,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersStr = prefs.getString(_keyRegisteredUsers);
    
    List<dynamic> usersList = usersStr != null ? jsonDecode(usersStr) : [];
    bool exists = usersList.any((u) => u['username'].toString().toLowerCase() == username.toLowerCase());
    if (exists) return false; 

    final newUser = {
      'name': name,
      'username': username.trim(),
      'password': password.trim(),
      'profileImage': '', // Path atau Base64 foto profil
      'appLogo': '',       // Path atau Base64 logo perusahaan/aplikasi
    };

    usersList.add(newUser);
    await prefs.setString(_keyRegisteredUsers, jsonEncode(usersList));
    return true;
  }

  static Future<Map<String, dynamic>?> loginWithPassword(String username, String password) async {
    final prefs = await SharedPreferences.getInstance();
    final String? usersStr = prefs.getString(_keyRegisteredUsers);
    if (usersStr == null) return null;

    List<dynamic> usersList = jsonDecode(usersStr);
    try {
      var foundUser = usersList.firstWhere(
        (u) => u['username'].toString().trim() == username.trim() && 
               u['password'].toString().trim() == password.trim(),
      );

      await prefs.setString(_keyActiveUser, jsonEncode(foundUser));
      return foundUser as Map<String, dynamic>;
    } catch (e) {
      return null;
    }
  }

  // Update profil user aktif (Foto / Logo / Nama)
  static Future<void> updateActiveUserProfile({
    required String name,
    String? profileImage,
    String? appLogo,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final String? activeStr = prefs.getString(_keyActiveUser);
    if (activeStr == null) return;

    Map<String, dynamic> activeUser = jsonDecode(activeStr);
    activeUser['name'] = name;
    if (profileImage != null) activeUser['profileImage'] = profileImage;
    if (appLogo != null) activeUser['appLogo'] = appLogo;

    // Simpan ulang ke active user
    await prefs.setString(_keyActiveUser, jsonEncode(activeUser));

    // Perbarui juga di daftar registered users
    final String? usersStr = prefs.getString(_keyRegisteredUsers);
    if (usersStr != null) {
      List<dynamic> usersList = jsonDecode(usersStr);
      for (int i = 0; i < usersList.length; i++) {
        if (usersList[i]['username'] == activeUser['username']) {
          usersList[i] = activeUser;
          break;
        }
      }
      await prefs.setString(_keyRegisteredUsers, jsonEncode(usersList));
    }
  }

  static Future<Map<String, dynamic>?> getActiveUser() async {
    final prefs = await SharedPreferences.getInstance();
    final String? activeStr = prefs.getString(_keyActiveUser);
    if (activeStr == null) return null;
    return jsonDecode(activeStr) as Map<String, dynamic>;
  }

  static Future<bool> authenticateBiometric() async {
    try {
      bool canCheck = await _auth.canCheckBiometrics;
      bool isSupported = await _auth.isDeviceSupported();
      
      if (!canCheck && !isSupported) {
        return false;
      }

      return await _auth.authenticate(
        localizedReason: 'Gunakan sidik jari atau pengenalan wajah untuk masuk',
        options: const AuthenticationOptions(
          biometricOnly: false,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (e) {
      print("Error Biometric: $e");
      return false;
    }
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Hapus sesi user yang sedang aktif
    await prefs.remove(_keyActiveUser);
    
    // Hapus data finansial lokal agar tidak tercampur ke user berikutnya di perangkat yang sama
    await prefs.remove('categories_data');
    await prefs.remove('items_data');
    await prefs.remove('transactions_data');
    await prefs.remove('budgets_data');
  }
}