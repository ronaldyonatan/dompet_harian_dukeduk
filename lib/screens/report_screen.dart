import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../helpers/database_helper.dart';
import '../helpers/localization_helper.dart';
import '../helpers/loading_helper.dart'; // Import LoadingHelper global
import '../models/finance_model.dart' as model;

class ReportScreen extends StatefulWidget {
  final String languageCode;
  final String? appLogo; // <-- Parameter Logo Perusahaan / Aplikasi

  const ReportScreen({
    super.key,
    required this.languageCode,
    this.appLogo,
  });

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  List<model.TransactionModel> _allTransactions = [];
  List<model.TransactionModel> _filteredTransactions = [];
  List<model.Category> _categories = [];
  List<model.ItemModel> _items = [];
  bool _isLoading = true;

  late String _selectedMonth;
  late String _selectedYear;
  List<String> _availableYears = [];
  String _reportMode = 'group'; // 'group' atau 'detail'
  String _periodMode = 'month'; // 'month' atau 'ytd'

  Map<String, String> _getMonthsMap(bool isEn) {
    return {
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

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedMonth = DateFormat('MM').format(now);
    _selectedYear = DateFormat('yyyy').format(now);
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    final txs = await DatabaseHelper.instance.getTransactions();
    final cats = await DatabaseHelper.instance.getCategories();
    final its = await DatabaseHelper.instance.getItems();
    
    Set<String> yearsSet = {DateFormat('yyyy').format(DateTime.now())};
    for (var tx in txs) {
      if (tx.date.length >= 4) yearsSet.add(tx.date.substring(0, 4));
    }
    List<String> sortedYears = yearsSet.toList()..sort((a, b) => b.compareTo(a));

    setState(() {
      _allTransactions = txs;
      _categories = cats;
      _items = its;
      _availableYears = sortedYears;
      _isLoading = false;
    });
    _applyFilter();
  }

  void _applyFilter() {
    setState(() {
      _filteredTransactions = _allTransactions.where((tx) {
        final txYear = tx.date.substring(0, 4);
        final txMonth = tx.date.substring(5, 7);

        if (txYear != _selectedYear) return false;

        if (_periodMode == 'month') {
          return txMonth == _selectedMonth;
        } else {
          return int.parse(txMonth) <= int.parse(_selectedMonth);
        }
      }).toList();
    });
  }

  double get _totalIncome {
    return _filteredTransactions.fold(0.0, (sum, tx) {
      final cat = _categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => model.Category(id: 0, name: '', type: model.TransactionType.expense));
      return cat.type == model.TransactionType.income ? sum + tx.amount : sum;
    });
  }

