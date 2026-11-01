
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart'; // Untuk membuka link PayPal di browser

class DonateScreen extends StatelessWidget {
  final String languageCode;
  const DonateScreen({super.key, required this.languageCode});

  // Fungsi untuk membuka link eksternal (PayPal)
  Future<void> _launchPayPal() async {
    final Uri url = Uri.parse('https://paypal.me/dukeduk'); // Ganti dengan link PayPal.Me Anda
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      throw Exception('Tidak dapat membuka $url');
    }
  }

  // Fungsi salin teks ke clipboard
  void _copyToClipboard(BuildContext context, String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$label berhasil disalin ke clipboard!'), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text('Dukung & Donasi', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Kartu Ucapan Terima Kasih
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1A237E), Color(0xFF3F51B5)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: const Color(0xFF3F51B5).withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 6))],
              ),
              child: const Column(
                children: [
                  Icon(Icons.favorite_rounded, color: Colors.redAccent, size: 40),
                  SizedBox(height: 12),
                  Text(
                    'Dukung Pengembangan Aplikasi',
                    style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'Jika aplikasi Dompet Harian Dukeduk bermanfaat bagi Anda, dukung kami agar terus berkembang dan menghadirkan pembaruan terbaik!',
                    style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bagian Global (PayPal)
            const Text('Global (Internasional)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: Colors.blue.shade50, shape: BoxShape.circle),
                    child: const Icon(Icons.public_rounded, color: Colors.blueAccent),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('PayPal / Kartu Kredit', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        SizedBox(height: 2),
                        Text('Donasi aman dari seluruh dunia (USD/EUR)', style: TextStyle(fontSize: 11, color: Colors.grey)),
                      ],
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF00796B), foregroundColor: Colors.white),
                    onPressed: _launchPayPal,
                    child: const Text('Donasi', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Bagian Indonesia (Bank & E-Wallet / QRIS)
            const Text('Indonesia (Lokal)', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
            const SizedBox(height: 10),

            // Transfer Bank BCA / Mandiri
            _buildBankCard(
              context,
              bankName: 'Bank BCA',
              accountNumber: '3720002875',
              accountHolder: 'Ronald Yonatan',
              icon: Icons.account_balance_rounded,
            ),
            const SizedBox(height: 12),

            // E-Wallet (GoPay / OVO / DANA)
            _buildBankCard(
              context,
              bankName: 'E-Wallet (GoPay / OVO / DANA / Shopee)',
              accountNumber: '081328273955',
              accountHolder: 'Ronald Yonatan',
              icon: Icons.account_balance_wallet_rounded,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBankCard(BuildContext context, {required String bankName, required String accountNumber, required String accountHolder, required IconData icon}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.indigo.shade50, shape: BoxShape.circle),
            child: Icon(icon, color: const Color(0xFF1A237E)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(bankName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                const SizedBox(height: 2),
                Text(accountNumber, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF1A237E))),
                const SizedBox(height: 2),
                Text('a.n. $accountHolder', style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.copy_rounded, size: 20, color: Color(0xFF1A237E)),
            tooltip: 'Salin Nomor Rekening',
            onPressed: () => _copyToClipboard(context, accountNumber, bankName),
          ),
        ],
      ),
    );
  }
}