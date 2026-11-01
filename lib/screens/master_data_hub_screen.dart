import 'package:flutter/material.dart';
import '../helpers/localization_helper.dart'; // <-- Gunakan helper lokalisasi yang sudah ada
import 'item_screen.dart';
import 'category_screen.dart';
import 'customer_screen.dart';
import 'lender_screen.dart';

class MasterDataHubScreen extends StatelessWidget {
  final String currentLanguage;

  const MasterDataHubScreen({
    super.key,
    required this.currentLanguage,
  });

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations(currentLanguage);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Text(
          localization.translate('master_data') ?? 'Master Data',
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
              localization.translate('select_master_data_module') ?? 'Pilih Modul Master Data',
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Color(0xFF0F172A),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              localization.translate('master_data_subtitle') ?? 'Kelola item dan kategori Anda di bawah',
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
                  // 1. Menu Master Item
                  _buildMenuCard(
                    context,
                    title: localization.translate('master_item') ?? 'Master Item',
                    subtitle: localization.translate('master_item_subtitle') ?? 'Kelola barang & barcode',
                    icon: Icons.inventory_2_rounded,
                    color: Colors.blue.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ItemScreen(currentLanguage: currentLanguage),
                        ),
                      );
                    },
                  ),

                  // 2. Menu Master Category
                  _buildMenuCard(
                    context,
                    title: localization.translate('master_category') ?? 'Master Kategori',
                    subtitle: localization.translate('master_category_subtitle') ?? 'Kelola tipe transaksi',
                    icon: Icons.category_rounded,
                    color: Colors.purple.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(currentLanguage: currentLanguage),
                        ),
                      );
                    },
                  ),

                  // 3. Menu Master customer
                  _buildMenuCard(
                    context,
                    title: localization.translate('master_customer'),
                    subtitle: localization.translate('master_customer_subtitle'),
                    icon: Icons.people_alt_rounded,
                    color: Colors.indigo.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CustomerScreen(currentLanguage: currentLanguage),
                        ),
                      );
                    },
                  ),       
                  // 4. Menu Master Lender
                  _buildMenuCard(
                    context,
                    title: localization.translate('master_lender'),
                    subtitle: localization.translate('master_lender_subtitle'),
                    icon: Icons.account_balance_rounded,
                    color: Colors.orange.shade700,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => LenderScreen(currentLanguage: currentLanguage),
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