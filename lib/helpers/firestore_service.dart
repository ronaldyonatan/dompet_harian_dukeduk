import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../helpers/database_helper.dart';
import '../models/finance_model.dart' as model;

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Di dalam FirestoreService
  Future<void> uploadBudgetsToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dbHelper = DatabaseHelper.instance;
    final localBudgets = await dbHelper.getBudgets();
    final firestore = FirebaseFirestore.instance;

    for (var budget in localBudgets) {
      // Cek duplikasi di Firestore berdasarkan user_id, category_id, bulan, dan tahun
      final existing = await firestore
          .collection('budgets')
          .where('user_id', isEqualTo: user.uid)
          .where('category_id', isEqualTo: budget.categoryId)
          .where('month', isEqualTo: budget.month)
          .where('year', isEqualTo: budget.year)
          .get();

      if (existing.docs.isEmpty) {
        await firestore.collection('budgets').add({
          'user_id': user.uid,
          'category_id': budget.categoryId,
          'month': budget.month,
          'year': budget.year,
          'amount': budget.amount,
        });
      } else {
        // Update data jika sudah ada di cloud
        for (var doc in existing.docs) {
          await firestore.collection('budgets').doc(doc.id).update({
            'amount': budget.amount,
          });
        }
      }
    }
  }

  // 1. Inisialisasi awal kategori default di Cloud
  Future<void> initializeUserDataOnFirstLaunch() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final categoryQuery = await _db
        .collection('categories')
        .where('user_id', isEqualTo: user.uid)
        .get();

    if (categoryQuery.docs.isEmpty) {
      List<Map<String, dynamic>> defaultCategories = [
        {'name': 'Gaji & Pendapatan', 'type': 'income', 'user_id': user.uid},
        {'name': 'Makanan & Minuman', 'type': 'expense', 'user_id': user.uid},
        {'name': 'Transportasi', 'type': 'expense', 'user_id': user.uid},
        {'name': 'Belanja Bulanan', 'type': 'expense', 'user_id': user.uid},
      ];

      for (var category in defaultCategories) {
        await _db.collection('categories').add(category);
      }
    }
  }

  // 2. Unggah (Upload) seluruh data lokal ke Cloud Firestore (Backup/Sync Up)
  Future<void> uploadLocalDataToCloud() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final dbHelper = DatabaseHelper.instance;
    final localCategories = await dbHelper.getCategories();
    final localItems = await dbHelper.getItems();
    final localTransactions = await dbHelper.getTransactions();

    // Sync Kategori
    for (var cat in localCategories) {
      final existing = await _db
          .collection('categories')
          .where('user_id', isEqualTo: user.uid)
          .where('name', isEqualTo: cat.name)
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('categories').add({
          'user_id': user.uid,
          'name': cat.name,
          'type': cat.type.name,
        });
      }
    }

    // Sync Master Item / Produk
    for (var item in localItems) {
      final existing = await _db
          .collection('items')
          .where('user_id', isEqualTo: user.uid)
          .where('name', isEqualTo: item.name)
          .get();

      if (existing.docs.isEmpty) {
        await _db.collection('items').add({
          'user_id': user.uid,
          'barcode': item.barcode,
          'name': item.name,
          'category_id': item.categoryId,
          'default_price': item.defaultPrice,
        });
      }
    }

    // Sync Transaksi
    for (var tx in localTransactions) {
      // Untuk transaksi, kita bisa langsung add atau cek berdasarkan keunikan data
      await _db.collection('transactions').add({
        'user_id': user.uid,
        'title': tx.title,
        'amount': tx.amount,
        'date': tx.date,
        'category_id': tx.categoryId,
        'item_id': tx.itemId,
        'note': tx.note,
      });
    }
  }
}