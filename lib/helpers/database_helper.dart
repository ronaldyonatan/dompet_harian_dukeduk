import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'local_sync.dart';
import 'installment_schedule.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/finance_model.dart' as model;
import '../models/debt_model.dart' as model;
import '../models/receivable_model.dart' as model;
import '../helpers/notification_helper.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  DatabaseHelper._init();

  Future<void> deleteCustomer(int id) => _mutate(() => _deleteCustomer(id));
  Future<void> deleteLender(int id) => _mutate(() => _deleteLender(id));
  Future<void> deleteReceivable(int id) => _mutate(() => _deleteReceivable(id));
  Future<void> deleteDebt(int id) => _mutate(() => _deleteDebt(id));
  Future<void> updateDebt(model.DebtModel debt) =>
      _mutate(() => _updateDebt(debt));
  Future<void> updateReceivable(model.ReceivableModel receivable) =>
      _mutate(() => _updateReceivable(receivable));
  Future<int> saveLender(Map<String, dynamic> row) =>
      _mutate(() => _saveLender(row));
  Future<int> saveCustomer(Map<String, dynamic> row) =>
      _mutate(() => _saveCustomer(row));
  Future<void> payInstallment(
    int parentId,
    int installmentNumber,
    int categoryIdForTx,
    String type,
    String titlePrefix,
  ) => _mutate(
    () => _payInstallment(
      parentId,
      installmentNumber,
      categoryIdForTx,
      type,
      titlePrefix,
    ),
  );
  Future<int> insertReceivable(model.ReceivableModel receivable) =>
      _mutate(() => _insertReceivable(receivable));
  Future<void> realizeReceivable(int receivableId, int categoryIdForTx) =>
      _mutate(() => _realizeReceivable(receivableId, categoryIdForTx));
  Future<int> insertDebt(model.DebtModel debt) =>
      _mutate(() => _insertDebt(debt));
  Future<void> realizeDebt(int debtId, int categoryIdForTx) =>
      _mutate(() => _realizeDebt(debtId, categoryIdForTx));
  Future<void> saveOrUpdateBudget(model.BudgetModel budget) =>
      _mutate(() => _saveOrUpdateBudget(budget));
  Future<int> insertCategory(model.Category category) =>
      _mutate(() => _insertCategory(category));
  Future<int> insertItem(model.ItemModel item) =>
      _mutate(() => _insertItem(item));
  Future<void> updateItemBarcode(int itemId, String newBarcode) =>
      _mutate(() => _updateItemBarcode(itemId, newBarcode));
  Future<int> insertTransaction(model.TransactionModel transaction) =>
      _mutate(() => _insertTransaction(transaction));
  Future<void> deleteTransaction(int id) =>
      _mutate(() => _deleteTransaction(id));
  Future<void> softDeleteCategory(int categoryId) =>
      _mutate(() => _softDeleteCategory(categoryId));
  Future<void> softDeleteItem(int itemId) =>
      _mutate(() => _softDeleteItem(itemId));
  Future<void> deleteBudget(int categoryId, int year, int month) =>
      _mutate(() => _deleteBudget(categoryId, year, month));
  Future<void> upsertBudget(model.BudgetModel budget) =>
      _mutate(() => _upsertBudget(budget));

  Future<T> _mutate<T>(Future<T> Function() action) async {
    final result = await LocalSync.serial(() async {
      await _initDefaultData();
      return LocalSync.transaction(action);
    });
    try {
      await refreshReminders();
    } catch (e) {
      debugPrint('Reminder update failed: $e');
    }
    LocalSync.syncInBackground();
    return result;
  }

  Future<void> _ensureDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    if (!prefs.containsKey(await _getStorageKey('categories_data')) ||
        !prefs.containsKey(await _getStorageKey('items_data'))) {
      await initDefaultData();
    }
  }

  Future<void> initDefaultData() => LocalSync.serial(_initDefaultData);

  Future<void> refreshReminders() => LocalSync.serial(() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await NotificationHelper.cancelAll();
      return;
    }
    final reminders = <PaymentReminder>[];
    for (final type in ['debt', 'receivable']) {
      final prefs = await SharedPreferences.getInstance();
      final parents = LocalSync.decode(
        prefs.getString(
          await _getStorageKey(
            '${type == 'debt' ? 'debts' : 'receivables'}_data',
          ),
        ),
      );
      for (final parent in parents) {
        if (parent['is_reminder_active'] != true &&
            parent['is_reminder_active'] != 1) {
          continue;
        }
        var unpaid = (await getInstallments(
          parent['id'] as int,
          type,
        )).where((r) => r['is_paid'] != true).toList();
        // Upgrade legacy parents that have no generated schedule yet.
        if (unpaid.isEmpty &&
            (await getInstallments(parent['id'] as int, type)).isEmpty) {
          final due = DateTime.tryParse(
            parent['first_due_date'] as String? ?? '',
          );
          if (due != null &&
              (parent['monthly_installment'] as num? ?? 0) > 0 &&
              (parent['installment_months'] as int? ?? 0) > 0) {
            unpaid = buildInstallments(
              parentId: parent['id'] as int,
              firstDueDate: due,
              months: parent['installment_months'] as int,
              monthlyAmount: (parent['monthly_installment'] as num).toDouble(),
              existing: [],
            );
          }
        }
        unpaid.sort(
          (a, b) =>
              (a['due_date'] as String).compareTo(b['due_date'] as String),
        );
        if (unpaid.isEmpty) continue;
        final next = unpaid.first;
        final due = DateTime.tryParse(next['due_date'] as String);
        if (due == null) continue;
        final name = parent[type == 'debt' ? 'lender_name' : 'debtor_name'];
        reminders.add(
          PaymentReminder(
            key:
                '${FirebaseAuth.instance.currentUser!.uid}:$type:${parent['id']}',
            title: type == 'debt'
                ? 'Pengingat Cicilan Hutang'
                : 'Pengingat Pembayaran Piutang',
            body:
                'Cicilan ke-${next['installment_number']} $name jatuh tempo ${next['due_date']}.',
            dueDate: due,
          ),
        );
      }
    }
    await NotificationHelper.replaceReminders(reminders);
  });

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
  Future<void> _deleteCustomer(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('customers_data');
    List<Map<String, dynamic>> customers = await getCustomers();

    customers.removeWhere((c) => c['id'] == id);
    await LocalSync.write(prefs, key, jsonEncode(customers));
  }

  // --- DELETE MASTER LENDER ---
  Future<void> _deleteLender(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('lenders_data');
    List<Map<String, dynamic>> lenders = await getLenders();

    lenders.removeWhere((l) => l['id'] == id);
    await LocalSync.write(prefs, key, jsonEncode(lenders));
  }

  // --- DELETE RECEIVABLE (PIUTANG) & INSTALLMENTS ---
  Future<void> _deleteReceivable(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    List<model.ReceivableModel> receivables = await getReceivables();

    receivables.removeWhere((r) => r.id == id);
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(receivables.map((r) => r.toMap()).toList()),
    );

    // Hapus juga data cicilan terkait
    await _deleteInstallmentsForParent(id, 'receivable');
  }

  // --- DELETE DEBT (HUTANG) & INSTALLMENTS ---
  Future<void> _deleteDebt(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    List<model.DebtModel> debts = await getDebts();

    debts.removeWhere((d) => d.id == id);
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(debts.map((d) => d.toMap()).toList()),
    );

    // Hapus juga data cicilan terkait
    await _deleteInstallmentsForParent(id, 'debt');
  }

  // --- UPDATE DEBT (HUTANG) ---
  Future<void> _updateDebt(model.DebtModel debt) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    final debts = await getDebts();

    int index = debts.indexWhere((d) => d.id == debt.id);
    if (index >= 0) {
      debts[index] = debt;
    } else {
      debts.add(debt);
    }

    // Regenerasi jadwal cicilan jika tenor/tanggal berubah
    if (debt.id != null) {
      await _generateInstallments(
        debt.id!,
        debt.firstDueDate,
        debt.installmentMonths,
        debt.monthlyInstallment,
        'debt',
      );
    }

    await LocalSync.write(
      prefs,
      key,
      jsonEncode(debts.map((d) => d.toMap()).toList()),
    );
  }

  // --- UPDATE RECEIVABLE (PIUTANG) ---
  Future<void> _updateReceivable(model.ReceivableModel receivable) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    final receivables = await getReceivables();

    int index = receivables.indexWhere((r) => r.id == receivable.id);
    if (index >= 0) {
      receivables[index] = receivable;
    } else {
      receivables.add(receivable);
    }

    // Regenerasi jadwal cicilan jika tenor/tanggal berubah
    if (receivable.id != null) {
      await _generateInstallments(
        receivable.id!,
        receivable.firstDueDate,
        receivable.installmentMonths,
        receivable.monthlyInstallment,
        'receivable',
      );
    }

    await LocalSync.write(
      prefs,
      key,
      jsonEncode(receivables.map((r) => r.toMap()).toList()),
    );
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

  Future<int> _saveLender(Map<String, dynamic> row) async {
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
        lenderId = LocalSync.newId();
        lenders.add({
          'id': lenderId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
        });
      }
    } else {
      lenderId = LocalSync.newId();
      final newRow = {
        'id': lenderId,
        'name': row['name'],
        'phone': row['phone'],
        'address': row['address'],
      };
      lenders.add(newRow);
    }

    await LocalSync.write(prefs, key, jsonEncode(lenders));

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

  Future<int> _saveCustomer(Map<String, dynamic> row) async {
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
        customerId = LocalSync.newId();
        customers.add({
          'id': customerId,
          'name': row['name'],
          'phone': row['phone'],
          'address': row['address'],
        });
      }
    } else {
      customerId = LocalSync.newId();
      final newRow = {
        'id': customerId,
        'name': row['name'],
        'phone': row['phone'],
        'address': row['address'],
      };
      customers.add(newRow);
    }

    await LocalSync.write(prefs, key, jsonEncode(customers));

    return customerId;
  }

  // --- SYSTEM MANAJEMEN CICILAN (INSTALLMENTS / PAYLATER STYLE) ---

  // Ambil daftar cicilan berdasarkan parent id dan tipenya ('debt' atau 'receivable')
  Future<List<Map<String, dynamic>>> getInstallments(
    int parentId,
    String type,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    List<Map<String, dynamic>> allInstallments = jsonList
        .map((json) => json as Map<String, dynamic>)
        .toList();

    return allInstallments
        .where((inst) => inst['parent_id'] == parentId)
        .toList();
  }

  // Generate otomatis jadwal cicilan per bulan berdasarkan tanggal jatuh tempo pertama
  Future<void> _generateInstallments(
    int parentId,
    String firstDueDateStr,
    int months,
    double monthlyAmount,
    String type,
  ) async {
    if (firstDueDateStr.isEmpty) {
      throw ArgumentError('Tanggal jatuh tempo wajib diisi.');
    }

    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);

    List<Map<String, dynamic>> allInstallments = [];
    if (dataStr != null) {
      List<dynamic> jsonList = jsonDecode(dataStr);
      allInstallments = jsonList
          .map((json) => json as Map<String, dynamic>)
          .toList();
    }

    final existing = allInstallments
        .where((inst) => inst['parent_id'] == parentId)
        .toList();
    final generated = buildInstallments(
      parentId: parentId,
      firstDueDate: DateTime.parse(firstDueDateStr),
      months: months,
      monthlyAmount: monthlyAmount,
      existing: existing,
    );
    allInstallments.removeWhere((inst) => inst['parent_id'] == parentId);
    allInstallments.addAll(generated);

    await LocalSync.write(prefs, key, jsonEncode(allInstallments));
  }

  Future<void> _deleteInstallmentsForParent(int parentId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return;

    List<dynamic> jsonList = jsonDecode(dataStr);
    List<Map<String, dynamic>> allInstallments = jsonList
        .map((json) => json as Map<String, dynamic>)
        .toList();

    allInstallments.removeWhere((inst) => inst['parent_id'] == parentId);
    await LocalSync.write(prefs, key, jsonEncode(allInstallments));
  }

  // Bayar cicilan per bulan (Mencatat transaksi & mengubah status cicilan jadi lunas)
  Future<void> _payInstallment(
    int parentId,
    int installmentNumber,
    int categoryIdForTx,
    String type,
    String titlePrefix,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('${type}_installments_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return;

    List<dynamic> jsonList = jsonDecode(dataStr);
    List<Map<String, dynamic>> allInstallments = jsonList
        .map((json) => json as Map<String, dynamic>)
        .toList();

    int index = allInstallments.indexWhere(
      (inst) =>
          inst['parent_id'] == parentId &&
          inst['installment_number'] == installmentNumber,
    );
    if (index < 0) return;

    final installment = allInstallments[index];
    if (installment['is_paid'] == true) return;

    double amount = (installment['amount'] is int)
        ? (installment['amount'] as int).toDouble()
        : installment['amount'];
    String todayStr = DateTime.now().toIso8601String().split('T')[0];

    // Catat ke transaksi keuangan otomatis
    final newTx = model.TransactionModel(
      title: '$titlePrefix (Cicilan ke-$installmentNumber)',
      amount: amount,
      date: todayStr,
      categoryId: categoryIdForTx,
      note: 'Pembayaran cicilan otomatis',
    );
    await _insertTransaction(newTx);

    // Update status cicilan menjadi lunas
    allInstallments[index]['is_paid'] = true;
    allInstallments[index]['paid_date'] = todayStr;

    await LocalSync.write(prefs, key, jsonEncode(allInstallments));
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

  Future<int> _insertReceivable(model.ReceivableModel receivable) async {
    buildInstallments(
      parentId: 0,
      firstDueDate: DateTime.parse(receivable.firstDueDate),
      months: receivable.installmentMonths,
      monthlyAmount: receivable.monthlyInstallment,
      existing: [],
    );

    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    final receivables = await getReceivables();

    int newId = LocalSync.newId();

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
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(receivables.map((r) => r.toMap()).toList()),
    );

    // Buat jadwal cicilan otomatis per bulan
    await _generateInstallments(
      newId,
      newReceivable.firstDueDate,
      newReceivable.installmentMonths,
      newReceivable.monthlyInstallment,
      'receivable',
    );

    return newId;
  }

  Future<void> _realizeReceivable(int receivableId, int categoryIdForTx) async {
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
    await _insertTransaction(newTx);

    receivables[index] = receivable.copyWith(isRealized: true);

    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('receivables_data');
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(receivables.map((r) => r.toMap()).toList()),
    );
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

  Future<int> _insertDebt(model.DebtModel debt) async {
    buildInstallments(
      parentId: 0,
      firstDueDate: DateTime.parse(debt.firstDueDate),
      months: debt.installmentMonths,
      monthlyAmount: debt.monthlyInstallment,
      existing: [],
    );

    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    final debts = await getDebts();

    int newId = LocalSync.newId();

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
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(debts.map((d) => d.toMap()).toList()),
    );

    // Buat jadwal cicilan otomatis per bulan
    await _generateInstallments(
      newId,
      newDebt.firstDueDate,
      newDebt.installmentMonths,
      newDebt.monthlyInstallment,
      'debt',
    );

    return newId;
  }

  Future<void> _realizeDebt(int debtId, int categoryIdForTx) async {
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
    await _insertTransaction(newTx);

    debts[index] = debt.copyWith(isRealized: true);

    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('debts_data');
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(debts.map((d) => d.toMap()).toList()),
    );
  }

  Future<void> _saveOrUpdateBudget(model.BudgetModel budget) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('budgets_data');
    final budgets = await getBudgets();

    int index = budgets.indexWhere(
      (b) =>
          b.categoryId == budget.categoryId &&
          b.month == budget.month &&
          b.year == budget.year,
    );

    if (index >= 0) {
      budgets[index] = budget;
    } else {
      budgets.add(budget);
    }

    await LocalSync.write(
      prefs,
      key,
      jsonEncode(budgets.map((b) => b.toMap()).toList()),
    );
  }

  Future<void> _initDefaultData() async {
    final prefs = await SharedPreferences.getInstance();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) await LocalSync.recoverTransaction(prefs, uid);
    final catKey = await _getStorageKey('categories_data');
    final itemKey = await _getStorageKey('items_data');

    if (!prefs.containsKey(catKey)) {
      final defaultCategories = [
        model.Category(
          id: 1,
          name: 'Gaji & Pendapatan',
          type: model.TransactionType.income,
          isActive: true,
          icon: 'work',
        ).toMap(),
        model.Category(
          id: 2,
          name: 'Makanan & Minuman',
          type: model.TransactionType.expense,
          isActive: true,
          icon: 'fastfood',
        ).toMap(),
        model.Category(
          id: 3,
          name: 'Transportasi',
          type: model.TransactionType.expense,
          isActive: true,
          icon: 'directions_car',
        ).toMap(),
        model.Category(
          id: 4,
          name: 'Belanja Bulanan',
          type: model.TransactionType.expense,
          isActive: true,
          icon: 'shopping_bag',
        ).toMap(),
      ];
      await LocalSync.write(prefs, catKey, jsonEncode(defaultCategories));
    }

    if (!prefs.containsKey(itemKey)) {
      final defaultItems = [
        model.ItemModel(
          id: 1,
          barcode: '8996001301281',
          name: 'Susu Bendera Coklat 1Lt',
          categoryId: 2,
          defaultPrice: 18000,
          isActive: true,
          icon: 'fastfood',
        ).toMap(),
        model.ItemModel(
          id: 2,
          barcode: '8998866201019',
          name: 'Indomie Goreng Spesial',
          categoryId: 2,
          defaultPrice: 3500,
          isActive: true,
          icon: 'fastfood',
        ).toMap(),
        model.ItemModel(
          id: 3,
          barcode: '012345678905',
          name: 'Aqua Botol 600ml',
          categoryId: 2,
          defaultPrice: 3000,
          isActive: true,
          icon: 'fastfood',
        ).toMap(),
      ];
      await LocalSync.write(prefs, itemKey, jsonEncode(defaultItems));
    }
  }

  // --- KATEGORI ---
  Future<List<model.Category>> getCategories() async {
    await _ensureDefaults();
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('categories_data');
    final String? dataStr = prefs.getString(key);
    if (dataStr == null) return [];

    List<dynamic> jsonList = jsonDecode(dataStr);
    return jsonList.map((json) => model.Category.fromMap(json)).toList();
  }

  Future<int> _insertCategory(model.Category category) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('categories_data');
    final categories = await getCategories();

    int newId = LocalSync.newId();

    final newCat = model.Category(
      id: newId,
      name: category.name,
      type: category.type,
      isActive: true,
      icon: category.icon,
    );

    categories.add(newCat);
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(categories.map((c) => c.toMap()).toList()),
    );

    return newId;
  }

  // --- MASTER ITEM ---
  Future<List<model.ItemModel>> getItems() async {
    await _ensureDefaults();
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

  Future<int> _insertItem(model.ItemModel item) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('items_data');
    final items = await getItems();

    if (items.any(
      (i) =>
          i.barcode == item.barcode &&
          item.barcode != null &&
          item.barcode!.isNotEmpty &&
          i.isActive,
    )) {
      throw Exception('Barcode sudah terdaftar pada item lain.');
    }

    int newId = LocalSync.newId();

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
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(items.map((i) => i.toMap()).toList()),
    );

    return newId;
  }

  Future<model.ItemModel?> getItemByBarcode(String barcode) async {
    final items = await getItems();
    try {
      return items.firstWhere(
        (item) => item.barcode == barcode && item.isActive,
      );
    } catch (e) {
      return null;
    }
  }

  Future<model.ItemModel?> getProductByBarcode(String barcode) async {
    return await getItemByBarcode(barcode);
  }

  Future<model.ItemModel?> getOwnerItemByBarcode(
    String barcode, {
    int? excludeItemId,
  }) async {
    final items = await getItems();
    try {
      return items.firstWhere(
        (item) =>
            item.barcode == barcode &&
            item.isActive &&
            (excludeItemId == null || item.id != excludeItemId),
      );
    } catch (e) {
      return null;
    }
  }

  Future<void> _updateItemBarcode(int itemId, String newBarcode) async {
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

    await LocalSync.write(
      prefs,
      key,
      jsonEncode(items.map((i) => i.toMap()).toList()),
    );
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
        amount: json['amount'] is int
            ? (json['amount'] as int).toDouble()
            : json['amount'],
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

  Future<int> _insertTransaction(model.TransactionModel transaction) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('transactions_data');
    final transactions = await getTransactions();

    int newId = LocalSync.newId();

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
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(transactions.map((t) => t.toMap()).toList()),
    );

    return newId;
  }

  Future<void> _deleteTransaction(int id) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('transactions_data');
    List<model.TransactionModel> transactions = await getTransactions();
    transactions.removeWhere((tx) => tx.id == id);
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(transactions.map((t) => t.toMap()).toList()),
    );
  }

  Future<void> _softDeleteCategory(int categoryId) async {
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
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(categories.map((c) => c.toMap()).toList()),
    );
  }

  Future<void> _softDeleteItem(int itemId) async {
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
    await LocalSync.write(
      prefs,
      key,
      jsonEncode(items.map((i) => i.toMap()).toList()),
    );
  }

  Future<void> _deleteBudget(int categoryId, int year, int month) async {
    final prefs = await SharedPreferences.getInstance();
    final key = await _getStorageKey('budgets_data');
    List<model.BudgetModel> budgets = await getBudgets();

    budgets.removeWhere(
      (b) => b.categoryId == categoryId && b.year == year && b.month == month,
    );

    await LocalSync.write(
      prefs,
      key,
      jsonEncode(budgets.map((b) => b.toMap()).toList()),
    );
  }

  Future<void> pullDataFromCloud() async {
    await LocalSync.sync();
    await refreshReminders();
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
      final debtMatch = debts.firstWhere(
        (d) => d.id == parentId,
        orElse: () => model.DebtModel(
          lenderName: 'Unknown',
          amount: 0,
          startDate: '',
          installmentMonths: 1,
          monthlyInstallment: 0,
          firstDueDate: '',
        ),
      );

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
      final recMatch = receivables.firstWhere(
        (r) => r.id == parentId,
        orElse: () => model.ReceivableModel(
          debtorName: 'Unknown',
          amount: 0,
          startDate: '',
          installmentMonths: 1,
          monthlyInstallment: 0,
          firstDueDate: '',
        ),
      );

      enrichedRecInsts.add({
        ...inst,
        'name': recMatch.debtorName,
        'type': 'receivable',
      });
    }

    return [...enrichedDebtInsts, ...enrichedRecInsts];
  }

  Future<List<model.BudgetModel>> getBudgetsByPeriod(
    int year,
    int month,
  ) async {
    final allBudgets = await getBudgets();
    return allBudgets.where((b) => b.year == year && b.month == month).toList();
  }

  Future<void> _upsertBudget(model.BudgetModel budget) async {
    await _saveOrUpdateBudget(budget);
  }
}
