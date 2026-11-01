import 'package:flutter/material.dart';
import 'debt_screen.dart';
import 'receivable_screen.dart'; // Nanti file ini dibuat terpisah

class DebtReceivableMainScreen extends StatefulWidget {
  final String currentLanguage;

  const DebtReceivableMainScreen({super.key, required this.currentLanguage});

  @override
  State<DebtReceivableMainScreen> createState() => _DebtReceivableMainScreenState();
}

class _DebtReceivableMainScreenState extends State<DebtReceivableMainScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.currentLanguage == 'en';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEn ? 'Debt & Receivable' : 'Hutang & Piutang',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
          tabs: [
            Tab(text: isEn ? 'Debts (Hutang)' : 'Hutang'),
            Tab(text: isEn ? 'Receivables (Piutang)' : 'Piutang'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Tab 1: Menggunakan file DebtScreen yang sudah kita buat
          DebtScreen(currentLanguage: widget.currentLanguage),
          
          // Tab 2: Menggunakan file ReceivableScreen (Akan kita buat berikutnya)
          ReceivableScreen(currentLanguage: widget.currentLanguage),
        ],
      ),
    );
  }
}