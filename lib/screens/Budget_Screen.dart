import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/finance_model.dart' as model;
import '../helpers/currency_formatter_helper.dart';
// Pastikan path import AppLocalizations ini sesuai dengan struktur project Anda
import '../helpers/localization_helper.dart'; 
// Import LoadingHelper global Anda
import '../helpers/loading_helper.dart';

class BudgetScreen extends StatefulWidget {
  final String currentLanguage; // Menerima kode bahasa aktif ('id' atau 'en')

  const BudgetScreen({super.key, required this.currentLanguage});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  bool _isLoading = true;
  int _selectedYear = DateTime.now().year;
  int _selectedMonth = DateTime.now().month;

  List<model.Category> _categories = [];
  List<model.BudgetModel> _existingBudgets = [];
  
  final _amountController = TextEditingController();
  model.Category? _selectedCategoryForInput;

  final _searchController = TextEditingController();
  String _searchQuery = '';

  // Helper untuk daftar bulan berdasarkan bahasa aktif
  List<String> get _months {
    if (widget.currentLanguage == 'en') {
      return ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    }
    return ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
  }

  @override
  void initState() {
    super.initState();
    _loadBudgetDataFirstTime();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // Pemuatan data pertama kali menggunakan indikator loading lokal halaman
  Future<void> _loadBudgetDataFirstTime() async {
    setState(() => _isLoading = true);
    await _fetchBudgetDataLogic();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  // Pemuatan data saat filter bulan/tahun diubah menggunakan LoadingHelper global
  Future<void> _loadBudgetDataWithDialog() async {
    final loc = AppLocalizations(widget.currentLanguage);
    LoadingHelper.show(context, message: loc.translate('loading_data') ?? 'Memuat data...');
    
    await _fetchBudgetDataLogic();
    
    if (mounted) {
      LoadingHelper.hide(context);
    }
  }

  // Logika utama pengambilan data dari database
  Future<void> _fetchBudgetDataLogic() async {
    final cats = await DatabaseHelper.instance.getCategories();
    final expenseCategories = cats.where((c) => c.type == model.TransactionType.expense && c.isActive).toList();
    final budgets = await DatabaseHelper.instance.getBudgetsByPeriod(_selectedYear, _selectedMonth);

    if (mounted) {
      setState(() {
        _categories = expenseCategories;
        _existingBudgets = budgets;
        if (_categories.isNotEmpty && (_selectedCategoryForInput == null || !_categories.contains(_selectedCategoryForInput))) {
          _selectedCategoryForInput = _categories.first;
        }
      });
    }
  }

  Future<void> _saveBudget() async {
    final loc = AppLocalizations(widget.currentLanguage);
    final amountText = _amountController.text.trim();
    if (amountText.isEmpty || _selectedCategoryForInput == null) return;

    final cleanAmountText = amountText.replaceAll('.', '');
    final double? amount = double.tryParse(cleanAmountText);
    if (amount == null) return;

    LoadingHelper.show(context, message: loc.translate('saving_budget') ?? 'Menyimpan anggaran...');

    await DatabaseHelper.instance.upsertBudget(model.BudgetModel(
      categoryId: _selectedCategoryForInput!.id!,
      year: _selectedYear,
      month: _selectedMonth,
      amount: amount,
    ));

    _amountController.clear();
    await _fetchBudgetDataLogic();

    if (!mounted) return;
    
    LoadingHelper.hide(context);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(loc.translate('budget_saved_success') ?? 'Anggaran berhasil disimpan'), backgroundColor: Colors.green),
    );
  }