  double get _totalExpense {
    return _filteredTransactions.fold(0.0, (sum, tx) {
      final cat = _categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => model.Category(id: 0, name: '', type: model.TransactionType.expense));
      return cat.type == model.TransactionType.expense ? sum + tx.amount : sum;
    });
  }

  double get _netProfit => _totalIncome - _totalExpense;

  Map<model.Category, double> _getGroupedData(model.TransactionType type) {
    final isEn = widget.languageCode == 'en';
    Map<model.Category, double> result = {};
    for (var tx in _filteredTransactions) {
      final cat = _categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => model.Category(id: 0, name: isEn ? 'Others' : 'Lainnya', type: type));
      if (cat.type == type) result[cat] = (result[cat] ?? 0.0) + tx.amount;
    }
    return result;
  }

  Map<model.ItemModel, double> _getDetailItemData(model.TransactionType type) {
    Map<model.ItemModel, double> result = {};
    for (var tx in _filteredTransactions) {
      final cat = _categories.firstWhere((c) => c.id == tx.categoryId, orElse: () => model.Category(id: 0, name: '', type: type));
      if (cat.type == type) {
        final item = _items.firstWhere((i) => i.id == tx.itemId, orElse: () => model.ItemModel(id: 0, name: tx.title, categoryId: cat.id ?? 0));
        result[item] = (result[item] ?? 0.0) + tx.amount;
      }
    }
    return result;
  }

  // ==================== FUNGSI EXPORT KE PDF ====================
  Future<void> _generatePdfReport() async {
    final isEn = widget.languageCode == 'en';
    
    // Tampilkan Loading Panel Global saat menyusun dokumen PDF
    LoadingHelper.show(context, message: isEn ? 'Generating PDF report...' : 'Menyiapkan laporan PDF...');

    try {
      final pdf = pw.Document();
      final currencyFormat = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
      final monthsMap = _getMonthsMap(isEn);

      final incomeGroup = _getGroupedData(model.TransactionType.income);
      final expenseGroup = _getGroupedData(model.TransactionType.expense);
      final incomeDetail = _getDetailItemData(model.TransactionType.income);
      final expenseDetail = _getDetailItemData(model.TransactionType.expense);

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.all(32),
          build: (pw.Context context) {
            return [
              // Header Laporan
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text('DOMPET HARIAN DUKEDUK', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700)),
                      pw.SizedBox(height: 2),
                      pw.Text(isEn ? 'COMPREHENSIVE INCOME STATEMENT' : 'LAPORAN LABA RUGI KOMPREHENSIF', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF1A237E))),
                    ],
                  ),
                  pw.Text(
                    '${isEn ? 'Period' : 'Periode'}: ${_periodMode == 'ytd' ? 'YTD ' : ''}${monthsMap[_selectedMonth]} $_selectedYear',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                  ),
                ],
              ),
              pw.Divider(thickness: 1.5, color: PdfColor.fromInt(0xFF1A237E)),
              pw.SizedBox(height: 10),

              // Bagian Pendapatan (Revenue)
              pw.Text(isEn ? 'REVENUE' : 'PENDAPATAN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headers: [_reportMode == 'group' ? (isEn ? 'Category' : 'Kategori') : 'Item', isEn ? 'Amount' : 'Jumlah'],
                data: _reportMode == 'group'
                    ? incomeGroup.entries.map((e) => [e.key.name, currencyFormat.format(e.value)]).toList()
                    : incomeDetail.entries.map((e) => [e.key.name, currencyFormat.format(e.value)]).toList(),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.green700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('${isEn ? 'Total Revenue' : 'Total Pendapatan'}: ${currencyFormat.format(_totalIncome)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.green900)),
              ),
              pw.SizedBox(height: 14),

              // Bagian Beban (Expense)
              pw.Text(isEn ? 'EXPENSES' : 'BEBAN / PENGELUARAN', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: PdfColors.red800)),
              pw.SizedBox(height: 6),
              pw.Table.fromTextArray(
                headers: [_reportMode == 'group' ? (isEn ? 'Category' : 'Kategori') : 'Item', isEn ? 'Amount' : 'Jumlah'],
                data: _reportMode == 'group'
                    ? expenseGroup.entries.map((e) => [e.key.name, currencyFormat.format(e.value)]).toList()
                    : expenseDetail.entries.map((e) => [e.key.name, currencyFormat.format(e.value)]).toList(),
                headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.red700),
                cellStyle: const pw.TextStyle(fontSize: 10),
                cellAlignment: pw.Alignment.centerLeft,
                cellPadding: const pw.EdgeInsets.all(6),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                alignment: pw.Alignment.centerRight,
                padding: const pw.EdgeInsets.all(6),
                child: pw.Text('${isEn ? 'Total Expenses' : 'Total Beban'}: ${currencyFormat.format(_totalExpense)}', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.red900)),
              ),
              pw.SizedBox(height: 20),

              // Laba Rugi Bersih
              pw.Container(
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: _netProfit >= 0 ? PdfColors.green : PdfColors.red, width: 1.5),
                  borderRadius: const pw.BorderRadius.all(pw.Radius.circular(8)),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(isEn ? 'NET PROFIT / LOSS' : 'LABA / RUGI BERSIH', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                    pw.Text(
                      currencyFormat.format(_netProfit),
                      style: pw.TextStyle(
                        fontSize: 12,
                        fontWeight: pw.FontWeight.bold,
                        color: _netProfit >= 0 ? PdfColors.green800 : PdfColors.red800,
                      ),
                    ),
                  ],
                ),
              ),
            ];
          },
        ),
      );

      // Sembunyikan loading sebelum memanggil dialog cetak/layout PDF
      if (!mounted) return;
      LoadingHelper.hide(context);

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => pdf.save(),
        name: 'Income_Statement_${_selectedMonth}_${_selectedYear}.pdf',
      );
    } catch (e) {
      if (!mounted) return;
      LoadingHelper.hide(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat PDF: $e'), backgroundColor: Colors.red),
      );
    }
  }

  void _showCategoryDrillDown(model.Category category) {
    final isEn = widget.languageCode == 'en';
    final currencyFormatter = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
    Map<String, double> itemTotals = {};
    for (var tx in _filteredTransactions.where((t) => t.categoryId == category.id)) {
      itemTotals[tx.title] = (itemTotals[tx.title] ?? 0.0) + tx.amount;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${isEn ? 'Item Details' : 'Rincian Item'}: ${category.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: itemTotals.isEmpty
              ? Text(isEn ? 'No item details.' : 'Tidak ada rincian item.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: itemTotals.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final entry = itemTotals.entries.elementAt(index);
                    return ListTile(
                      title: Text(entry.key, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                      trailing: Text(currencyFormatter.format(entry.value), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Close' : 'Tutup')),
        ],
      ),
    );
  }

  void _showItemTransactionsDrillDown(model.ItemModel item) {
    final isEn = widget.languageCode == 'en';
    final currencyFormatter = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
    final txs = _filteredTransactions.where((t) => t.itemId == item.id || t.title == item.name).toList();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('${isEn ? 'Item Mutations' : 'Mutasi Item'}: ${item.name}', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: double.maxFinite,
          child: txs.isEmpty
              ? Text(isEn ? 'No transaction mutations for this item.' : 'Tidak ada mutasi transaksi untuk item ini.')
              : ListView.separated(
                  shrinkWrap: true,
                  itemCount: txs.length,
                  separatorBuilder: (_, __) => const Divider(),
                  itemBuilder: (_, index) {
                    final tx = txs[index];
                    return ListTile(
                      dense: true,
                      title: Text(tx.date.substring(0, 10), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                      subtitle: tx.note != null && tx.note!.isNotEmpty ? Text('"${tx.note}"', style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic)) : null,
                      trailing: Text(currencyFormatter.format(tx.amount), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A237E))),
                    );
                  },
                ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(isEn ? 'Close' : 'Tutup')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.languageCode == 'en';
    final t = AppLocalizations(widget.languageCode);
    final currencyFormatter = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
    final monthsMap = _getMonthsMap(isEn);

    final incomeGroup = _getGroupedData(model.TransactionType.income);
    final expenseGroup = _getGroupedData(model.TransactionType.expense);
    final incomeDetail = _getDetailItemData(model.TransactionType.income);
    final expenseDetail = _getDetailItemData(model.TransactionType.expense);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(t.translate('report'), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_rounded),
            tooltip: isEn ? 'Export to PDF' : 'Export ke PDF',
            onPressed: _generatePdfReport,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.white,
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: DropdownButtonFormField<String>(
                              value: _selectedYear,
                              decoration: InputDecoration(labelText: t.translate('select_year'), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              items: _availableYears.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                              onChanged: (val) { if (val != null) setState(() => _selectedYear = val); },
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 3,
                            child: DropdownButtonFormField<String>(
                              value: _selectedMonth,
                              decoration: InputDecoration(labelText: t.translate('select_month'), isDense: true, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                              items: monthsMap.entries.map((e) => DropdownMenuItem(value: e.key, child: Text(e.value))).toList(),
                              onChanged: (val) { if (val != null) setState(() => _selectedMonth = val); },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<String>(
                          segments: [
                            ButtonSegment(value: 'month', label: Text(t.translate('current_month'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                            ButtonSegment(value: 'ytd', label: Text(t.translate('ytd'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                          ],
                          selected: {_periodMode},
                          onSelectionChanged: (val) => setState(() => _periodMode = val.first),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 40,
                              child: SegmentedButton<String>(
                                segments: [
                                  ButtonSegment(value: 'group', label: Text(isEn ? 'Group' : 'Group', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                  ButtonSegment(value: 'detail', label: Text(isEn ? 'Detail' : 'Detail', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
                                ],
                                selected: {_reportMode},
                                onSelectionChanged: (val) => setState(() => _reportMode = val.first),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            height: 40,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF1A237E),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                              onPressed: _applyFilter,
                              child: const Icon(Icons.refresh_rounded, size: 20),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: const Color(0xFF1A237E), borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            children: [
                              Container(
                                width: 44,
                                height: 44,
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                  image: widget.appLogo != null && widget.appLogo!.isNotEmpty
                                      ? DecorationImage(
                                          image: (kIsWeb ? NetworkImage(widget.appLogo!) : FileImage(File(widget.appLogo!)) as ImageProvider),
                                          fit: BoxFit.cover,
                                        )
                                      : null,
                                ),
                                child: widget.appLogo == null || widget.appLogo!.isEmpty
                                    ? const Icon(Icons.business_rounded, color: Colors.white, size: 22)
                                    : null,
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('DOMPET HARIAN DUKEDUK', style: TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text(t.translate('income_statement'), style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 2),
                                    Text('${_periodMode == 'ytd' ? 'YTD ' : ''}${monthsMap[_selectedMonth]} $_selectedYear', style: TextStyle(color: Colors.cyan.shade200, fontSize: 11)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(t.translate('revenue'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green.shade800)),
                        const SizedBox(height: 6),
                        _reportMode == 'group'
                            ? _buildGroupTableCategory(incomeGroup, Colors.green.shade700)
                            : _buildDetailTableItem(incomeDetail, Colors.green.shade700),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isEn ? 'Total Revenue' : 'Total Pendapatan', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(currencyFormatter.format(_totalIncome), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.green.shade800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(t.translate('expense'), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red.shade800)),
                        const SizedBox(height: 6),
                        _reportMode == 'group'
                            ? _buildGroupTableCategory(expenseGroup, Colors.red.shade700)
                            : _buildDetailTableItem(expenseDetail, Colors.red.shade700),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                          decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(isEn ? 'Total Expenses' : 'Total Beban', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                              Text(currencyFormatter.format(_totalExpense), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.red.shade800)),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _netProfit >= 0 ? Colors.green.shade300 : Colors.red.shade300, width: 1.5),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(t.translate('net_profit'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                              Text(currencyFormatter.format(_netProfit), style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: _netProfit >= 0 ? Colors.green.shade700 : Colors.red.shade700)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildGroupTableCategory(Map<model.Category, double> data, Color amountColor) {
    final isEn = widget.languageCode == 'en';
    final currencyFormatter = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
    if (data.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text(isEn ? 'No data' : 'Tidak ada data', style: const TextStyle(fontSize: 11, color: Colors.grey)));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final entry = data.entries.elementAt(index);
          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              onTap: () => _showCategoryDrillDown(entry.key),
              title: Text(entry.key.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currencyFormatter.format(entry.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: amountColor)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailTableItem(Map<model.ItemModel, double> data, Color amountColor) {
    final isEn = widget.languageCode == 'en';
    final currencyFormatter = NumberFormat.currency(locale: isEn ? 'en_US' : 'id_ID', symbol: isEn ? '\$ ' : 'Rp ', decimalDigits: 0);
    if (data.isEmpty) return Padding(padding: const EdgeInsets.all(8), child: Text(isEn ? 'No data' : 'Tidak ada data', style: const TextStyle(fontSize: 11, color: Colors.grey)));

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.grey.shade200)),
      child: ListView.separated(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: data.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, index) {
          final entry = data.entries.elementAt(index);
          return Material(
            color: Colors.transparent,
            child: ListTile(
              dense: true,
              onTap: () => _showItemTransactionsDrillDown(entry.key),
              title: Text(entry.key.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(currencyFormatter.format(entry.value), style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: amountColor)),
                  const SizedBox(width: 4),
                  const Icon(Icons.chevron_right_rounded, size: 16, color: Colors.grey),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}