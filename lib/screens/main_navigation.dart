import 'dart:async';

import '../helpers/database_helper.dart';

import 'package:flutter/material.dart';

import '../helpers/auth_helper.dart';
import '../helpers/Loading_Helper.dart';
import 'dashboard_screen.dart';
import 'transaction_screen.dart';
import 'master_data_hub_screen.dart';
import 'profile_screen.dart';
import 'mutation_report_hub_screen.dart';

class MainNavigation extends StatefulWidget {
  final String userName;
  final String initialLanguage;
  const MainNavigation({
    super.key,
    required this.userName,
    required this.initialLanguage,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation>
    with WidgetsBindingObserver {
  int _currentIndex = 0;
  late String _currentLanguage;
  late String _userName;
  bool _ready = false;
  int _revision = 0;
  String? _appLogo;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.initialLanguage;
    _userName = widget.userName;

    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadUserMetadata();
      unawaited(_refreshData());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshData() async {
    try {
      await DatabaseHelper.instance.pullDataFromCloud();
    } catch (_) {
      // Local data and pending changes remain available without a connection.
    }
    await DatabaseHelper.instance.initDefaultData();
    await DatabaseHelper.instance.refreshReminders();
    if (mounted)
      setState(() {
        _ready = true;
        if (_currentIndex == 0) _revision++;
      });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_refreshData());
  }

  Future<void> _loadUserMetadata() async {
    final bool isEn = _currentLanguage == 'en';
    final bool isMalay = _currentLanguage == 'ms';

    LoadingHelper.show(
      context,
      message: isEn
          ? 'Loading user data...'
          : (isMalay
                ? 'Memuatkan data pengguna...'
                : 'Memuat data pengguna...'),
    );

    try {
      var user = await AuthHelper.getActiveUser();
      if (user != null && mounted) {
        setState(() {
          _userName = user['name'] ?? widget.userName;
          _appLogo = user['appLogo'];
        });
      }
    } finally {
      if (mounted) {
        LoadingHelper.hide(context);
      }
    }
  }

  void _updateLanguage(String newLang) {
    setState(() {
      _currentLanguage = newLang;
    });
  }

  void _updateProfile(String name, String profileImg, String logoImg) {
    setState(() {
      _userName = name;
      _appLogo = logoImg;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bool isEn = _currentLanguage == 'en';
    final bool isMalay = _currentLanguage == 'ms';

    // 5 Menu Utama Sesuai Urutan Bottom Navigation Bar
    final List<Widget> screens = [
      // Index 0: Dashboard
      DashboardScreen(
        userName: _userName,
        languageCode: _currentLanguage,
        appLogo: _appLogo,
      ),

      // Index 1: Transaction
      TransactionScreen(languageCode: _currentLanguage),

      // Index 2: Master Data (Item & Kategori)
      MasterDataHubScreen(currentLanguage: _currentLanguage),

      // Index 3: Report & Mutation Hub
      MutationReportHubScreen(
        languageCode: _currentLanguage,
        appLogo: _appLogo,
      ),

      // Index 4: Profile
      ProfileScreen(
        userName: _userName,
        currentLanguage: _currentLanguage,
        onLanguageChanged: _updateLanguage,
        onProfileUpdated: _updateProfile,
      ),
    ];

    return Scaffold(
      body: !_ready
          ? const Center(child: CircularProgressIndicator())
          : KeyedSubtree(
              key: ValueKey(
                '$_currentIndex:${_currentIndex == 0 ? _revision : 0}',
              ),
              child: screens[_currentIndex],
            ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.06),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.dashboard_rounded,
                isEn ? 'Dashboard' : (isMalay ? 'Papan Utama' : 'Dashboard'),
              ),
              _buildNavItem(
                1,
                Icons.receipt_long_rounded,
                isEn ? 'Transaction' : (isMalay ? 'Transaksi' : 'Transaksi'),
              ),
              _buildNavItem(
                2,
                Icons.grid_view_rounded,
                isEn ? 'Master Data' : (isMalay ? 'Data Induk' : 'Master Data'),
              ),
              _buildNavItem(
                3,
                Icons.bar_chart_rounded,
                isEn ? 'Report' : (isMalay ? 'Laporan' : 'Report'),
              ),
              _buildNavItem(
                4,
                Icons.person_rounded,
                isEn ? 'Profile' : (isMalay ? 'Profil' : 'Profil'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentIndex == index;
    return Expanded(
      child: InkWell(
        onTap: () => setState(() => _currentIndex = index),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 20,
                color: isSelected
                    ? const Color(0xFF1A237E)
                    : Colors.grey.shade400,
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? const Color(0xFF1A237E)
                      : Colors.grey.shade400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
