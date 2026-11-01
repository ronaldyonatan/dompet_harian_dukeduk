import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/finance_model.dart' as model;
import '../models/debt_model.dart' as model;
import '../models/receivable_model.dart' as model;
import '../helpers/notification_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  // Helper untuk mendapatkan key unik berdasarkan User yang aktif (Firebase UID atau 'local_guest')
  Future<String> _getStorageKey(String baseKey) async {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser != null) {
      return '${baseKey}_${currentUser.uid}';
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      final activeUserStr = prefs.getString('active_user_key_v2');
      if (activeUserStr != null) {
        Map<String, dynamic> userMap = jsonDecode(activeUserStr);
        String username = userMap['username'] ?? 'default';
        return '${baseKey}_$username';
      }
    } catch (e) {
      // Abaikan jika gagal parse
    }

    return '${baseKey}_default_user';
  }

  // --- BUDGET ---
  Future<List<model.BudgetModel>> getBudgets() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('budgets_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => model.BudgetModel.fromMap(json)).toList();
  }

  // --- DELETE MASTER CUSTOMER ---
  Future<void> deleteCustomer(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('customers_data');
    List<Map<String, dynamic>> customers = await getCustomers();
    
    customers.removeWhere((c) => c['id'] == id);
    await prefs.setString(key, jsonEncode(customers));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_customer_$id';
        await firestore.collection('customers').doc(docId).delete();
      }
    } catch (e) {
      print('Gagal menghapus customer dari Firestore: $e');
    }
  }

  // --- DELETE MASTER LENDER ---
  Future<void> deleteLender(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('lenders_data');
    List<Map<String, dynamic>> lenders = await getLenders();
    
    lenders.removeWhere((l) => l['id'] == id);
    await prefs.setString(key, jsonEncode(lenders));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_lender_$id';
        await firestore.collection('lenders').doc(docId).delete();
      }
    } catch (e) {
      print('Gagal menghapus lender dari Firestore: $e');
    }
  }

  // --- DELETE RECEIVABLE (PIUTANG) & INSTALLMENTS ---
  Future<void> deleteReceivable(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    List<model.ReceivableModel> receivables = await getReceivables();
    
    receivables.removeWhere((r) => r.id == id);
    await prefs.setString(key, jsonEncode(receivables.map((r) => r.toMap()).toList()));

    // Hapus juga data cicilan terkait
    await _deleteInstallmentsForParent(id, 'receivable');

    await NotificationHelper.cancelReminder(id);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_receivable_$id';
        await firestore.collection('receivables').doc(docId).delete();
      }
    } catch (e) {
      print('Gagal menghapus piutang dari Firestore: $e');
    }
  }

  // --- DELETE DEBT (HUTANG) & INSTALLMENTS ---
  Future<void> deleteDebt(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    List<model.DebtModel> debts = await getDebts();
    
    debts.removeWhere((d) => d.id == id);
    await prefs.setString(key, jsonEncode(debts.map((d) => d.toMap()).toList()));

    // Hapus juga data cicilan terkait
    await _deleteInstallmentsForParent(id, 'debt');

    await NotificationHelper.cancelReminder(id + 100000);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_debt_$id';
        await firestore.collection('debts').doc(docId).delete();
      }
    } catch (e) {
      print('Gagal menghapus hutang dari Firestore: $e');
    }
  }

  // --- UPDATE DEBT (HUTANG) ---
  Future<void> updateDebt(model.DebtModel debt) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    final debts = await getDebts();
    
    int index = debts.indexWhere((d) => d.id == debt.id);
    if (index >= 0) {
      debts[index] = debt;
    } else {
      debts.add(debt);
    }

    await prefs.setString(key, jsonEncode(debts.map((d) => d.toMap()).toList()));

    // Regenerasi jadwal cicilan jika tenor/tanggal berubah
    if (debt.id != null) {
      await _generateInstallments(debt.id!, debt.firstDueDate, debt.installmentMonths, debt.monthlyInstallment, 'debt');
    }

    if (debt.isReminderActive && debt.firstDueDate.isNotEmpty && debt.id != null) {
      try {
        DateTime parsedDueDate = DateTime.parse(debt.firstDueDate);
        await NotificationHelper.schedulePaymentReminder(
          id: debt.id! + 100000,
          title: 'Pengingat Hutang: ${debt.lenderName}',
          body: 'Cicilan hutang jatuh tempo pada ${debt.firstDueDate}. Mohon segera dibayarkan.',
          dueDate: parsedDueDate,
        );
      } catch (e) {
        print('Gagal menjadwalkan ulang notifikasi hutang: $e');
      }
    } else if (debt.id != null) {
      await NotificationHelper.cancelReminder(debt.id! + 100000);
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && debt.id != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_debt_${debt.id}';

        await firestore.collection('debts').doc(docId).set({
          'user_id': userId,
          'debt_id': debt.id,
          'item_id': debt.itemId,
          'lender_id': debt.lenderId,
          'lender_name': debt.lenderName,
          'amount': debt.amount,
          'start_date': debt.startDate,
          'installment_months': debt.installmentMonths,
          'monthly_installment': debt.monthlyInstallment,
          'first_due_date': debt.firstDueDate,
          'is_reminder_active': debt.isReminderActive,
          'is_realized': debt.isRealized,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi update hutang ke Firestore: $e');
    }
  }

  // --- UPDATE RECEIVABLE (PIUTANG) ---
  Future<void> updateReceivable(model.ReceivableModel receivable) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    final receivables = await getReceivables();
    
    int index = receivables.indexWhere((r) => r.id == receivable.id);
    if (index >= 0) {
      receivables[index] = receivable;
    } else {
      receivables.add(receivable);
    }

    await prefs.setString(key, jsonEncode(receivables.map((r) => r.toMap()).toList()));

    // Regenerasi jadwal cicilan jika tenor/tanggal berubah
    if (receivable.id != null) {
      await _generateInstallments(receivable.id!, receivable.firstDueDate, receivable.installmentMonths, receivable.monthlyInstallment, 'receivable');
    }

    if (receivable.isReminderActive && receivable.firstDueDate.isNotEmpty && receivable.id != null) {
      try {
        DateTime parsedDueDate = DateTime.parse(receivable.firstDueDate);
        await NotificationHelper.schedulePaymentReminder(
          id: receivable.id!,
          title: 'Pengingat Piutang: ${receivable.debtorName}',
          body: 'Cicilan piutang jatuh tempo pada ${receivable.firstDueDate}. Mohon segera ditindaklanjuti.',
          dueDate: parsedDueDate,
        );
      } catch (e) {
        print('Gagal menjadwalkan ulang notifikasi piutang: $e');
      }
    } else if (receivable.id != null) {
      await NotificationHelper.cancelReminder(receivable.id!);
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null && receivable.id != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_receivable_${receivable.id}';

        await firestore.collection('receivables').doc(docId).set({
          'user_id': userId,
          'receivable_id': receivable.id,
          'item_id': receivable.itemId,
          'customer_id': receivable.customerId,
          'debtor_name': receivable.debtorName,
          'amount': receivable.amount,
          'start_date': receivable.startDate,
          'installment_months': receivable.installmentMonths,
          'monthly_installment': receivable.monthlyInstallment,
          'first_due_date': receivable.firstDueDate,
          'is_reminder_active': receivable.isReminderActive,
          'is_realized': receivable.isRealized,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi update piutang ke Firestore: $e');
    }
  }

  // --- MASTER LENDER (PEMBERI PINJAMAN) ---
  Future<List<Map<String, dynamic>>> getLenders() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('lenders_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => json as Map<String, dynamic>).toList();
  }

  Future<int> saveLender(Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('lenders_data');
    final lenders = await getLenders();

    int lenderId;
    bool isUpdate = row['id'] != null;

    if (isUpdate) {
      lenderId = row['id'] as int;
      int index = lenders.indexWhere((l) => (l['id'] as int?) == lenderId);
      
      if (index != -1) {
        lenders[index] = {
          'id': lenderId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
        };
      } else {
        lenderId = lenders.isEmpty ? 1 : (lenders.map((l) => (l['id'] ?? 0) as int).reduce((a, b) => a > b ? a : b) + 1);
        lenders.add({
          'id': lenderId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
        });
      }
    } else {
      lenderId = lenders.isEmpty ? 1 : (lenders.map((l) => (l['id'] ?? 0) as int).reduce((a, b) => a > b ? a : b) + 1);
      final newRow = {
        'id': lenderId,
        'name': row['name'],
        'phone': row['phone'],
        'address': row['address'],
      };
      lenders.add(newRow);
    }

    await prefs.setString(key, jsonEncode(lenders));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_lender_$lenderId';

        await firestore.collection('lenders').doc(docId).set({
          'user_id': userId,
          'lender_id': lenderId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi lender ke Firestore: $e');
    }

    return lenderId;
  }

  // --- MASTER CUSTOMER (PELANGGAN / DEBITUR) ---
  Future<List<Map<String, dynamic>>> getCustomers() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('customers_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => json as Map<String, dynamic>).toList();
  }

  Future<int> saveCustomer(Map<String, dynamic> row) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('customers_data');
    final customers = await getCustomers();

    int customerId;
    bool isUpdate = row['id'] != null;

    if (isUpdate) {
      customerId = row['id'] as int;
      int index = customers.indexWhere((c) => (c['id'] as int?) == customerId);
      
      if (index != -1) {
        customers[index] = {
          'id': customerId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
        };
      } else {
        customerId = customers.isEmpty ? 1 : (customers.map((c) => (c['id'] ?? 0) as int).reduce((a, b) => a > b ? a : b) + 1);
        customers.add({
          'id': customerId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
        });
      }
    } else {
      customerId = customers.isEmpty ? 1 : (customers.map((c) => (c['id'] ?? 0) as int).reduce((a, b) => a > b ? a : b) + 1);
      final newRow = {
        'id': customerId,
        'name': row['name'],
        'phone': row['phone'],
        'address': row['address'],
      };
      customers.add(newRow);
    }

    await prefs.setString(key, jsonEncode(customers));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_customer_$customerId';

        await firestore.collection('customers').doc(docId).set({
          'user_id': userId,
          'customer_id': customerId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi customer ke Firestore: $e');
    }

    return customerId;
  }

  // --- SYSTEM MANAJEMEN CICILAN (INSTALLMENTS / PAYLATER STYLE) ---
  
  // Ambil daftar cicilan berdasarkan parent id dan tipenya ('debt' atau 'receivable')
  Future<List<Map<String, dynamic>>> getInstallments(int parentId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    List<Map<String, dynamic>> allInstallments = jsonList.map((json) => json as Map<String, dynamic>).toList();
    
    return allInstallments.where((inst) => inst['parent_id'] == parentId).toList();
  }

  // Generate otomatis jadwal cicilan per bulan berdasarkan tanggal jatuh tempo pertama
  Future<void> _generateInstallments(int parentId, String firstDueDateStr, int months, double monthlyAmount, String type) async {
    if (firstDueDateStr.isEmpty || months <= 0) return;

    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);
    
    List<Map<String, dynamic>> allInstallments = [];
    if (dataStr != null) {
      List<dynamic> jsonList = jsonDecode(dataStr);
      allInstallments = jsonList.map((json) => json as Map<String, dynamic>).toList();
    }

    // Hapus cicilan lama untuk parent ini agar tidak duplikat saat edit
    allInstallments.removeWhere((inst) => inst['parent_id'] == parentId);

    DateTime firstDueDate = DateTime.parse(firstDueDateStr);

    for (int i = 1; i <= months; i++) {
      // Hitung tanggal jatuh tempo per bulan (bulan ke-1, ke-2, dst.)
      DateTime targetDate = DateTime(
        firstDueDate.year,
        firstDueDate.month + (i - 1),
        firstDueDate.day,
      );

      allInstallments.add({
        'parent_id': parentId,
        'installment_number': i,
        'amount': monthlyAmount,
        'due_date': targetDate.toIso8601String().split('T')[0],
        'is_paid': false,
        'paid_date': null,
      });
    }

    await prefs.setString(key, jsonEncode(allInstallments));
  }

  Future<void> _deleteInstallmentsForParent(int parentId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return;

    List<dynamic> jsonList = jsonDecode(dataStr);
    List<Map<String, dynamic>> allInstallments = jsonList.map((json) => json as Map<String, dynamic>).toList();
    
    allInstallments.removeWhere((inst) => inst['parent_id'] == parentId);
    await prefs.setString(key, jsonEncode(allInstallments));
  }

  // Bayar cicilan per bulan (Mencatat transaksi & mengubah status cicilan jadi lunas)
  Future<void> payInstallment(int parentId, int installmentNumber, int categoryIdForTx, String type, String titlePrefix) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return;

    List<dynamic> jsonList = jsonDecode(dataStr);
    List<Map<String, dynamic>> allInstallments = jsonList.map((json) => json as Map<String, dynamic>).toList();

    int index = allInstallments.indexWhere((inst) => inst['parent_id'] == parentId && inst['installment_number'] == installmentNumber);
    if (index < 0) return;

    final installment = allInstallments[index];
    if (installment['is_paid'] == true) return;

    double amount = (installment['amount'] is int) ? (installment['amount'] as int).toDouble() : installment['amount'];
    String todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Catat ke transaksi keuangan otomatis
    final newTx = model.TransactionModel(
      title: '$titlePrefix (Cicilan ke-$installmentNumber)',
      amount: amount,
      date: todayStr,
      categoryId: categoryIdForTx,
      note: 'Pembayaran cicilan otomatis',
    );
    await insertTransaction(newTx);

    // Update status cicilan menjadi lunas
    allInstallments[index]['is_paid'] = true;
    allInstallments[index]['paid_date'] = todayStr;

    await prefs.setString(key, jsonEncode(allInstallments));
  }

  // --- RECEIVABLE (PIUTANG) ---
  Future<List<model.ReceivableModel>> getReceivables() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => model.ReceivableModel.fromMap(json)).toList();
  }

  Future<int> insertReceivable(model.ReceivableModel receivable) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    final receivables = await getReceivables();
    
    int newId = receivables.isEmpty ? 1 : (receivables.map((r) => r.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    
    final newReceivable = model.ReceivableModel(
      id: newId,
      itemId: receivable.itemId,
      customerId: receivable.customerId,
      debtorName: receivable.debtorName,
      amount: receivable.amount,
      startDate: receivable.startDate,
      installmentMonths: receivable.installmentMonths,
      monthlyInstallment: receivable.monthlyInstallment,
      firstDueDate: receivable.firstDueDate,
      isReminderActive: receivable.isReminderActive,
      isRealized: receivable.isRealized,
    );

    receivables.add(newReceivable);
    await prefs.setString(key, jsonEncode(receivables.map((r) => r.toMap()).toList()));

    // Buat jadwal cicilan otomatis per bulan
    await _generateInstallments(newId, newReceivable.firstDueDate, newReceivable.installmentMonths, newReceivable.monthlyInstallment, 'receivable');

    if (newReceivable.isReminderActive && newReceivable.firstDueDate.isNotEmpty) {
      try {
        DateTime parsedDueDate = DateTime.parse(newReceivable.firstDueDate);
        await NotificationHelper.schedulePaymentReminder(
          id: newId,
          title: 'Pengingat Piutang: ${newReceivable.debtorName}',
          body: 'Cicilan piutang jatuh tempo pada ${newReceivable.firstDueDate}. Mohon segera ditindaklanjuti.',
          dueDate: parsedDueDate,
        );
      } catch (e) {
        print('Gagal menjadwalkan notifikasi piutang: $e');
      }
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_receivable_$newId';

        await firestore.collection('receivables').doc(docId).set({
          'user_id': userId,
          'receivable_id': newId,
          'item_id': newReceivable.itemId,
          'customer_id': newReceivable.customerId,
          'debtor_name': newReceivable.debtorName,
          'amount': newReceivable.amount,
          'start_date': newReceivable.startDate,
          'installment_months': newReceivable.installmentMonths,
          'monthly_installment': newReceivable.monthlyInstallment,
          'first_due_date': newReceivable.firstDueDate,
          'is_reminder_active': newReceivable.isReminderActive,
          'is_realized': newReceivable.isRealized,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi piutang ke Firestore: $e');
    }

    return newId;
  }

  Future<void> realizeReceivable(int receivableId, int categoryIdForTx) async {
    final receivables = await getReceivables();
    final index = receivables.indexWhere((r) => r.id == receivableId);
    if (index < 0) return;

    final receivable = receivables[index];
    if (receivable.isRealized) return;

    final newTx = model.TransactionModel(
      title: 'Pemberian Piutang: ${receivable.debtorName}',
      amount: receivable.amount,
      date: receivable.startDate,
      categoryId: categoryIdForTx,
      itemId: receivable.itemId,
      note: 'Realisasi otomatis dari modul piutang',
    );
    await insertTransaction(newTx);

    receivables[index] = receivable.copyWith(isRealized: true);
    
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    await prefs.setString(key, jsonEncode(receivables.map((r) => r.toMap()).toList()));

    await NotificationHelper.cancelReminder(receivableId);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_receivable_$receivableId';

        await firestore.collection('receivables').doc(docId).update({
          'is_realized': true,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Gagal update status realisasi piutang ke Firestore: $e');
    }
  }

  // --- DEBT (HUTANG) ---
  Future<List<model.DebtModel>> getDebts() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => model.DebtModel.fromMap(json)).toList();
  }

  Future<int> insertDebt(model.DebtModel debt) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    final debts = await getDebts();
    
    int newId = debts.isEmpty ? 1 : (debts.map((d) => d.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    
    final newDebt = model.DebtModel(
      id: newId,
      itemId: debt.itemId,
      lenderId: debt.lenderId,
      lenderName: debt.lenderName,
      amount: debt.amount,
      startDate: debt.startDate,
      installmentMonths: debt.installmentMonths,
      monthlyInstallment: debt.monthlyInstallment,
      firstDueDate: debt.firstDueDate,
      isReminderActive: debt.isReminderActive,
      isRealized: debt.isRealized,
    );

    debts.add(newDebt);
    await prefs.setString(key, jsonEncode(debts.map((d) => d.toMap()).toList()));

    // Buat jadwal cicilan otomatis per bulan
    await _generateInstallments(newId, newDebt.firstDueDate, newDebt.installmentMonths, newDebt.monthlyInstallment, 'debt');

    if (newDebt.isReminderActive && newDebt.firstDueDate.isNotEmpty) {
      try {
        DateTime parsedDueDate = DateTime.parse(newDebt.firstDueDate);
        await NotificationHelper.schedulePaymentReminder(
          id: newId + 100000, 
          title: 'Pengingat Hutang: ${newDebt.lenderName}',
          body: 'Cicilan hutang jatuh tempo pada ${newDebt.firstDueDate}. Mohon segera dibayarkan.',
          dueDate: parsedDueDate,
        );
      } catch (e) {
        print('Gagal menjadwalkan notifikasi hutang: $e');
      }
    }

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_debt_$newId';

        await firestore.collection('debts').doc(docId).set({
          'user_id': userId,
          'debt_id': newId,
          'item_id': newDebt.itemId,
          'lender_id': newDebt.lenderId,
          'lender_name': newDebt.lenderName,
          'amount': newDebt.amount,
          'start_date': newDebt.startDate,
          'installment_months': newDebt.installmentMonths,
          'monthly_installment': newDebt.monthlyInstallment,
          'first_due_date': newDebt.firstDueDate,
          'is_reminder_active': newDebt.isReminderActive,
          'is_realized': newDebt.isRealized,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi hutang ke Firestore: $e');
    }

    return newId;
  }

  Future<void> realizeDebt(int debtId, int categoryIdForTx) async {
    final debts = await getDebts();
    final index = debts.indexWhere((d) => d.id == debtId);
    if (index < 0) return;

    final debt = debts[index];
    if (debt.isRealized) return;

    final newTx = model.TransactionModel(
      title: 'Penerimaan Hutang: ${debt.lenderName}',
      amount: debt.amount,
      date: debt.startDate,
      categoryId: categoryIdForTx,
      itemId: debt.itemId,
      note: 'Realisasi otomatis dari modul hutang',
    );
    await insertTransaction(newTx);

    debts[index] = debt.copyWith(isRealized: true);
    
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    await prefs.setString(key, jsonEncode(debts.map((d) => d.toMap()).toList()));

    await NotificationHelper.cancelReminder(debtId + 100000);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_debt_$debtId';

        await firestore.collection('debts').doc(docId).update({
          'is_realized': true,
          'updated_at': FieldValue.serverTimestamp(),
        });
      }
    } catch (e) {
      print('Gagal update status realisasi hutang ke Firestore: $e');
    }
  }

  Future<void> saveOrUpdateBudget(model.BudgetModel budget) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('budgets_data');
    final budgets = await getBudgets();

    int index = budgets.indexWhere((b) => 
      b.categoryId == budget.categoryId && b.month == budget.month && b.year == budget.year
    );

    if (index >= 0) {
      budgets[index] = budget;
    } else {
      budgets.add(budget);
    }

    await prefs.setString(key, jsonEncode(budgets.map((b) => b.toMap()).toList()));
  }

  Future<void> initDefaultData() async {
    final prefs = await SharedPreferences.getInstance();
    final catKey = await _getStorageKey('categories_data');
    final itemKey = await _getStorageKey('items_data');
    
    if (!prefs.containsKey(catKey)) {
      final defaultCategories = [
        model.Category(id: 1, name: 'Gaji & Pendapatan', type: model.TransactionType.income, isActive: true, icon: 'work').toMap(),
        model.Category(id: 2, name: 'Makanan & Minuman', type: model.TransactionType.expense, isActive: true, icon: 'fastfood').toMap(),
        model.Category(id: 3, name: 'Transportasi', type: model.TransactionType.expense, isActive: true, icon: 'directions_car').toMap(),
        model.Category(id: 4, name: 'Belanja Bulanan', type: model.TransactionType.expense, isActive: true, icon: 'shopping_bag').toMap(),
      ];
      await prefs.setString(catKey, jsonEncode(defaultCategories));
    }

    if (!prefs.containsKey(itemKey)) {
      final defaultItems = [
        model.ItemModel(id: 1, barcode: '8996001301281', name: 'Susu Bendera Coklat 1Lt', categoryId: 2, defaultPrice: 18000, isActive: true, icon: 'fastfood').toMap(),
        model.ItemModel(id: 2, barcode: '8998866201019', name: 'Indomie Goreng Spesial', categoryId: 2, defaultPrice: 3500, isActive: true, icon: 'fastfood').toMap(),
        model.ItemModel(id: 3, barcode: '012345678905', name: 'Aqua Botol 600ml', categoryId: 2, defaultPrice: 3000, isActive: true, icon: 'fastfood').toMap(),
      ];
      await prefs.setString(itemKey, jsonEncode(defaultItems));
    }
  }

  // --- KATEGORI ---
  Future<List<model.Category>> getCategories() async {
    await initDefaultData();
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('categories_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => model.Category.fromMap(json)).toList();
  }

  Future<int> insertCategory(model.Category category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('categories_data');
    final categories = await getCategories();
    
    int newId = categories.isEmpty ? 1 : (categories.map((c) => c.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    
    final newCat = model.Category(
      id: newId,
      name: category.name,
      type: category.type,
      isActive: true,
      icon: category.icon,
    );
    
    categories.add(newCat);
    await prefs.setString(key, jsonEncode(categories.map((c) => c.toMap()).toList()));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_cat_$newId';

        await firestore.collection('categories').doc(docId).set({
          'user_id': userId,
          'category_id': newId,
          'name': newCat.name,
          'type': newCat.type == model.TransactionType.income ? 'income' : 'expense',
          'is_active': newCat.isActive,
          'icon': newCat.icon,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi kategori ke Firestore: $e');
    }

    return newId;
  }

  // --- MASTER ITEM ---
  Future<List<model.ItemModel>> getItems() async {
    await initDefaultData();
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('items_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => model.ItemModel.fromMap(json)).toList();
  }

  Future<List<model.ItemModel>> getProducts() async {
    return await getItems();
  }

  Future<int> insertItem(model.ItemModel item) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('items_data');
    final items = await getItems();
    
    if (items.any((i) => i.barcode == item.barcode && item.barcode != null && item.barcode!.isNotEmpty && i.isActive)) {
      throw Exception('Barcode sudah terdaftar pada item lain.');
    }

    int newId = items.isEmpty ? 1 : (items.map((i) => i.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    
    final newItem = model.ItemModel(
      id: newId,
      barcode: item.barcode,
      name: item.name,
      categoryId: item.categoryId,
      defaultPrice: item.defaultPrice,
      isActive: true,
      icon: item.icon,
    );

    items.add(newItem);
    await prefs.setString(key, jsonEncode(items.map((i) => i.toMap()).toList()));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_item_$newId';

        await firestore.collection('items').doc(docId).set({
          'user_id': userId,
          'item_id': newId,
          'barcode': newItem.barcode,
          'name': newItem.name,
          'category_id': newItem.categoryId,
          'default_price': newItem.defaultPrice,
          'is_active': newItem.isActive,
          'icon': newItem.icon,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi item ke Firestore: $e');
    }

    return newId;
  }

  Future<model.ItemModel?> getItemByBarcode(String barcode) async {
    final items = await getItems();
    try {
      return items.firstWhere((item) => item.barcode == barcode && item.isActive);
    } catch (e) {
      return null;
    }
  }

  Future<model.ItemModel?> getProductByBarcode(String barcode) async {
    return await getItemByBarcode(barcode);
  }

  Future<model.ItemModel?> getOwnerItemByBarcode(String barcode, {int? excludeItemId}) async {
    final items = await getItems();
    try {
      return items.firstWhere((item) => 
        item.barcode == barcode && item.isActive && (excludeItemId == null || item.id != excludeItemId)
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> updateItemBarcode(int itemId, String newBarcode) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('items_data');
    final items = await getItems();

    for (int i = 0; i < items.length; i++) {
      if (items[i].barcode == newBarcode && items[i].id != itemId) {
        items[i] = model.ItemModel(
          id: items[i].id,
          barcode: null,
          name: items[i].name,
          categoryId: items[i].categoryId,
          defaultPrice: items[i].defaultPrice,
          isActive: items[i].isActive,
          icon: items[i].icon,
        );
      }
    }

    for (int i = 0; i < items.length; i++) {
      if (items[i].id == itemId) {
        items[i] = model.ItemModel(
          id: items[i].id,
          barcode: newBarcode,
          name: items[i].name,
          categoryId: items[i].categoryId,
          defaultPrice: items[i].defaultPrice,
          isActive: items[i].isActive,
          icon: items[i].icon,
        );
        break;
      }
    }

    await prefs.setString(key, jsonEncode(items.map((i) => i.toMap()).toList()));
  }

  // --- TRANSAKSI ---
  Future<List<model.TransactionModel>> getTransactions() async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('transactions_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    List<model.TransactionModel> txs = jsonList.map((json) {
      return model.TransactionModel(
        id: json['id'],
        title: json['title'],
        amount: json['amount'] is int ? (json['amount'] as int).toDouble() : json['amount'],
        date: json['date'],
        categoryId: json['category_id'] ?? json['categoryId'] ?? 1,
        itemId: json['item_id'] ?? json['itemId'],
        note: json['note'],
      );
    }).toList();
    
    txs.sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return txs;
  }

  Future<model.TransactionModel?> getLastTransactionByItem(int itemId) async {
    final transactions = await getTransactions();
    try {
      return transactions.firstWhere((tx) => tx.itemId == itemId);
    } catch (e) {
      return null;
    }
  }

  Future<int> insertTransaction(model.TransactionModel transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('transactions_data');
    final transactions = await getTransactions();
    
    int newId = transactions.isEmpty ? 1 : (transactions.map((t) => t.id ?? 0).reduce((a, b) => a > b ? a : b) + 1);
    
    final newTx = model.TransactionModel(
      id: newId,
      title: transaction.title,
      amount: transaction.amount,
      date: transaction.date,
      categoryId: transaction.categoryId,
      itemId: transaction.itemId,
      note: transaction.note,
    );

    transactions.add(newTx);
    await prefs.setString(key, jsonEncode(transactions.map((t) => t.toMap()).toList()));

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_tx_$newId';

        await firestore.collection('transactions').doc(docId).set({
          'user_id': userId,
          'title': newTx.title,
          'amount': newTx.amount,
          'date': newTx.date,
          'category_id': newTx.categoryId,
          'item_id': newTx.itemId,
          'note': newTx.note,
          'created_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi transaksi ke Firestore: $e');
    }

    return newId;
  }

  Future<void> deleteTransaction(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('transactions_data');
    List<model.TransactionModel> transactions = await getTransactions();
    transactions.removeWhere((tx) => tx.id == id);
    await prefs.setString(
      key, 
      jsonEncode(transactions.map((t) => t.toMap()).toList()),
    );
  }

  Future<void> softDeleteCategory(int categoryId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('categories_data');
    final categories = await getCategories();

    for (int i = 0; i < categories.length; i++) {
      if (categories[i].id == categoryId) {
        categories[i] = model.Category(
          id: categories[i].id,
          name: categories[i].name,
          type: categories[i].type,
          isActive: false,
          icon: categories[i].icon,
        );
        break;
      }
    }
    await prefs.setString(key, jsonEncode(categories.map((c) => c.toMap()).toList()));
  }

  Future<void> softDeleteItem(int itemId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('items_data');
    final items = await getItems();

    for (int i = 0; i < items.length; i++) {
      if (items[i].id == itemId) {
        items[i] = model.ItemModel(
          id: items[i].id,
          barcode: items[i].barcode,
          name: items[i].name,
          categoryId: items[i].categoryId,
          defaultPrice: items[i].defaultPrice,
          isActive: false,
          icon: items[i].icon,
        );
        break;
      }
    }
    await prefs.setString(key, jsonEncode(items.map((i) => i.toMap()).toList()));
  }

  Future<void> deleteBudget(int categoryId, int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('budgets_data');
    List<model.BudgetModel> budgets = await getBudgets();
    
    budgets.removeWhere((b) => b.categoryId == categoryId && b.year == year && b.month == month);
    
    await prefs.setString(
      key, 
      jsonEncode(budgets.map((b) => b.toMap()).toList()),
    );

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_cat${categoryId}_${year}_${month}';

        await firestore.collection('budgets').doc(docId).delete();
      }
    } catch (e) {
      print('Gagal menghapus budget dari Firestore: $e');
    }
  }  

  Future<void> pullDataFromCloud() async {
    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser == null) return;

      final firestore = FirebaseFirestore.instance;
      final userId = currentUser.uid;
      final prefs = await SharedPreferences.getInstance();

      final catSnapshot = await firestore
          .collection('categories')
          .where('user_id', isEqualTo: userId)
          .get();

      if (catSnapshot.docs.isNotEmpty) {
        List<model.Category> cloudCategories = catSnapshot.docs.map((doc) {
          final data = doc.data();
          return model.Category(
            id: data['category_id'] ?? doc.id.hashCode.abs() % 1000,
            name: data['name'] ?? '',
            type: data['type'] == 'income' ? model.TransactionType.income : model.TransactionType.expense,
            isActive: data['is_active'] ?? true,
            icon: data['icon'],
          );
        }).toList();

        final catKey = await _getStorageKey('categories_data');
        await prefs.setString(catKey, jsonEncode(cloudCategories.map((c) => c.toMap()).toList()));
      }

      final itemSnapshot = await firestore
          .collection('items')
          .where('user_id', isEqualTo: userId)
          .get();

      if (itemSnapshot.docs.isNotEmpty) {
        List<model.ItemModel> cloudItems = itemSnapshot.docs.map((doc) {
          final data = doc.data();
          return model.ItemModel(
            id: data['item_id'] ?? doc.id.hashCode.abs() % 1000,
            barcode: data['barcode'],
            name: data['name'] ?? '',
            categoryId: data['category_id'] ?? 1,
            defaultPrice: (data['default_price'] ?? 0).toDouble(),
            isActive: data['is_active'] ?? true,
            icon: data['icon'],
          );
        }).toList();

        final itemKey = await _getStorageKey('items_data');
        await prefs.setString(itemKey, jsonEncode(cloudItems.map((i) => i.toMap()).toList()));
      }

      final txSnapshot = await firestore
          .collection('transactions')
          .where('user_id', isEqualTo: userId)
          .get();

      if (txSnapshot.docs.isNotEmpty) {
        List<model.TransactionModel> cloudTxs = txSnapshot.docs.map((doc) {
          final data = doc.data();
          return model.TransactionModel(
            id: data['transaction_id'] ?? doc.id.hashCode.abs() % 10000,
            title: data['title'] ?? '',
            amount: (data['amount'] ?? 0).toDouble(),
            date: data['date'] ?? '',
            categoryId: data['category_id'] ?? 1,
            itemId: data['item_id'],
            note: data['note'],
          );
        }).toList();

        final txKey = await _getStorageKey('transactions_data');
        await prefs.setString(txKey, jsonEncode(cloudTxs.map((t) => t.toMap()).toList()));
      }

      final budgetSnapshot = await firestore
          .collection('budgets')
          .where('user_id', isEqualTo: userId)
          .get();

      if (budgetSnapshot.docs.isNotEmpty) {
        List<model.BudgetModel> cloudBudgets = budgetSnapshot.docs.map((doc) {
          final data = doc.data();
          return model.BudgetModel(
            categoryId: data['category_id'] ?? 1,
            month: data['month'] ?? 1,
            year: data['year'] ?? 2026,
            amount: (data['amount'] ?? 0).toDouble(),
          );
        }).toList();

        final budgetKey = await _getStorageKey('budgets_data');
        await prefs.setString(budgetKey, jsonEncode(cloudBudgets.map((b) => b.toMap()).toList()));
      }

      final lenderSnapshot = await firestore
          .collection('lenders')
          .where('user_id', isEqualTo: userId)
          .get();

      if (lenderSnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> cloudLenders = lenderSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': data['lender_id'] ?? 1,
            'name': data['name'] ?? '',
            'phone': data['phone'],
            'address': data['address'],
          };
        }).toList();

        final lenderKey = await _getStorageKey('lenders_data');
        await prefs.setString(lenderKey, jsonEncode(cloudLenders));
      }

      final customerSnapshot = await firestore
          .collection('customers')
          .where('user_id', isEqualTo: userId)
          .get();

      if (customerSnapshot.docs.isNotEmpty) {
        List<Map<String, dynamic>> cloudCustomers = customerSnapshot.docs.map((doc) {
          final data = doc.data();
          return {
            'id': data['customer_id'] ?? 1,
            'name': data['name'] ?? '',
            'phone': data['phone'],
            'address': data['address'],
          };
        }).toList();

        final customerKey = await _getStorageKey('customers_data');
        await prefs.setString(customerKey, jsonEncode(cloudCustomers));
      }

      print('Berhasil menarik data dari Cloud ke lokal.');
    } catch (e) {
      print('Gagal menarik data dari Cloud: $e');
    }
  }  

// --- AMBIL SEMUA JADWAL CICILAN UNTUK KALENDER TAGIHAN ---
  Future<List<Map<String, dynamic>>> getAllScheduleInstallments() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Ambil cicilan hutang
    final debtKey = await _getStorageKey('debt_installments_data');
    final debtDataStr = prefs.getString(debtKey);
    List<Map<String, dynamic>> debtInsts = [];
    if (debtDataStr != null) {
      List<dynamic> list = jsonDecode(debtDataStr);
      debtInsts = list.map((e) => e as Map<String, dynamic>).toList();
    }

    // Ambil data master hutang untuk nama lender
    final debts = await getDebts();
    
    // Gabungkan detail nama ke cicilan hutang
    List<Map<String, dynamic>> enrichedDebtInsts = [];
    for (var inst in debtInsts) {
      final parentId = inst['parent_id'];
      final debtMatch = debts.firstWhere((d) => d.id == parentId, orElse: () => model.DebtModel(lenderName: 'Unknown', amount: 0, startDate: '', installmentMonths: 1, monthlyInstallment: 0, firstDueDate: ''));
      
      enrichedDebtInsts.add({
        ...inst,
        'name': debtMatch.lenderName,
        'type': 'debt',
      });
    }

    // Ambil cicilan piutang
    final recKey = await _getStorageKey('receivable_installments_data');
    final recDataStr = prefs.getString(recKey);
    List<Map<String, dynamic>> recInsts = [];
    if (recDataStr != null) {
      List<dynamic> list = jsonDecode(recDataStr);
      recInsts = list.map((e) => e as Map<String, dynamic>).toList();
    }

    // Ambil data master piutang untuk nama debtor
    final receivables = await getReceivables();

    // Gabungkan detail nama ke cicilan piutang
    List<Map<String, dynamic>> enrichedRecInsts = [];
    for (var inst in recInsts) {
      final parentId = inst['parent_id'];
      final recMatch = receivables.firstWhere((r) => r.id == parentId, orElse: () => model.ReceivableModel(debtorName: 'Unknown', amount: 0, startDate: '', installmentMonths: 1, monthlyInstallment: 0, firstDueDate: ''));

      enrichedRecInsts.add({
        ...inst,
        'name': recMatch.debtorName,
        'type': 'receivable',
      });
    }

    return [...enrichedDebtInsts, ...enrichedRecInsts];
  }  

  Future<List<model.BudgetModel>> getBudgetsByPeriod(int year, int month) async {
    final allBudgets = await getBudgets(); 
    return allBudgets.where((b) => b.year == year && b.month == month).toList();
  }

  Future<void> upsertBudget(model.BudgetModel budget) async {
    await saveOrUpdateBudget(budget);

    try {
      final currentUser = FirebaseAuth.instance.currentUser;
      if (currentUser != null) {
        final firestore = FirebaseFirestore.instance;
        final userId = currentUser.uid;
        final String docId = '${userId}_cat${budget.categoryId}_${budget.year}_${budget.month}';

        await firestore.collection('budgets').doc(docId).set({
          'user_id': userId,
          'category_id': budget.categoryId,
          'month': budget.month,
          'year': budget.year,
          'amount': budget.amount,
          'updated_at': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } catch (e) {
      print('Gagal sinkronisasi budget ke Firestore: $e');
    }
  }
}