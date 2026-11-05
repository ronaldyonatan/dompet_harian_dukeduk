import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/database_helper.dart';
import '../models/finance_model.dart' as finance;
import '../models/receivable_model.dart' as receivable;
import '../helpers/Loading_Helper.dart';
import '../helpers/currency_formatter_helper.dart';

class ReceivableScreen extends StatefulWidget {
  final String currentLanguage;

  const ReceivableScreen({super.key, required this.currentLanguage});

  @override
  State<ReceivableScreen> createState() => _ReceivableScreenState();
}

class _ReceivableScreenState extends State<ReceivableScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<receivable.ReceivableModel> _receivables = [];
  List<Map<String, dynamic>> _customers = [];
  List<finance.ItemModel> _items = [];
  List<finance.Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final receivables = await DatabaseHelper.instance.getReceivables();

      List<Map<String, dynamic>> customers = [];
      try {
        customers = await DatabaseHelper.instance.getCustomers();
      } catch (_) {
        customers = [];
      }

      final items = await DatabaseHelper.instance.getItems();
      final categories = await DatabaseHelper.instance.getCategories();

      if (mounted) {
        setState(() {
          _receivables = receivables;
          _customers = customers;
          _items = items;
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error loading data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _showDeleteConfirmation(int id, String debtorName) {
    final isEn = widget.currentLanguage == 'en';
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(isEn ? 'Delete Receivable' : 'Hapus Piutang'),
        content: Text(
          isEn
              ? 'Are you sure you want to delete receivable for "$debtorName"?'
              : 'Apakah Anda yakin ingin menghapus piutang untuk "$debtorName"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(
              isEn ? 'Cancel' : 'Batal',
              style: const TextStyle(color: Colors.grey),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);

              if (!mounted) return;
              LoadingHelper.show(
                context,
                message: isEn ? 'Deleting...' : 'Menghapus...',
              );

              try {
                await DatabaseHelper.instance.deleteReceivable(id);
                await _loadData();

                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isEn
                          ? 'Receivable deleted successfully'
                          : 'Piutang berhasil dihapus',
                    ),
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } finally {
                if (mounted) {
                  LoadingHelper.hide(context);
                }
              }
            },
            child: Text(isEn ? 'Delete' : 'Hapus'),
          ),
        ],
      ),
    );
  }

  void _showAddOrEditReceivableDialog({
    receivable.ReceivableModel? existingReceivable,
  }) {
    final isEn = widget.currentLanguage == 'en';
    final isEdit = existingReceivable != null;
    final currencyFormat = NumberFormat.currency(
      locale: 'id_ID',
      symbol: '',
      decimalDigits: 0,
    );

    final debtorController = TextEditingController(
      text: isEdit ? existingReceivable.debtorName : '',
    );
    final amountController = TextEditingController(
      text: isEdit
          ? currencyFormat.format(existingReceivable.amount).trim()
          : '',
    );
    final monthsController = TextEditingController(
      text: isEdit ? existingReceivable.installmentMonths.toString() : '1',
    );
    final monthlyController = TextEditingController(
      text: isEdit
          ? currencyFormat.format(existingReceivable.monthlyInstallment).trim()
          : '',
    );

    int? selectedCustomerId = isEdit ? existingReceivable.customerId : null;
    int? selectedItemId = isEdit ? existingReceivable.itemId : null;
    bool isReminderActive = isEdit ? existingReceivable.isReminderActive : true;
    String startDate = isEdit
        ? existingReceivable.startDate
        : DateTime.now().toIso8601String().split('T')[0];
    String dueDate = isEdit
        ? existingReceivable.firstDueDate
        : DateTime.now().toIso8601String().split('T')[0];

    final incomeCategoryIds = _categories
        .where(
          (cat) =>
              cat.type == finance.TransactionType.income ||
              cat.type.name.toLowerCase() == 'income' ||
              cat.type.name.toLowerCase() == 'pendapatan',
        )
        .map((cat) => cat.id)
        .toSet();

    final incomeItems = _items
        .where(
          (item) =>
              item.isActive && incomeCategoryIds.contains(item.categoryId),
        )
        .toList();
    final availableItems = incomeItems.isNotEmpty
        ? incomeItems
        : _items.where((item) => item.isActive).toList();

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (builderContext, setDialogState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Text(
                isEdit
                    ? (isEn ? 'Edit Receivable' : 'Ubah Piutang')
                    : (isEn ? 'Add New Receivable' : 'Tambah Piutang Baru'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DropdownButtonFormField<int>(
                      initialValue: selectedCustomerId,
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Select Customer'
                            : 'Pilih Pelanggan / Customer',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      items: _customers.map((customer) {
                        final id = customer['id'] as int?;
                        final name = customer['name']?.toString() ?? '';
                        return DropdownMenuItem<int>(
                          value: id,
                          child: Text(name, overflow: TextOverflow.ellipsis),
                        );
                      }).toList(),
                      onChanged: (val) {
                        setDialogState(() {
                          selectedCustomerId = val;
                          final selectedCust = _customers.firstWhere(
                            (c) => c['id'] == val,
                            orElse: () => {'name': ''},
                          );
                          final custName =
                              selectedCust['name'] as String? ?? '';
                          debtorController.text = custName;
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: debtorController,
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Debtor Name'
                            : 'Nama Peminjam / Debitur',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        labelText: isEn ? 'Receivable Amount' : 'Nilai Piutang',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final cleanVal = val.replaceAll(RegExp(r'[^0-9]'), '');
                        final amt = double.tryParse(cleanVal) ?? 0;
                        final months = int.tryParse(monthsController.text) ?? 1;
                        if (months > 0) {
                          monthlyController.text = currencyFormat
                              .format(amt / months)
                              .trim();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: monthsController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Installment (Months)'
                            : 'Lama Cicilan (Bulan)',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onChanged: (val) {
                        final months = int.tryParse(val) ?? 1;
                        final cleanAmt = amountController.text.replaceAll(
                          RegExp(r'[^0-9]'),
                          '',
                        );
                        final amt = double.tryParse(cleanAmt) ?? 0;
                        if (months > 0) {
                          monthlyController.text = currencyFormat
                              .format(amt / months)
                              .trim();
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: monthlyController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [CurrencyInputFormatter()],
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Monthly Installment'
                            : 'Cicilan per Bulan',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // BARIS TERPISAH UNTUK START DATE & DUE DATE
                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: isEn ? 'Start Date' : 'Tgl Mulai',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                        suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      ),
                      controller: TextEditingController(text: startDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: builderContext,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(
                            () => startDate = picked.toIso8601String().split(
                              'T',
                            )[0],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: isEn ? 'First Due Date' : 'Tgl Jatuh Tempo',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                        suffixIcon: const Icon(Icons.calendar_today, size: 18),
                      ),
                      controller: TextEditingController(text: dueDate),
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: builderContext,
                          initialDate: DateTime.now(),
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2030),
                        );
                        if (picked != null) {
                          setDialogState(
                            () => dueDate = picked.toIso8601String().split(
                              'T',
                            )[0],
                          );
                        }
                      },
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<int>(
                      initialValue: selectedItemId,
                      decoration: InputDecoration(
                        labelText: isEn
                            ? 'Select Item (Income)'
                            : 'Pilih Item / Pendapatan',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      items: availableItems.map((item) {
                        return DropdownMenuItem<int>(
                          value: item.id,
                          child: Text(
                            item.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) =>
                          setDialogState(() => selectedItemId = val),
                    ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      title: Text(
                        isEn
                            ? 'Enable Payment Reminder'
                            : 'Aktifkan Reminder Pembayaran',
                        style: const TextStyle(fontSize: 12),
                      ),
                      value: isReminderActive,
                      activeThumbColor: const Color(0xFF1A237E),
                      onChanged: (val) =>
                          setDialogState(() => isReminderActive = val),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: Text(
                    isEn ? 'Cancel' : 'Batal',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: () async {
                    final debtor = debtorController.text.trim();
                    final amount =
                        double.tryParse(
                          amountController.text.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          ),
                        ) ??
                        0;
                    final months = int.tryParse(monthsController.text) ?? 1;
                    final monthly =
                        double.tryParse(
                          monthlyController.text.replaceAll(
                            RegExp(r'[^0-9]'),
                            '',
                          ),
                        ) ??
                        0;

                    if (debtor.isEmpty ||
                        amount <= 0 ||
                        months < 1 ||
                        months > 600 ||
                        monthly <= 0) {
                      ScaffoldMessenger.of(builderContext).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEn
                                ? 'Enter name, amount, term (1–600 months), and a positive installment'
                                : 'Isi nama, nominal, tenor 1–600 bulan, dan cicilan lebih dari nol',
                          ),
                          backgroundColor: Colors.orange,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(dialogContext);

                    if (!mounted) return;
                    LoadingHelper.show(
                      context,
                      message: isEn
                          ? 'Saving receivable...'
                          : 'Menyimpan piutang...',
                    );

                    try {
                      int savedReceivableId;
                      if (isEdit) {
                        savedReceivableId = existingReceivable.id!;
                        final updatedReceivable = receivable.ReceivableModel(
                          id: savedReceivableId,
                          itemId: selectedItemId,
                          customerId: selectedCustomerId,
                          debtorName: debtor,
                          amount: amount,
                          startDate: startDate,
                          installmentMonths: months,
                          monthlyInstallment: monthly,
                          firstDueDate: dueDate,
                          isReminderActive: isReminderActive,
                          isRealized: existingReceivable.isRealized,
                        );
                        await DatabaseHelper.instance.updateReceivable(
                          updatedReceivable,
                        );
                      } else {
                        final newReceivable = receivable.ReceivableModel(
                          itemId: selectedItemId,
                          customerId: selectedCustomerId,
                          debtorName: debtor,
                          amount: amount,
                          startDate: startDate,
                          installmentMonths: months,
                          monthlyInstallment: monthly,
                          firstDueDate: dueDate,
                          isReminderActive: isReminderActive,
                          isRealized: false,
                        );
                        savedReceivableId = await DatabaseHelper.instance
                            .insertReceivable(newReceivable);
                      }

                      await _loadData();

                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            isEn
                                ? 'Receivable saved successfully!'
                                : 'Piutang berhasil disimpan!',
                          ),
                          backgroundColor: Colors.green,
                        ),
                      );
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: $e'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } finally {
                      if (mounted) {
                        LoadingHelper.hide(context);
                      }
                    }
                  },
                  child: Text(isEn ? 'Save' : 'Simpan'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showInstallmentsDetailSheet(
    receivable.ReceivableModel receivableItem,
  ) async {
    final isEn = widget.currentLanguage == 'en';
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    final incomeCategories = _categories
        .where(
          (cat) =>
              cat.type == finance.TransactionType.income ||
              cat.type.name.toLowerCase() == 'income' ||
              cat.type.name.toLowerCase() == 'pendapatan',
        )
        .toList();
    final availableCategories = incomeCategories.isNotEmpty
        ? incomeCategories
        : _categories;
    int? selectedCategory = availableCategories.isNotEmpty
        ? availableCategories.first.id
        : (_categories.isNotEmpty ? _categories.first.id : 1);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            return FutureBuilder<List<Map<String, dynamic>>>(
              future: DatabaseHelper.instance.getInstallments(
                receivableItem.id!,
                'receivable',
              ),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const SizedBox(
                    height: 250,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF1A237E),
                      ),
                    ),
                  );
                }

                final installments = snapshot.data ?? [];
                final paidCount = installments
                    .where((i) => i['is_paid'] == true)
                    .length;
                final totalCount = installments.length;
                final progress = totalCount > 0 ? paidCount / totalCount : 0.0;

                return Container(
                  padding: const EdgeInsets.all(20),
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.75,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEn
                                ? 'Installment Details'
                                : 'Rincian Cicilan: ${receivableItem.debtorName}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => Navigator.pop(sheetContext),
                          ),
                        ],
                      ),
                      const Divider(),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isEn
                                ? 'Progress: $paidCount of $totalCount paid'
                                : 'Status: $paidCount dari $totalCount lunas',
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            '${(progress * 100).toStringAsFixed(0)}%',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A237E),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: progress,
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.green,
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: installments.isEmpty
                            ? Center(
                                child: Text(
                                  isEn
                                      ? 'No installments found'
                                      : 'Belum ada jadwal cicilan',
                                ),
                              )
                            : ListView.builder(
                                itemCount: installments.length,
                                itemBuilder: (context, index) {
                                  final inst = installments[index];
                                  final int instNo = inst['installment_number'];
                                  final double amt = (inst['amount'] is int)
                                      ? (inst['amount'] as int).toDouble()
                                      : inst['amount'];
                                  final String dueDate = inst['due_date'];
                                  final bool isPaid = inst['is_paid'] == true;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: isPaid
                                          ? Colors.green.shade50
                                          : Colors.white,
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: isPaid
                                            ? Colors.green.shade200
                                            : Colors.grey.shade300,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              isEn
                                                  ? 'Installment #$instNo'
                                                  : 'Cicilan ke-$instNo',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                                color: isPaid
                                                    ? Colors.green.shade800
                                                    : Colors.black87,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              currencyFormatter.format(amt),
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              '${isEn ? "Due Date" : "Jatuh Tempo"}: $dueDate',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ],
                                        ),
                                        isPaid
                                            ? Chip(
                                                label: Text(
                                                  isEn ? 'Paid' : 'Lunas',
                                                  style: TextStyle(
                                                    color:
                                                        Colors.green.shade800,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                                backgroundColor:
                                                    Colors.green.shade100,
                                              )
                                            : ElevatedButton(
                                                style: ElevatedButton.styleFrom(
                                                  backgroundColor: const Color(
                                                    0xFF1A237E,
                                                  ),
                                                  foregroundColor: Colors.white,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 14,
                                                        vertical: 8,
                                                      ),
                                                  shape: RoundedRectangleBorder(
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                  ),
                                                ),
                                                onPressed: () async {
                                                  final unpaidsBefore = installments
                                                      .where(
                                                        (i) =>
                                                            i['installment_number'] <
                                                                instNo &&
                                                            i['is_paid'] !=
                                                                true,
                                                      )
                                                      .toList();

                                                  int targetInstNo = instNo;
                                                  String infoText = isEn
                                                      ? 'Are you sure you want to receive payment for installment #$instNo of ${currencyFormatter.format(amt)}?'
                                                      : 'Yakin ingin menerima pembayaran Cicilan ke-$instNo sebesar ${currencyFormatter.format(amt)}?';

                                                  if (unpaidsBefore
                                                      .isNotEmpty) {
                                                    final firstUnpaid =
                                                        unpaidsBefore.first;
                                                    targetInstNo =
                                                        firstUnpaid['installment_number'];
                                                    infoText = isEn
                                                        ? 'Installment #$targetInstNo is still unpaid. You must collect sequentially starting from the earliest. Receive payment for installment #$targetInstNo now?'
                                                        : 'Cicilan ke-$targetInstNo belum lunas. Penerimaan harus berurutan dari yang awal. Terima cicilan ke-$targetInstNo terlebih dahulu?';
                                                  }

                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (dialogCtx) => AlertDialog(
                                                      title: Text(
                                                        isEn
                                                            ? 'Confirm Payment Collection'
                                                            : 'Konfirmasi Penerimaan Pembayaran',
                                                      ),
                                                      content: Text(infoText),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogCtx,
                                                                false,
                                                              ),
                                                          child: Text(
                                                            isEn
                                                                ? 'Cancel'
                                                                : 'Batal',
                                                            style:
                                                                const TextStyle(
                                                                  color: Colors
                                                                      .grey,
                                                                ),
                                                          ),
                                                        ),
                                                        ElevatedButton(
                                                          style:
                                                              ElevatedButton.styleFrom(
                                                                backgroundColor:
                                                                    const Color(
                                                                      0xFF1A237E,
                                                                    ),
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                dialogCtx,
                                                                true,
                                                              ),
                                                          child: Text(
                                                            isEn
                                                                ? 'Yes, Receive'
                                                                : 'Ya, Terima',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (confirmed != true) return;

                                                  await DatabaseHelper.instance
                                                      .payInstallment(
                                                        receivableItem.id!,
                                                        targetInstNo,
                                                        selectedCategory!,
                                                        'receivable',
                                                        'Terima Piutang: ${receivableItem.debtorName}',
                                                      );

                                                  final updatedInstallments =
                                                      await DatabaseHelper
                                                          .instance
                                                          .getInstallments(
                                                            receivableItem.id!,
                                                            'receivable',
                                                          );
                                                  final allNowPaid =
                                                      updatedInstallments
                                                          .isNotEmpty &&
                                                      updatedInstallments.every(
                                                        (i) =>
                                                            i['is_paid'] ==
                                                            true,
                                                      );

                                                  if (allNowPaid) {
                                                    final updatedReceivable =
                                                        receivableItem.copyWith(
                                                          isRealized: true,
                                                        );
                                                    await DatabaseHelper
                                                        .instance
                                                        .updateReceivable(
                                                          updatedReceivable,
                                                        );
                                                  }

                                                  setSheetState(() {});
                                                  await _loadData();

                                                  if (!mounted) return;
                                                  ScaffoldMessenger.of(
                                                    context,
                                                  ).showSnackBar(
                                                    SnackBar(
                                                      content: Text(
                                                        isEn
                                                            ? 'Installment #$targetInstNo collected successfully!'
                                                            : 'Cicilan ke-$targetInstNo berhasil diterima!',
                                                      ),
                                                      backgroundColor:
                                                          Colors.green,
                                                    ),
                                                  );

                                                  if (allNowPaid &&
                                                      sheetContext.mounted) {
                                                    Navigator.pop(sheetContext);
                                                  }
                                                },
                                                child: Text(
                                                  isEn ? 'Receive' : 'Terima',
                                                  style: const TextStyle(
                                                    fontSize: 12,
                                                  ),
                                                ),
                                              ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildReceivableList(
    List<receivable.ReceivableModel> list, {
    required bool isDoneTab,
  }) {
    final isEn = widget.currentLanguage == 'en';
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    if (list.isEmpty) {
      return Center(
        child: Text(
          isEn ? 'No receivable records found.' : 'Belum ada data piutang.',
          style: const TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final itemReceivable = list[index];
        final itemName = _items
            .firstWhere(
              (i) => i.id == itemReceivable.itemId,
              orElse: () => finance.ItemModel(name: '-', categoryId: 0),
            )
            .name;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.02),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    itemReceivable.debtorName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  Chip(
                    label: Text(
                      itemReceivable.isRealized
                          ? (isEn ? 'Realized' : 'Teralisasi')
                          : (isEn ? 'Pending' : 'Belum Teralisasi'),
                      style: TextStyle(
                        fontSize: 10,
                        color: itemReceivable.isRealized
                            ? Colors.green.shade700
                            : Colors.orange.shade800,
                      ),
                    ),
                    backgroundColor: itemReceivable.isRealized
                        ? Colors.green.shade50
                        : Colors.orange.shade50,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '${isEn ? "Item Bridge" : "Item Ter-bridge"}: $itemName',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Total Receivable' : 'Total Piutang',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        currencyFormatter.format(itemReceivable.amount),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEn ? 'Monthly Installment' : 'Cicilan / Bulan',
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                      Text(
                        '${currencyFormatter.format(itemReceivable.monthlyInstallment)} (${itemReceivable.installmentMonths}x)',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        itemReceivable.isReminderActive
                            ? Icons.notifications_active
                            : Icons.notifications_off,
                        size: 16,
                        color: itemReceivable.isReminderActive
                            ? Colors.indigo
                            : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        itemReceivable.isReminderActive
                            ? (isEn ? 'Reminder On' : 'Reminder Aktif')
                            : (isEn ? 'Reminder Off' : 'Reminder Mati'),
                        style: TextStyle(
                          fontSize: 11,
                          color: itemReceivable.isReminderActive
                              ? Colors.indigo
                              : Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  if (!isDoneTab)
                    Row(
                      children: [
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF1A237E),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          icon: const Icon(Icons.list_alt, size: 16),
                          label: Text(
                            isEn ? 'Installments' : 'Detail Cicilan',
                            style: const TextStyle(fontSize: 12),
                          ),
                          onPressed: () =>
                              _showInstallmentsDetailSheet(itemReceivable),
                        ),
                        const SizedBox(width: 6),
                        IconButton(
                          icon: const Icon(
                            Icons.edit_outlined,
                            color: Colors.blue,
                            size: 20,
                          ),
                          onPressed: () => _showAddOrEditReceivableDialog(
                            existingReceivable: itemReceivable,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.delete_outline,
                            color: Colors.red,
                            size: 20,
                          ),
                          onPressed: () => _showDeleteConfirmation(
                            itemReceivable.id!,
                            itemReceivable.debtorName,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.currentLanguage == 'en';

    final outstandingList = _receivables.where((r) => !r.isRealized).toList();
    final doneList = _receivables.where((r) => r.isRealized).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Text(
          isEn ? 'Receivables' : 'Piutang',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          indicatorColor: Colors.white,
          tabs: [
            Tab(
              text: isEn
                  ? 'Outstanding (${outstandingList.length})'
                  : 'Belum Teralisasi (${outstandingList.length})',
            ),
            Tab(
              text: isEn
                  ? 'Done (${doneList.length})'
                  : 'Histori (${doneList.length})',
            ),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)),
            )
          : TabBarView(
              controller: _tabController,
              children: [
                _buildReceivableList(outstandingList, isDoneTab: false),
                _buildReceivableList(doneList, isDoneTab: true),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A237E),
        onPressed: () => _showAddOrEditReceivableDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}