  Future<void> _deleteBudget(model.BudgetModel budget, String categoryName) async {
    final loc = AppLocalizations(widget.currentLanguage);

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(loc.translate('delete_budget_title') ?? 'Hapus Anggaran', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        content: Text('${loc.translate('delete_budget_confirmation') ?? 'Apakah Anda yakin ingin menghapus anggaran untuk kategori'} "$categoryName"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.translate('cancel') ?? 'Batal'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: Text(loc.translate('delete') ?? 'Hapus'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      if (!mounted) return;
      LoadingHelper.show(context, message: loc.translate('deleting_budget') ?? 'Menghapus anggaran...');

      // Memanggil method deleteBudget dengan categoryId, year, dan month
      await DatabaseHelper.instance.deleteBudget(
        budget.categoryId, 
        budget.year, 
        budget.month,
      ); 

      await _fetchBudgetDataLogic();

      if (!mounted) return;
      LoadingHelper.hide(context);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('budget_deleted_success') ?? 'Anggaran berhasil dihapus'), 
          backgroundColor: Colors.red.shade700,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations(widget.currentLanguage);

    final existingCategoryIds = _existingBudgets.map((b) => b.categoryId).toSet();
    final unassignedCategories = _categories.where((c) => !existingCategoryIds.contains(c.id)).toList();
    final assignedBudgetsMap = { for (var b in _existingBudgets) b.categoryId: b };

    final filteredCategories = _categories.where((cat) {
      return cat.name.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF8FAFC),
        appBar: AppBar(
          title: Text(loc.translate('manage_budget'), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
          backgroundColor: const Color(0xFF1A237E),
          foregroundColor: Colors.white,
          elevation: 0,
          bottom: TabBar(
            indicatorColor: Colors.amber,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white60,
            labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            tabs: [
              Tab(
                icon: const Icon(Icons.edit_note_rounded, size: 18),
                text: loc.translate('set_budget_amount'),
              ),
              Tab(
                icon: const Icon(Icons.list_alt_rounded, size: 18),
                text: loc.translate('monthly_budget_list'),
              ),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
            : TabBarView(
                children: [
                  // --- TAB 1: FORM ATUR ANGGARAN & PERIODE ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Filter Tahun & Bulan
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _selectedMonth,
                                  decoration: InputDecoration(
                                    labelText: loc.translate('select_month'),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: List.generate(12, (index) {
                                    return DropdownMenuItem(value: index + 1, child: Text(_months[index], style: const TextStyle(fontSize: 13)));
                                  }),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedMonth = val);
                                      _loadBudgetDataWithDialog();
                                    }
                                  },
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: DropdownButtonFormField<int>(
                                  value: _selectedYear,
                                  decoration: InputDecoration(
                                    labelText: loc.translate('select_year'),
                                    isDense: true,
                                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                                  ),
                                  items: [2025, 2026, 2027].map((year) {
                                    return DropdownMenuItem(value: year, child: Text('$year', style: const TextStyle(fontSize: 13)));
                                  }).toList(),
                                  onChanged: (val) {
                                    if (val != null) {
                                      setState(() => _selectedYear = val);
                                      _loadBudgetDataWithDialog();
                                    }
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Informasi Kategori Belum Ada Anggaran
                        if (unassignedCategories.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.info_outline_rounded, size: 18, color: Colors.amber.shade800),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        '${unassignedCategories.length} ${loc.translate('unassigned_categories')}',
                                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber.shade900),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: unassignedCategories.map((cat) {
                                    return ActionChip(
                                      label: Text(cat.name, style: const TextStyle(fontSize: 11)),
                                      backgroundColor: Colors.white,
                                      onPressed: () {
                                        setState(() {
                                          _selectedCategoryForInput = cat;
                                        });
                                      },
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ),
                        if (unassignedCategories.isNotEmpty) const SizedBox(height: 16),

                        // Form Input / Edit Anggaran
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Text(loc.translate('set_budget_amount'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<model.Category>(
                                value: _selectedCategoryForInput,
                                decoration: InputDecoration(
                                  labelText: loc.translate('select_category'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                ),
                                items: _categories.map((cat) {
                                  final bool hasBudget = existingCategoryIds.contains(cat.id);
                                  return DropdownMenuItem(
                                    value: cat, 
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(cat.name, style: const TextStyle(fontSize: 13)),
                                        if (!hasBudget) 
                                          Text(loc.translate('not_yet'), style: const TextStyle(fontSize: 10, color: Colors.orange))
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (val) => setState(() => _selectedCategoryForInput = val),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _amountController,
                                keyboardType: TextInputType.number,
                                inputFormatters: [CurrencyInputFormatter()],
                                decoration: InputDecoration(
                                  labelText: loc.translate('budget_amount_hint'),
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                  filled: true,
                                  fillColor: Colors.grey.shade50,
                                  prefixText: 'Rp ',
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF1A237E),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 12),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                onPressed: _saveBudget,
                                child: Text(loc.translate('save_update_budget'), style: const TextStyle(fontWeight: FontWeight.bold)),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // --- TAB 2: DAFTAR & MONITORING ANGGARAN ---
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchController,
                          decoration: InputDecoration(
                            labelText: loc.translate('search_budget_category'),
                            prefixIcon: const Icon(Icons.search, color: Color(0xFF1A237E)),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.white,
                            isDense: true,
                            suffixIcon: _searchQuery.isNotEmpty
                                ? IconButton(
                                    icon: const Icon(Icons.clear, size: 18),
                                    onPressed: () {
                                      setState(() {
                                        _searchController.clear();
                                        _searchQuery = '';
                                      });
                                    },
                                  )
                                : null,
                          ),
                          onChanged: (value) {
                            setState(() {
                              _searchQuery = value;
                            });
                          },
                        ),
                        const SizedBox(height: 16),
                        Text(loc.translate('monthly_budget_list'), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))),
                        const SizedBox(height: 10),
                        filteredCategories.isEmpty
                            ? Padding(
                                padding: const EdgeInsets.symmetric(vertical: 32.0),
                                child: Center(
                                  child: Text(loc.translate('no_category_found'), style: const TextStyle(color: Colors.grey)),
                                ),
                              )
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: filteredCategories.length,
                                itemBuilder: (context, index) {
                                  final cat = filteredCategories[index];
                                  final budget = assignedBudgetsMap[cat.id];
                                  final isSet = budget != null;

                                  return Container(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: isSet ? Colors.indigo.shade100 : Colors.grey.shade200),
                                    ),
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(cat.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Color(0xFF0F172A))),
                                              const SizedBox(height: 2),
                                              Text(
                                                isSet ? loc.translate('active_budget') : loc.translate('not_set'),
                                                style: TextStyle(fontSize: 11, color: isSet ? Colors.green.shade700 : Colors.orange.shade800, fontWeight: FontWeight.w500),
                                              ),
                                            ],
                                          ),
                                        ),
                                        Row(
                                          children: [
                                            Text(
                                              isSet ? 'Rp ${formatCurrency(budget.amount)}' : '-',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 14, 
                                                color: isSet ? const Color(0xFF1A237E) : Colors.grey.shade400,
                                              ),
                                            ),
                                            if (isSet) ...[
                                              const SizedBox(width: 8),
                                              IconButton(
                                                icon: const Icon(Icons.delete_outline_rounded, color: Colors.red, size: 20),
                                                constraints: const BoxConstraints(),
                                                padding: EdgeInsets.zero,
                                                onPressed: () => _deleteBudget(budget, cat.name),
                                                tooltip: loc.translate('delete') ?? 'Hapus',
                                              ),
                                            ],
                                          ],
                                        ),
                                      ],
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
}