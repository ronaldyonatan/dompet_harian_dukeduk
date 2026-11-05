import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// Fungsi untuk mengubah angka double/int menjadi string berformat mata uang (Cth: 150.000)
String formatCurrency(num amount) {
  final formatter = NumberFormat('#,###', 'id_ID');
  return formatter.format(amount);
}

// Formatter untuk TextField agar otomatis ada titik ribuan saat diketik
class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue.copyWith(text: '');
    }

    // Bersihkan karakter selain angka
    String cleanText = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (cleanText.isEmpty) {
      return newValue.copyWith(text: '');
    }

    final parsedValue = int.tryParse(cleanText);
    if (parsedValue == null) return oldValue;
    final formatter = NumberFormat('#,###', 'id_ID');
    String formatted = formatter.format(parsedValue);

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
