import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/auth_helper.dart';
import '../helpers/database_helper.dart';
import '../helpers/local_sync.dart';
import '../helpers/notification_helper.dart';
import '../helpers/profile_image.dart';
import '../helpers/localization_helper.dart';
import '../helpers/Loading_Helper.dart'; // Import LoadingHelper global
import 'login_screen.dart';
import 'donate_screen.dart';

class ProfileScreen extends StatefulWidget {
  final String userName;
  final String currentLanguage;
  final Function(String) onLanguageChanged;
  final Function(String, String, String) onProfileUpdated;

  const ProfileScreen({
    super.key,
    required this.userName,
    required this.currentLanguage,
    required this.onLanguageChanged,
    required this.onProfileUpdated,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  String? _profileImagePath;
  String? _appLogoPath;
  String? _userEmail;
  bool _isBiometricActive = false;
  bool _isCloudSyncActive = false;
  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.userName);
    _loadUserDataFromFirebase();
    _loadBiometricStatus();
    _checkCloudSyncStatus();
  }

  Future<void> _loadUserDataFromFirebase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    final prefs = await SharedPreferences.getInstance();
    Map<String, dynamic> data = Map<String, dynamic>.from(
      jsonDecode(prefs.getString('profile_cache_${user.uid}') ?? '{}') as Map,
    );
    void apply() {
      if (!mounted) return;
      setState(() {
        _profileImagePath = data['profile_image'] as String?;
        _appLogoPath = data['app_logo'] as String?;
        _nameController.text =
            data['name'] as String? ?? user.displayName ?? widget.userName;
        _userEmail = user.email;
      });
      widget.onProfileUpdated(
        _nameController.text,
        _profileImagePath ?? '',
        _appLogoPath ?? '',
      );
    }

