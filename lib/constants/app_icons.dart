import 'package:flutter/material.dart';

class AppIcons {
  static final List<Map<String, dynamic>> availableIcons = [
    // --- Belanja & Kebutuhan ---
    {'name': 'shopping_bag', 'icon': Icons.shopping_bag, 'label': 'Belanja'},
    {
      'name': 'local_grocery_store',
      'icon': Icons.local_grocery_store,
      'label': 'Swalayan',
    },
    {
      'name': 'shopping_cart',
      'icon': Icons.shopping_cart,
      'label': 'Keranjang',
    },
    {'name': 'store', 'icon': Icons.store, 'label': 'Toko'},
    {'name': 'checkroom', 'icon': Icons.checkroom, 'label': 'Pakaian'},
    {'name': 'diamond', 'icon': Icons.diamond, 'label': 'Perhiasan'},

    // --- Makanan & Minuman ---
    {'name': 'fastfood', 'icon': Icons.fastfood, 'label': 'Makanan Cepat'},
    {'name': 'restaurant', 'icon': Icons.restaurant, 'label': 'Restoran'},
    {'name': 'local_cafe', 'icon': Icons.local_cafe, 'label': 'Kopi/Kafe'},
    {'name': 'local_bar', 'icon': Icons.local_bar, 'label': 'Minuman'},
    {'name': 'bakery_dining', 'icon': Icons.bakery_dining, 'label': 'Roti/Kue'},
    {'name': 'liquor', 'icon': Icons.liquor, 'label': 'Bar/Alkohol'},

    // --- Transportasi & Kendaraan ---
    {'name': 'directions_car', 'icon': Icons.directions_car, 'label': 'Mobil'},
    {'name': 'two_wheeler', 'icon': Icons.two_wheeler, 'label': 'Motor'},
    {'name': 'directions_bus', 'icon': Icons.directions_bus, 'label': 'Bus'},
    {'name': 'train', 'icon': Icons.train, 'label': 'Kereta'},
    {'name': 'local_taxi', 'icon': Icons.local_taxi, 'label': 'Taksi/Online'},
    {
      'name': 'local_gas_station',
      'icon': Icons.local_gas_station,
      'label': 'Bensin',
    },
    {'name': 'flight', 'icon': Icons.flight, 'label': 'Pesawat/Travel'},
    {
      'name': 'directions_boat',
      'icon': Icons.directions_boat,
      'label': 'Kapal',
    },
    {'name': 'local_parking', 'icon': Icons.local_parking, 'label': 'Parkir'},

    // --- Keuangan, Gaji & Investasi ---
    {
      'name': 'account_balance_wallet',
      'icon': Icons.account_balance_wallet,
      'label': 'Dompet',
    },
    {'name': 'local_atm', 'icon': Icons.local_atm, 'label': 'Tunai/ATM'},
    {'name': 'payments', 'icon': Icons.payments, 'label': 'Pembayaran'},
    {'name': 'attach_money', 'icon': Icons.attach_money, 'label': 'Uang Masuk'},
    {'name': 'credit_card', 'icon': Icons.credit_card, 'label': 'Kartu Kredit'},
    {'name': 'account_balance', 'icon': Icons.account_balance, 'label': 'Bank'},
    {'name': 'trending_up', 'icon': Icons.trending_up, 'label': 'Investasi'},
    {
      'name': 'request_quote',
      'icon': Icons.request_quote,
      'label': 'Tagihan/Invoice',
    },
    {
      'name': 'card_giftcard',
      'icon': Icons.card_giftcard,
      'label': 'Hadiah/Bonus',
    },
    {'name': 'savings', 'icon': Icons.savings, 'label': 'Tabungan'},

    // --- Rumah, Utilitas & Keluarga ---
    {'name': 'home', 'icon': Icons.home, 'label': 'Rumah'},
    {'name': 'apartment', 'icon': Icons.apartment, 'label': 'Apartemen/Kost'},
    {'name': 'bolt', 'icon': Icons.bolt, 'label': 'Listrik'},
    {'name': 'water_drop', 'icon': Icons.water_drop, 'label': 'Air/PDAM'},
    {'name': 'wifi', 'icon': Icons.wifi, 'label': 'Internet'},
    {
      'name': 'phone_android',
      'icon': Icons.phone_android,
      'label': 'Ponsel/Pulsa',
    },
    {'name': 'tv', 'icon': Icons.tv, 'label': 'Televisi/Cable'},
    {'name': 'build', 'icon': Icons.build, 'label': 'Perbaikan'},
    {
      'name': 'cleaning_services',
      'icon': Icons.cleaning_services,
      'label': 'Kebersihan',
    },

    // --- Pekerjaan, Pendidikan & Bisnis ---
    {'name': 'work', 'icon': Icons.work, 'label': 'Kerja/Gaji'},
    {'name': 'school', 'icon': Icons.school, 'label': 'Sekolah/Kuliah'},
    {'name': 'book', 'icon': Icons.book, 'label': 'Buku/Kursus'},
    {'name': 'badge', 'icon': Icons.badge, 'label': 'Identitas/ID'},
    {'name': 'computer', 'icon': Icons.computer, 'label': 'Komputer/IT'},
    {'name': 'print', 'icon': Icons.print, 'label': 'Cetak/ATK'},

    // --- Kesehatan & Olahraga ---
    {
      'name': 'medical_services',
      'icon': Icons.medical_services,
      'label': 'Kesehatan',
    },
    {
      'name': 'local_hospital',
      'icon': Icons.local_hospital,
      'label': 'Rumah Sakit',
    },
    {'name': 'medication', 'icon': Icons.medication, 'label': 'Obat/Apotek'},
    {
      'name': 'fitness_center',
      'icon': Icons.fitness_center,
      'label': 'Fitness/Gym',
    },
    {
      'name': 'sports_soccer',
      'icon': Icons.sports_soccer,
      'label': 'Sepak Bola',
    },
    {'name': 'pool', 'icon': Icons.pool, 'label': 'Renang'},

    // --- Hiburan, Hobi & Hewan ---
    {'name': 'movie', 'icon': Icons.movie, 'label': 'Bioskop/Film'},
    {'name': 'sports_esports', 'icon': Icons.sports_esports, 'label': 'Game'},
    {'name': 'headphones', 'icon': Icons.headphones, 'label': 'Musik'},
    {
      'name': 'photo_camera',
      'icon': Icons.photo_camera,
      'label': 'Kamera/Foto',
    },
    {'name': 'palette', 'icon': Icons.palette, 'label': 'Seni/Desain'},
    {'name': 'pets', 'icon': Icons.pets, 'label': 'Hewan Peliharaan'},
    {'name': 'card_travel', 'icon': Icons.card_travel, 'label': 'Liburan'},
    {'name': 'celebration', 'icon': Icons.celebration, 'label': 'Pesta/Acara'},

    // --- Lain-lain ---
    {'name': 'security', 'icon': Icons.security, 'label': 'Asuransi/Keamanan'},
    {
      'name': 'card_membership',
      'icon': Icons.card_membership,
      'label': 'Langganan/Member',
    },
    {
      'name': 'volunteer_activism',
      'icon': Icons.volunteer_activism,
      'label': 'Donasi/Amal',
    },
    {'name': 'category', 'icon': Icons.category, 'label': 'Lainnya'},
  ];

