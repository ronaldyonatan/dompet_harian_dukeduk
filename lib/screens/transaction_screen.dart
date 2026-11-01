import 'package:flutter/material.dart';
import '../helpers/localization_helper.dart'; 
import 'budget_screen.dart';
import 'new_transaction_screen.dart'; // <-- Impor screen baru
import 'debt_screen.dart';
import 'receivable_screen.dart';

class TransactionScreen extends StatelessWidget {
  final String languageCode;

  const TransactionScreen({
    super.key,
    required this.languageCode,
  });

  // Fungsi untuk membuka form New Transaction
  void _openNewTransaction(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => NewTransactionScreen(languageCode: languageCode),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations(languageCode);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Text(
          localization.translate('transaction_menu'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              localization.translate('select_input_type'),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              localization.translate('choose_input_menu_below'),
              style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: [
                  // 1. Inputan New Transaction
                  _buildMenuCard(
                    context,
                    title: localization.translate('new_transaction'),
                    subtitle: localization.translate('new_transaction_subtitle'),
                    icon: Icons.add_card_rounded,
                    color: Colors.blue.shade700,
                    onTap: () => _openNewTransaction(context),
                  ),

                  // 2. Inputan Budget
                  _buildMenuCard(
                    context,
                    title: localization.translate('budget'),
                    subtitle: localization.translate('budget_subtitle'),
                    icon: Icons.pie_chart_rounded,
                    color: Colors.purple.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => BudgetScreen(currentLanguage: languageCode),
                        ),
                      );
                    },
                  ),

                  // 3. Inputan Hutang (Debt)
                  _buildMenuCard(
                    context,
                    title: localization.translate('debts'),
                    subtitle: localization.translate('debt_subtitle'),
                    icon: Icons.money_off_rounded,
                    color: Colors.red.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DebtScreen(currentLanguage: languageCode),
                        ),
                      );
                    },
                  ),

                  // 4. Inputan Piutang (Receivable)
                  _buildMenuCard(
                    context,
                    title: localization.translate('receivables'),
                    subtitle: localization.translate('receivable_subtitle'),
                    icon: Icons.request_quote_rounded,
                    color: Colors.green.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ReceivableScreen(currentLanguage: languageCode),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
    BuildContext context, {
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      elevation: 2,
      shadowColor: Colors.black.withOpacity(0.05),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const Spacer(),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade500,
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