    apply();
    if (!await LocalSync.isEnabled()) return;
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get()
          .timeout(const Duration(seconds: 12));
      if (doc.data() != null &&
          !(prefs.getBool('profile_dirty_${user.uid}') ?? false)) {
        final remote = doc.data()!;
        data = {
          for (final key in ['name', 'profile_image', 'app_logo'])
            if (remote[key] != null) key: remote[key],
        };
        await prefs.setString('profile_cache_${user.uid}', jsonEncode(data));
        apply();
      }
    } catch (e) {
      debugPrint('Profile remains available offline: $e');
    }
  }

  Future<void> _persistProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    final prefs = await SharedPreferences.getInstance();
    final data = {
      'name': _nameController.text.trim(),
      'profile_image': _profileImagePath ?? '',
      'app_logo': _appLogoPath ?? '',
    };
    await prefs.setString('profile_cache_$uid', jsonEncode(data));
    await prefs.setBool('profile_dirty_$uid', true);
    if (await LocalSync.isEnabled()) {
      try {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set({
              ...data,
              'updated_at': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true))
            .timeout(const Duration(seconds: 12));
        await prefs.setBool('profile_dirty_$uid', false);
      } catch (e) {
        debugPrint('Profile upload pending: $e');
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadBiometricStatus() async {
    bool status = await AuthHelper.isBiometricEnabled();
    if (mounted) {
      setState(() => _isBiometricActive = status);
    }
  }

  Future<void> _checkCloudSyncStatus() async {
    final currentUser = FirebaseAuth.instance.currentUser;
    final enabled = await LocalSync.isEnabled();
    if (mounted) {
      setState(() {
        _isCloudSyncActive = enabled;
        _userEmail = currentUser?.email ?? 'Belum Login';
      });
    }
  }

  Future<void> _changeLanguage(String langCode) async {
    final t = AppLocalizations(widget.currentLanguage);
    LoadingHelper.show(
      context,
      message: t.translate('loading', fallback: 'Memproses...'),
    );

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_language', langCode);
    widget.onLanguageChanged(langCode);

    await Future.delayed(const Duration(milliseconds: 200));
    if (mounted) {
      LoadingHelper.hide(context);
      setState(() {});
    }
  }

  Future<void> _pickImage(bool isProfile) async {
    final image = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 75,
    );
    if (image == null || !mounted) return;
    LoadingHelper.show(context, message: 'Menyimpan gambar...');
    try {
      final bytes = await image.readAsBytes();
      // Firestore documents are limited to 1 MiB; keep both images well below it.
      if (bytes.length > 250000) {
        throw Exception('Gambar terlalu besar. Pilih gambar yang lebih kecil.');
      }
      final data = 'data:image/jpeg;base64,${base64Encode(bytes)}';
      if (!mounted) return;
      setState(() {
        if (isProfile) {
          _profileImagePath = data;
        } else {
          _appLogoPath = data;
        }
      });
      await _persistProfile();
      if (mounted) {
        widget.onProfileUpdated(
          _nameController.text.trim(),
          _profileImagePath ?? '',
          _appLogoPath ?? '',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) LoadingHelper.hide(context);
    }
  }

  void _saveName() async {
    final t = AppLocalizations(widget.currentLanguage);
    String newName = _nameController.text.trim();
    if (newName.isEmpty) return;

    LoadingHelper.show(
      context,
      message: t.translate('saving', fallback: 'Menyimpan nama...'),
    );

    try {
      await _persistProfile();
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && await LocalSync.isEnabled()) {
        try {
          await currentUser
              .updateDisplayName(newName)
              .timeout(const Duration(seconds: 12));
        } catch (e) {
          debugPrint('Nama profil sudah tersimpan lokal: $e');
        }
      }
      if (!mounted) return;
      widget.onProfileUpdated(
        newName,
        _profileImagePath ?? '',
        _appLogoPath ?? '',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(t.translate('profile_updated_success')),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memperbarui nama: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) {
        LoadingHelper.hide(context);
      }
    }
  }

  Future<void> _toggleBiometric(bool value) async {
    final t = AppLocalizations(widget.currentLanguage);

    if (value) {
      LoadingHelper.show(
        context,
        message: t.translate(
          'verifying_biometric',
          fallback: 'Memverifikasi Biometrik...',
        ),
      );
      bool authenticated = await AuthHelper.authenticateBiometric();
      if (mounted) LoadingHelper.hide(context);

      if (authenticated) {
        await AuthHelper.setBiometricEnabled(true);
        if (mounted) setState(() => _isBiometricActive = true);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate('biometric_enabled')),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate('biometric_failed')),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } else {
      LoadingHelper.show(
        context,
        message: t.translate('saving', fallback: 'Memproses...'),
      );
      await AuthHelper.setBiometricEnabled(false);
      if (mounted) {
        LoadingHelper.hide(context);
        setState(() => _isBiometricActive = false);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('biometric_disabled'))),
      );
    }
  }

  Future<void> _toggleCloudSync(bool value) async {
    final t = AppLocalizations(widget.currentLanguage);
    final currentUser = FirebaseAuth.instance.currentUser;

    if (value) {
      if (currentUser == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate('login_first_cloud')),
            backgroundColor: Colors.orange,
          ),
        );
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => LoginScreen(
              currentLanguage: widget.currentLanguage,
              onLanguageChanged: (newLang) {},
            ),
          ),
        );
        return;
      }

      LoadingHelper.show(
        context,
        message: t.translate(
          'cloud_syncing',
          fallback: 'Sinkronisasi data ke Cloud...',
        ),
      );

      try {
        await LocalSync.setEnabled(true);
        await DatabaseHelper.instance.pullDataFromCloud();
        await _persistProfile();

        if (mounted) {
          setState(() {
            _isCloudSyncActive = true;
            _userEmail = currentUser.email;
          });
        }

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(t.translate('cloud_active_success')),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        await _checkCloudSyncStatus();
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${t.translate('cloud_sync_failed')}: $e'),
            backgroundColor: Colors.red,
          ),
        );
      } finally {
        if (mounted) {
          LoadingHelper.hide(context);
        }
      }
    } else {
      await LocalSync.setEnabled(false);
      if (!mounted) return;
      setState(() => _isCloudSyncActive = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.translate('offline_mode_switched'))),
      );
    }
  }

  void _showAppInfoDialog(BuildContext context, AppLocalizations t) {
    final bool isEn = widget.currentLanguage == 'en';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircleAvatar(
              radius: 36,
              backgroundColor: Color(0xFF1A237E),
              child: Icon(
                Icons.account_balance_wallet,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              t.translate('app_title', fallback: 'Dompet Harian Dukeduk'),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            const Text(
              'Version 1.0.1',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
            const SizedBox(height: 12),
            Text(
              isEn
                  ? 'A simple and secure daily finance & business ledger application with cloud synchronization support.'
                  : 'Aplikasi pencatatan keuangan harian & bisnis yang simpel dan aman dengan dukungan sinkronisasi cloud.',
              style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.code, size: 16, color: Colors.grey),
                const SizedBox(width: 6),
                Text(
                  isEn
                      ? 'Developed by Ronald Yonatan'
                      : 'Dibuat oleh Ronald Yonatan',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              '© 2026 Ronald Yonatan. All rights reserved.',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF1A237E),
                foregroundColor: Colors.white,
                minimumSize: const Size(120, 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: Text(t.translate('close', fallback: 'Tutup')),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, AppLocalizations t) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            t.translate('confirm_logout'),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          content: Text(
            'Apakah Anda yakin ingin keluar dari sesi Firebase?',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                t.translate('close'),
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: () async {
                Navigator.pop(context);
                LoadingHelper.show(
                  context,
                  message: t.translate(
                    'logging_out',
                    fallback: 'Keluar sesi...',
                  ),
                );

                // Logout langsung dari Firebase Authentication
                await AuthHelper.logout();

                if (!mounted) return;
                LoadingHelper.hide(context);

                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => LoginScreen(
                      currentLanguage: widget.currentLanguage,
                      onLanguageChanged: (newLang) {},
                    ),
                  ),
                );
              },
              child: Text(t.translate('stay_logout')),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = AppLocalizations(widget.currentLanguage);
    final bool isEn = widget.currentLanguage == 'en';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: Text(
          t.translate('profile_settings'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: ListTile(
                leading: const Icon(Icons.notifications_active),
                title: const Text('Uji notifikasi pengingat'),
                subtitle: const Text(
                  'Izinkan notifikasi dan kirim contoh notifikasi ke ponsel ini.',
                ),
                onTap: () async {
                  try {
                    await NotificationHelper.requestPermission();
                    await DatabaseHelper.instance.refreshReminders();
                    await NotificationHelper.showTestNotification();
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context)
                          .showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Column(
                        children: [
                          const Text(
                            'Foto Profil',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.indigo.shade50,
                                backgroundImage: profileImage(
                                  _profileImagePath,
                                ),
                                child:
                                    _profileImagePath == null ||
                                        _profileImagePath!.isEmpty
                                    ? const Icon(
                                        Icons.person_rounded,
                                        size: 35,
                                        color: Color(0xFF1A237E),
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => _pickImage(true),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF1A237E),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(width: 30),
                      Column(
                        children: [
                          const Text(
                            'Logo PT / Instansi',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Stack(
                            children: [
                              CircleAvatar(
                                radius: 35,
                                backgroundColor: Colors.blue.shade50,
                                backgroundImage: profileImage(_appLogoPath),
                                child:
                                    _appLogoPath == null ||
                                        _appLogoPath!.isEmpty
                                    ? const Icon(
                                        Icons.business_rounded,
                                        size: 35,
                                        color: Colors.blueAccent,
                                      )
                                    : null,
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: InkWell(
                                  onTap: () => _pickImage(false),
                                  child: Container(
                                    padding: const EdgeInsets.all(5),
                                    decoration: const BoxDecoration(
                                      color: Colors.blueAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.camera_alt_rounded,
                                      size: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.email_outlined,
                          size: 14,
                          color: Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          _userEmail ?? 'Memuat email...',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.grey,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _nameController,
                    decoration: InputDecoration(
                      labelText: t.translate('full_name'),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onSubmitted: (_) => _saveName(),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: _saveName,
                      child: Text(
                        t.translate('save_name'),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.cloud_sync_rounded,
                    color: Colors.blue,
                    size: 22,
                  ),
                ),
                title: Text(
                  t.translate('cloud_mode'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  t.translate('cloud_desc'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _isCloudSyncActive,
                onChanged: _toggleCloudSync,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: SwitchListTile(
                secondary: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.indigo.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.fingerprint_rounded,
                    color: Color(0xFF1A237E),
                    size: 22,
                  ),
                ),
                title: Text(
                  t.translate('biometric_title'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  t.translate('biometric_desc'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                value: _isBiometricActive,
                onChanged: _toggleBiometric,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    t.translate('language'),
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text(
                            'Bahasa Indonesia',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: 'id',
                          groupValue: widget.currentLanguage,
                          onChanged: (val) {
                            if (val != null) _changeLanguage(val);
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text(
                            'English',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: 'en',
                          groupValue: widget.currentLanguage,
                          onChanged: (val) {
                            if (val != null) _changeLanguage(val);
                          },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.favorite_rounded,
                    color: Colors.redAccent,
                    size: 20,
                  ),
                ),
                title: Text(
                  t.translate('donate_menu'),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  t.translate('donate_desc'),
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) =>
                          DonateScreen(languageCode: widget.currentLanguage),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.shade50,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: Colors.blue,
                    size: 20,
                  ),
                ),
                title: Text(
                  isEn ? 'App Information' : 'Informasi Aplikasi',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                  ),
                ),
                subtitle: Text(
                  isEn
                      ? 'Version, developer, & details'
                      : 'Versi, pengembang, & detail',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: Colors.grey,
                ),
                onTap: () => _showAppInfoDialog(context, t),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade50,
                foregroundColor: Colors.red.shade700,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => _confirmLogout(context, t),
              icon: const Icon(Icons.logout_rounded),
              label: Text(
                t.translate('logout'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