  static IconData getIconData(String? iconName) {
    final match = availableIcons.firstWhere(
      (element) => element['name'] == iconName,
      orElse: () => {'icon': Icons.category},
    );
    return match['icon'] as IconData;
  }

  static IconData fromCodePoint(int codePoint) {
    for (final entry in availableIcons) {
      final icon = entry['icon'] as IconData;
      if (icon.codePoint == codePoint) return icon;
    }
    return Icons.category;
  }

  static Map<String, Color> getIconThemeColor(String? iconName) {
    switch (iconName) {
      case 'shopping_bag':
      case 'checkroom':
      case 'diamond':
        return {'bg': Colors.pink.shade100, 'fg': Colors.pink.shade800};
      case 'fastfood':
      case 'restaurant':
      case 'bakery_dining':
      case 'local_grocery_store':
      case 'shopping_cart':
      case 'store':
        return {'bg': Colors.orange.shade100, 'fg': Colors.orange.shade800};
      case 'directions_car':
      case 'two_wheeler':
      case 'directions_bus':
      case 'train':
      case 'local_taxi':
      case 'local_gas_station':
      case 'local_parking':
        return {'bg': Colors.blue.shade100, 'fg': Colors.blue.shade800};
      case 'flight':
      case 'directions_boat':
      case 'card_travel':
        return {'bg': Colors.cyan.shade100, 'fg': Colors.cyan.shade800};
      case 'account_balance_wallet':
      case 'local_atm':
      case 'payments':
      case 'attach_money':
      case 'credit_card':
      case 'account_balance':
      case 'trending_up':
      case 'request_quote':
      case 'card_giftcard':
      case 'savings':
        return {'bg': Colors.green.shade100, 'fg': Colors.green.shade800};
      case 'local_cafe':
      case 'local_bar':
      case 'liquor':
        return {'bg': Colors.brown.shade100, 'fg': Colors.brown.shade800};
      case 'medical_services':
      case 'local_hospital':
      case 'medication':
        return {'bg': Colors.red.shade100, 'fg': Colors.red.shade800};
      case 'bolt':
      case 'water_drop':
      case 'wifi':
      case 'phone_android':
      case 'tv':
        return {'bg': Colors.amber.shade100, 'fg': Colors.amber.shade900};
      case 'work':
      case 'school':
      case 'book':
      case 'badge':
      case 'computer':
      case 'print':
        return {'bg': Colors.purple.shade100, 'fg': Colors.purple.shade800};
      case 'pets':
      case 'fitness_center':
      case 'sports_soccer':
      case 'pool':
        return {
          'bg': Colors.deepOrange.shade100,
          'fg': Colors.deepOrange.shade800,
        };
      case 'movie':
      case 'sports_esports':
      case 'headphones':
      case 'photo_camera':
      case 'palette':
      case 'celebration':
        return {'bg': Colors.indigo.shade100, 'fg': Colors.indigo.shade800};
      default:
        return {'bg': Colors.blueGrey.shade100, 'fg': Colors.blueGrey.shade800};
    }
  }
}
