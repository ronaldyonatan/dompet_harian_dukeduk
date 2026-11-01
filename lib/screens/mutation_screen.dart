import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/finance_model.dart' as model;
import '../constants/app_icons.dart';

class MutationScreen extends StatefulWidget {
  final String languageCode;
  const MutationScreen({super.key, required this.languageCode});

  @override
  State<MutationScreen> createState() => _MutationScreenState();
}

class _MutationScreenState extends State<MutationScreen> {
  List<model.TransactionModel> _allTransactions = [];
  List<model.TransactionModel> _filteredTransactions = [];
  List<model.Category> _categories = [];
  List<model.ItemModel> _items = [];
  bool _isLoading = true;
  bool _isActionLoading = false;

  DateTime? _startDate;
  DateTime? _endDate;
  
  late String _selectedMonth;
  late String _selectedYear;
  
  final TextEditingController _searchController = TextEditingController();
  final List<String> _yearsList = ['Semua', '2024', '2025', '2026', '2027', '2028', '2029', '2030'];

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateFormat('MM').format(now);
    _selectedYear = DateFormat('yyyy').format(now);
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final txs = await DatabaseHelper.instance.getTransactions();
    final cats = await DatabaseHelper.instance.getCategories();
    final items = await DatabaseHelper.instance.getItems();
    setState(() {
      _allTransactions = txs;
      _categories = cats;
      _items = items;
      _isLoading = false;
    });
    _applyFilter();
  }

  Map<String, String> _getMonthsMap(bool isEn) {
    return {
      'Semua': isEn ? 'All Months' : 'Semua Bulan',
      '01': isEn ? 'January' : 'Januari', 
      '02': isEn ? 'February' : 'Februari', 
      '03': isEn ? 'March' : 'Maret', 
      '04': isEn ? 'April' : 'April',
      '05': isEn ? 'May' : 'Mei', 
      '06': isEn ? 'June' : 'Juni', 
      '07': isEn ? 'July' : 'Juli', 
      '08': isEn ? 'August' : 'Agustus',
      '09': isEn ? 'September' : 'September', 
      '10': isEn ? 'October' : 'Oktober', 
      '11': isEn ? 'November' : 'November', 
      '12': isEn ? 'December' : 'Desember',
    };
  }

  /// Mendapatkan detail ikon & warna berdasarkan transaksi dari AppIcons
  Map<String, dynamic> _getItemIconDetails(model.TransactionModel tx) {
    model.ItemModel? matchedItem;
    try {
      matchedItem = _items.firstWhere(
        (item) => item.name.toLowerCase().trim() == tx.title.toLowerCase().trim(),
      );
    } catch (_) {
      matchedItem = null;
    }

    final String iconName = matchedItem?.icon ?? 'category';
    final IconData iconData = AppIcons.getIconData(iconName);
    final Map<String, Color> colors = AppIcons.getIconThemeColor(iconName);

    return {
      'iconData': iconData,
      'bg': colors['bg'],
      'fg': colors['fg'],
    };
  }

  void _applyFilter() {
    final query = _searchController.text.toLowerCase().trim();

    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        bool matchMonth = true;
        bool matchYear = true;
        bool matchDateRange = true;
        bool matchSearch = true;

        final txDateStr = tx.date.length >= 10 ? tx.date.substring(0, 10) : tx.date;
        final txDate = DateTime.tryParse(txDateStr) ?? DateTime.now();
        final txYear = tx.date.length >= 4 ? tx.date.substring(0, 4) : '';
        final txMonth = tx.date.length >= 7 ? tx.date.substring(5, 7) : '';

        if (_selectedYear != 'Semua') {
          matchYear = (txYear == _selectedYear);
        }
        if (_selectedMonth != 'Semua') {
          matchMonth = (txMonth == _selectedMonth);
        }
        if (_startDate != null && _endDate != null) {
          final normalizedTx = DateTime(txDate.year, txDate.month, txDate.day);
          final normalizedStart = DateTime(_startDate!.year, _startDate!.month, _startDate!.day);
          final normalizedEnd = DateTime(_endDate!.year, _endDate!.month, _endDate!.day);
          matchDateRange = normalizedTx.compareTo(normalizedStart) >= 0 && 
                           normalizedTx.compareTo(normalizedEnd) <= 0;
        }

        if (query.isNotEmpty) {
          final isEn = widget.languageCode == 'en';
          final cat = _categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => model.Category(id: 0, name: isEn ? 'Others' : 'Lainnya', type: model.TransactionType.expense),
          );
          
          final titleMatch = tx.title.toLowerCase().contains(query);
          final categoryMatch = cat.name.toLowerCase().contains(query);
          final noteMatch = tx.note != null && tx.note!.toLowerCase().contains(query);

          matchSearch = titleMatch || categoryMatch || noteMatch;
        }

        return matchYear && matchMonth && matchDateRange && matchSearch;
      }).toList();
    });
  }

  void _resetFilter() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _searchController.clear();
      final now = DateTime.now();
      _selectedMonth = DateFormat('MM').format(now);
      _selectedYear = DateFormat('yyyy').format(now);
    });
    _applyFilter();
  }

  Future<void> _pickDateRange(BuildContext context) async {
    final pickedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
      initialDateRange: _startDate != null && _endDate != null 
          ? DateTimeRange(start: _startDate!, end: _endDate!) 
          : null,
    );

    if (pickedRange != null) {
      setState(() {
        _startDate = pickedRange.start;
        _endDate = pickedRange.end;
      });
      _applyFilter();
    }
  }

  Future<void> _executeDeleteTransaction(int id) async {
    final isEn = widget.languageCode == 'en';
    setState(() => _isActionLoading = true);
    try {
      await DatabaseHelper.instance.deleteTransaction(id);
      await _loadData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEn ? 'Transaction successfully deleted' : 'Transaksi berhasil dihapus'), 
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isActionLoading = false);
      }
    }
  }

  Future<void> _deleteTransaction(int id, String title) async {
    final isEn = widget.languageCode == 'en';
    bool? confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(isEn ? 'Delete Transaction' : 'Hapus Transaksi', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text(isEn ? 'Are you sure you want to delete "$title"?' : 'Yakin ingin menghapus transaksi "$title"?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEn ? 'Cancel' : 'Batal', style: const TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
            onPressed: () => Navigator.pop(context, true),
            child: Text(isEn ? 'Delete' : 'Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _executeDeleteTransaction(id);
    }
  }

  void _showTransactionDetail(model.TransactionModel tx) {
    final isEn = widget.languageCode == 'en';
    final currencyFormatter = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
    final cat = _categories.firstWhere(
      (c) => c.id == tx.categoryId,
      orElse: () => model.Category(id: 0, name: isEn ? 'Others' : 'Lainnya', type: model.TransactionType.expense),
    );
    final isIncome = cat.type == model.TransactionType.income;
    final iconDetails = _getItemIconDetails(tx);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: iconDetails['bg'],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  iconDetails['iconData'], 
                  color: iconDetails['fg'], 
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(isEn ? 'Transaction Detail' : 'Detail Transaksi', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(isEn ? 'Item / Title' : 'Item / Judul', tx.title),
              const Divider(height: 16),
              _buildDetailRow(isEn ? 'Category (Group)' : 'Kategori (Group)', cat.name),
              const Divider(height: 16),
              _buildDetailRow(isEn ? 'Type' : 'Tipe', isIncome ? (isEn ? 'Income' : 'Pemasukan') : (isEn ? 'Expense' : 'Pengeluaran')),
              const Divider(height: 16),
              _buildDetailRow(isEn ? 'Amount' : 'Nominal', currencyFormatter.format(tx.amount)),
              const Divider(height: 16),
              _buildDetailRow(isEn ? 'Date' : 'Tanggal', tx.date.length >= 10 ? tx.date.substring(0, 10) : tx.date),
              const Divider(height: 16),
              _buildDetailRow(
                isEn ? 'Note / Description' : 'Keterangan / Catatan', 
                (tx.note != null && tx.note!.isNotEmpty) ? tx.note! : (isEn ? 'No additional notes' : 'Tidak ada keterangan tambahan'), 
                isItalic: tx.note == null || tx.note!.isEmpty,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                if (tx.id != null) _deleteTransaction(tx.id!, tx.title);
              },
              child: Text(isEn ? 'Delete' : 'Hapus', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            ),
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Close' : 'Tutup', style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1A237E)))),
          ],
        );
      },
    );
  }

  Widget _buildDetailRow(String label, String value, {bool isItalic = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: const Color(0xFF0F172A), fontStyle: isItalic ? FontStyle.italic : FontStyle.normal)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.languageCode == 'en';
    final currencyFormatter = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
    final monthsMap = _getMonthsMap(isEn);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(isEn ? 'Mutation List' : 'Daftar Mutasi', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), tooltip: isEn ? 'Reset Filter' : 'Reset Filter', onPressed: _resetFilter),
        ],
      ),
      body: Stack(
        children: [
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
              : Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))]),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            controller: _searchController,
                            onChanged: (val) => _applyFilter(),
                            decoration: InputDecoration(
                              hintText: isEn ? 'Search item, group, or note...' : 'Cari Item, Group, atau Keterangan...',
                              hintStyle: TextStyle(fontSize: 12, color: Colors.grey.shade400),
                              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF1A237E)),
                              suffixIcon: _searchController.text.isNotEmpty
                                  ? IconButton(
                                      icon: const Icon(Icons.clear_rounded, size: 18),
                                      onPressed: () {
                                        _searchController.clear();
                                        _applyFilter();
                                      },
                                    )
                                  : null,
                              isDense: true,
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedYear,
                                  decoration: InputDecoration(labelText: isEn ? 'Year' : 'Tahun', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                                  items: _yearsList.map((y) => DropdownMenuItem(value: y, child: Text(y == 'Semua' ? (isEn ? 'All' : 'Semua') : y, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedYear = val);
                                      _applyFilter();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedMonth,
                                  decoration: InputDecoration(labelText: isEn ? 'Month' : 'Bulan', isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50),
                                  items: monthsMap.entries.map((entry) => DropdownMenuItem(value: entry.key, child: Text(entry.value, style: const TextStyle(fontSize: 13)))).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMonth = val);
                                      _applyFilter();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 4,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 13, horizontal: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    side: BorderSide(color: Colors.grey.shade300),
                                    backgroundColor: Colors.grey.shade50,
                                  ),
                                  onPressed: () => _pickDateRange(context),
                                  child: Text(
                                    _startDate == null || _endDate == null ? (isEn ? 'Period' : 'Periode') : '${DateFormat('dd/MM').format(_startDate!)} - ${DateFormat('dd/MM').format(_endDate!)}',
                                    style: const TextStyle(fontSize: 11, color: Color(0xFF0F172A), fontWeight: FontWeight.bold),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          if (_startDate != null && _endDate != null)
                            SizedBox(
                              height: 36,
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red.shade700,
                                  side: BorderSide(color: Colors.red.shade200),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                ),
                                onPressed: () {
                                  setState(() { _startDate = null; _endDate = null; });
                                  _applyFilter();
                                },
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                label: Text(isEn ? 'Clear Date Range Filter' : 'Hapus Filter Rentang Tanggal', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(isEn ? 'Mutation Results (${_filteredTransactions.length} Transactions)' : 'Hasil Mutasi (${_filteredTransactions.length} Transaksi)', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey.shade600)),
                          if (_startDate != null && _endDate != null)
                            Text(isEn ? 'Active Period' : 'Periode Aktif', style: TextStyle(fontSize: 11, color: Colors.indigo.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _filteredTransactions.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.receipt_long_outlined, size: 48, color: Colors.grey.shade400),
                                  const SizedBox(height: 12),
                                  Text(isEn ? 'No mutations found for this filter' : 'Tidak ada mutasi pada filter ini', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                                ],
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              itemCount: _filteredTransactions.length,
                              itemBuilder: (ctx, index) {
                                final tx = _filteredTransactions[index];
                                final cat = _categories.firstWhere(
                                  (c) => c.id == tx.categoryId,
                                  orElse: () => model.Category(id: 0, name: isEn ? 'Others' : 'Lainnya', type: model.TransactionType.expense),
                                );
                                final isIncome = cat.type == model.TransactionType.income;
                                final iconDetails = _getItemIconDetails(tx);

                                return Dismissible(
                                  key: Key(tx.id.toString()),
                                  direction: DismissDirection.endToStart,
                                  background: Container(
                                    margin: const EdgeInsets.only(bottom: 10),
                                    padding: const EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.red.shade600,
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    alignment: Alignment.centerRight,
                                    child: const Icon(Icons.delete_rounded, color: Colors.white, size: 22),
                                  ),
                                  confirmDismiss: (direction) async {
                                    bool? confirm = await showDialog(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                        title: Text(isEn ? 'Delete Transaction' : 'Hapus Transaksi', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                                        content: Text(isEn ? 'Are you sure you want to delete "${tx.title}"?' : 'Yakin ingin menghapus transaksi "${tx.title}"?'),
                                        actions: [
                                          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(isEn ? 'Cancel' : 'Batal', style: const TextStyle(color: Colors.grey))),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                                            onPressed: () => Navigator.pop(context, true),
                                            child: Text(isEn ? 'Delete' : 'Hapus'),
                                          ),
                                        ],
                                      ),
                                    );
                                    return confirm ?? false;
                                  },
                                  onDismissed: (direction) async {
                                    if (tx.id != null) {
                                      await _executeDeleteTransaction(tx.id!);
                                    }
                                  },
                                  child: Material(
                                    color: Colors.transparent,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(color: Colors.grey.shade100),
                                        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2))],
                                      ),
                                      child: ListTile(
                                        onTap: () => _showTransactionDetail(tx),
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                        leading: Container(
                                          padding: const EdgeInsets.all(10),
                                          decoration: BoxDecoration(
                                            color: iconDetails['bg'], 
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            iconDetails['iconData'], 
                                            color: iconDetails['fg'], 
                                            size: 20,
                                          ),
                                        ),
                                        title: Text(tx.title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF0F172A))),
                                        subtitle: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            const SizedBox(height: 3),
                                            Row(
                                              children: [
                                                Text(cat.name, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.indigo.shade700)),
                                                const Text(' • ', style: TextStyle(color: Colors.grey)),
                                                Text(tx.date.length >= 10 ? tx.date.substring(0, 10) : tx.date, style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
                                              ],
                                            ),
                                            if (tx.note != null && tx.note!.isNotEmpty) ...[
                                              const SizedBox(height: 2),
                                              Text('"${tx.note}"', style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Colors.grey.shade600)),
                                            ],
                                          ],
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              '${isIncome ? "+ " : "- "}${currencyFormatter.format(tx.amount)}',
                                              style: TextStyle(color: isIncome ? Colors.green.shade700 : Colors.red.shade700, fontWeight: FontWeight.bold, fontSize: 13),
                                            ),
                                            const SizedBox(width: 4),
                                            IconButton(
                                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.grey),
                                              onPressed: () {
                                                if (tx.id != null) _deleteTransaction(tx.id!, tx.title);
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
                  ],
                ),
          if (_isActionLoading)
            Container(
              color: Colors.black.withOpacity(0.3),
              child: const Center(
                child: CircularProgressIndicator(
                  color: Color(0xFF1A237E),
                ),
              ),
            ),
        ],
      ),
    );
  }
}