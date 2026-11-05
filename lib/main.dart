import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'helpers/notification_helper.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await NotificationHelper.init();
  } catch (e) {
    debugPrint('Notifikasi belum dapat diinisialisasi: $e');
  }
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeDateFormatting('id_ID', null);

  // Baca cache bahasa
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('registered_users_key_v2');
  final String initialLanguage = prefs.getString('saved_language') ?? 'id';

  runApp(DompetHarianDukedukApp(initialLanguage: initialLanguage));
}

class DompetHarianDukedukApp extends StatefulWidget {
  final String initialLanguage;
  const DompetHarianDukedukApp({super.key, required this.initialLanguage});

  @override
  State<DompetHarianDukedukApp> createState() => _DompetHarianDukedukAppState();
}

class _DompetHarianDukedukAppState extends State<DompetHarianDukedukApp> {
  late String _currentLanguage;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.initialLanguage;
  }

  // Fungsi untuk mengubah bahasa dan menyimpannya secara permanen
  Future<void> handleLanguageChanged(String newLang) async {
    setState(() {
      _currentLanguage = newLang;
    });

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_language', newLang);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dompet Harian Dukeduk',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1A237E)),
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: LoginScreen(
        currentLanguage: _currentLanguage,
        onLanguageChanged: handleLanguageChanged,
      ),
      debugShowCheckedModeBanner: false,
    );
  }
}
