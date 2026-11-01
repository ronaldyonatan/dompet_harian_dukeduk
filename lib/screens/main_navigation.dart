import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../helpers/auth_helper.dart';
import '../helpers/loading_helper.dart'; 
import 'dashboard_screen.dart';
import 'transaction_screen.dart';
import 'master_data_hub_screen.dart';
import 'profile_screen.dart';
import 'mutation_report_hub_screen.dart';

class MainNavigation extends StatefulWidget {
  final String userName;
  final String initialLanguage;
  const MainNavigation({super.key, required this.userName, required this.initialLanguage});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  late String _currentLanguage;
  late String _userName;
  String? _profileImage;
  String? _appLogo;

  @override
  void initState() {
    super.initState();
    _currentLanguage = widget.initialLanguage;
    _userName = widget.userName;
    
    Future.microtask(() => _loadUserMetadata());
  }

  Future<void> _loadUserMetadata() async {
    final bool isEn = _currentLanguage == 'en';
    final bool isMalay = _currentLanguage == 'ms';
    
    LoadingHelper.show(
      context, 
      message: isEn ? 'Loading user data...' : (isMalay ? 'Memuatkan data pengguna...' : 'Memuat data pengguna...'),
    );

    try {
      var user = await AuthHelper.getActiveUser();
      if (user != null && mounted) {
        setState(() {
          _userName = user['name'] ?? widget.userName;
          _profileImage = user['profileImage'];
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
      _profileImage = profileImg;
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
      DashboardScreen(userName: _userName, languageCode: _currentLanguage, appLogo: _appLogo),
      
      // Index 1: Transaction
      TransactionScreen(languageCode: _currentLanguage),
      
      // Index 2: Master Data (Item & Kategori)
      MasterDataHubScreen(currentLanguage: _currentLanguage),
      
      // Index 3: Report & Mutation Hub
      MutationReportHubScreen(languageCode: _currentLanguage, appLogo: _appLogo),

      // Index 4: Profile
      ProfileScreen(
        userName: _userName,
        currentLanguage: _currentLanguage,
        onLanguageChanged: _updateLanguage,
        onProfileUpdated: _updateProfile,
      ),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        height: 64,
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 10, offset: const Offset(0, -4)),
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
              Icon(icon, size: 20, color: isSelected ? const Color(0xFF1A237E) : Colors.grey.shade400),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? const Color(0xFF1A237E) : Colors.grey.shade400,
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