import '../helpers/profile_image.dart';
import '../constants/app_icons.dart';

import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../helpers/database_helper.dart';
import '../models/finance_model.dart' as model;
import '../helpers/localization_helper.dart';
import 'calendar_schedule_screen.dart'; // Ditambahkan: Impor layar kalender tagihan

class DashboardScreen extends StatefulWidget {
  final String userName;
  final String languageCode;
  final String? appLogo;

  const DashboardScreen({
    super.key,
    required this.userName,
    required this.languageCode,
    this.appLogo,
  });

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  List<model.TransactionModel> _transactions = [];
  List<model.Category> _categories = [];
  List<model.ItemModel> _items = [];
  List<model.BudgetModel> _budgets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      final results = await Future.wait([
        DatabaseHelper.instance.getTransactions(),
        DatabaseHelper.instance.getCategories(),
        DatabaseHelper.instance.getItems(),
        DatabaseHelper.instance.getBudgets(),
      ]);

      if (!mounted) return;

      setState(() {
        _transactions = results[0] as List<model.TransactionModel>;
        _categories = results[1] as List<model.Category>;
        _items = results[2] as List<model.ItemModel>;
        _budgets = results[3] as List<model.BudgetModel>;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Gagal memuat data: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Widget _buildAppLogoWidget(String? logoPath) {
    final provider = profileImage(logoPath);
    return provider == null
        ? const Icon(
            Icons.account_balance_wallet,
            color: Colors.white,
            size: 28,
          )
        : Image(
            image: provider,
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) =>
                const Icon(Icons.account_balance_wallet, color: Colors.white),
          );
  }

  Widget? _renderIconContent(
    dynamic iconSource,
    bool isIncome,
    Widget defaultWidget,
  ) {
    if (iconSource == null) return null;

    if (iconSource is IconData) {
      return Icon(
        iconSource,
        color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
        size: 20,
      );
    }

    if (iconSource is int) {
      return Icon(
        AppIcons.fromCodePoint(iconSource),
        color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
        size: 20,
      );
    }

    if (iconSource is String) {
      final cleanPath = iconSource.trim();
      if (cleanPath.isEmpty) return null;

      final parsedInt = int.tryParse(cleanPath);
      if (parsedInt != null) {
        return Icon(
          AppIcons.fromCodePoint(parsedInt),
          color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
          size: 20,
        );
      }

      try {
        if (cleanPath.startsWith('http://') ||
            cleanPath.startsWith('https://')) {
          return Image.network(
            cleanPath,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => defaultWidget,
          );
        } else if (cleanPath.startsWith('assets/')) {
          return Image.asset(
            cleanPath,
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => defaultWidget,
          );
        } else if (!kIsWeb) {
          return Image.file(
            File(cleanPath),
            width: 42,
            height: 42,
            fit: BoxFit.cover,
            errorBuilder: (_, _, _) => defaultWidget,
          );
        }
      } catch (_) {}
    }

    return null;
  }

  Widget _buildTransactionItemIcon(model.TransactionModel tx, bool isIncome) {
    model.ItemModel? matchedItem;
    if (tx.itemId != null) {
      try {
        matchedItem = _items.firstWhere((i) => i.id == tx.itemId);
      } catch (_) {}
    }

    if (matchedItem == null) {
      try {
        matchedItem = _items.firstWhere(
          (i) => i.name.toLowerCase() == tx.title.toLowerCase(),
        );
      } catch (_) {}
    }

    model.Category? matchedCategory;
    try {
      matchedCategory = _categories.firstWhere((c) => c.id == tx.categoryId);
    } catch (_) {}

    dynamic iconDataRaw;
    if (matchedItem != null) {
      try {
        final dynamic dyn = matchedItem;
        iconDataRaw = dyn.iconPath ?? dyn.imagePath ?? dyn.icon ?? dyn.iconCode;
      } catch (_) {}
    }

    if (iconDataRaw == null && matchedCategory != null) {
      try {
        final dynamic dyn = matchedCategory;
        iconDataRaw = dyn.iconPath ?? dyn.imagePath ?? dyn.icon ?? dyn.iconCode;
      } catch (_) {}
    }

    final Icon defaultArrowIcon = Icon(
      isIncome ? Icons.arrow_downward_rounded : Icons.arrow_upward_rounded,
      color: isIncome ? Colors.green.shade700 : Colors.red.shade700,
      size: 20,
    );

    final Widget? customIconWidget = _renderIconContent(
      iconDataRaw,
      isIncome,
      defaultArrowIcon,
    );

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: isIncome ? Colors.green.shade50 : Colors.red.shade50,
        shape: BoxShape.circle,
        border: Border.all(
          color: isIncome ? Colors.green.shade300 : Colors.red.shade300,
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(21),
        child: Center(child: customIconWidget ?? defaultArrowIcon),
      ),
    );
  }

  double get _currentMonthIncome {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    return _transactions.where((tx) => tx.date.startsWith(currentMonth)).fold(
      0.0,
      (sum, tx) {
        final cat = _categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => model.Category(
            id: 0,
            name: '',
            type: model.TransactionType.expense,
          ),
        );
        return cat.type == model.TransactionType.income ? sum + tx.amount : sum;
      },
    );
  }

  double get _currentMonthExpense {
    final currentMonth = DateFormat('yyyy-MM').format(DateTime.now());
    return _transactions.where((tx) => tx.date.startsWith(currentMonth)).fold(
      0.0,
      (sum, tx) {
        final cat = _categories.firstWhere(
          (c) => c.id == tx.categoryId,
          orElse: () => model.Category(
            id: 0,
            name: '',
            type: model.TransactionType.expense,
          ),
        );
        return cat.type == model.TransactionType.expense
            ? sum + tx.amount
            : sum;
      },
    );
  }

  double get _totalIncome {
    return _transactions.fold(0.0, (sum, item) {
      final cat = _categories.firstWhere(
        (c) => c.id == item.categoryId,
        orElse: () => model.Category(
          id: 0,
          name: '',
          type: model.TransactionType.expense,
        ),
      );
      return cat.type == model.TransactionType.income ? sum + item.amount : sum;
    });
  }

  double get _totalExpense {
    return _transactions.fold(0.0, (sum, item) {
      final cat = _categories.firstWhere(
        (c) => c.id == item.categoryId,
        orElse: () => model.Category(
          id: 0,
          name: '',
          type: model.TransactionType.expense,
        ),
      );
      return cat.type == model.TransactionType.expense
          ? sum + item.amount
          : sum;
    });
  }

  double get _balance => _totalIncome - _totalExpense;

  List<Map<String, dynamic>> _getIncomeByCategoryForYear(int selectedYear) {
    final now = DateTime.now();
    final yearStr = selectedYear.toString();
    final isCurrentYear = selectedYear == now.year;
    final monthLimitFormat = isCurrentYear
        ? DateFormat('yyyy-MM').format(now)
        : '$yearStr-12';
    final Map<String, double> categoryMap = {};

    for (var tx in _transactions) {
      if (tx.date.length >= 7) {
        final txYearMonth = (tx.date.length >= 7
            ? tx.date.substring(0, 7)
            : '');
        final txYear = (tx.date.length >= 4 ? tx.date.substring(0, 4) : '');

        if (txYear == yearStr && txYearMonth.compareTo(monthLimitFormat) <= 0) {
          final cat = _categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => model.Category(
              id: 0,
              name: 'Lainnya',
              type: model.TransactionType.expense,
            ),
          );
          if (cat.type == model.TransactionType.income) {
            categoryMap[cat.name] = (categoryMap[cat.name] ?? 0) + tx.amount;
          }
        }
      }
    }

    final List<Map<String, dynamic>> result = [];
    double total = categoryMap.values.fold(0.0, (a, b) => a + b);

    categoryMap.forEach((name, amount) {
      final percentage = total == 0 ? 0.0 : (amount / total) * 100;
      result.add({'name': name, 'amount': amount, 'percentage': percentage});
    });
    result.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );
    return result;
  }

  List<Map<String, dynamic>> _getExpenseByCategoryForYear(int selectedYear) {
    final now = DateTime.now();
    final yearStr = selectedYear.toString();
    final isCurrentYear = selectedYear == now.year;
    final monthLimitFormat = isCurrentYear
        ? DateFormat('yyyy-MM').format(now)
        : '$yearStr-12';
    final Map<String, double> categoryMap = {};

    for (var tx in _transactions) {
      if (tx.date.length >= 7) {
        final txYearMonth = (tx.date.length >= 7
            ? tx.date.substring(0, 7)
            : '');
        final txYear = (tx.date.length >= 4 ? tx.date.substring(0, 4) : '');

        if (txYear == yearStr && txYearMonth.compareTo(monthLimitFormat) <= 0) {
          final cat = _categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => model.Category(
              id: 0,
              name: 'Lainnya',
              type: model.TransactionType.expense,
            ),
          );
          if (cat.type == model.TransactionType.expense) {
            categoryMap[cat.name] = (categoryMap[cat.name] ?? 0) + tx.amount;
          }
        }
      }
    }

    final List<Map<String, dynamic>> result = [];
    double total = categoryMap.values.fold(0.0, (a, b) => a + b);

    categoryMap.forEach((name, amount) {
      final percentage = total == 0 ? 0.0 : (amount / total) * 100;
      result.add({'name': name, 'amount': amount, 'percentage': percentage});
    });
    result.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );
    return result;
  }

  List<Map<String, dynamic>> _getExpenseByItemForYear(int selectedYear) {
    final now = DateTime.now();
    final yearStr = selectedYear.toString();
    final isCurrentYear = selectedYear == now.year;
    final monthLimitFormat = isCurrentYear
        ? DateFormat('yyyy-MM').format(now)
        : '$yearStr-12';
    final Map<String, double> itemMap = {};

    for (var tx in _transactions) {
      if (tx.date.length >= 7) {
        final txYearMonth = (tx.date.length >= 7
            ? tx.date.substring(0, 7)
            : '');
        final txYear = (tx.date.length >= 4 ? tx.date.substring(0, 4) : '');

        if (txYear == yearStr && txYearMonth.compareTo(monthLimitFormat) <= 0) {
          final cat = _categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => model.Category(
              id: 0,
              name: '',
              type: model.TransactionType.expense,
            ),
          );
          if (cat.type == model.TransactionType.expense) {
            final itemName = tx.title.isNotEmpty ? tx.title : 'Item Umum';
            itemMap[itemName] = (itemMap[itemName] ?? 0) + tx.amount;
          }
        }
      }
    }

    final List<Map<String, dynamic>> result = [];
    double total = itemMap.values.fold(0.0, (a, b) => a + b);

    itemMap.forEach((name, amount) {
      final percentage = total == 0 ? 0.0 : (amount / total) * 100;
      result.add({'name': name, 'amount': amount, 'percentage': percentage});
    });
    result.sort(
      (a, b) => (b['amount'] as double).compareTo(a['amount'] as double),
    );
    return result;
  }

  Map<String, dynamic> _getBudgetVsExpenseForYear(int selectedYear) {
    final now = DateTime.now();
    final isCurrentYear = selectedYear == now.year;
    final monthLimit = isCurrentYear ? now.month : 12;

    double totalBudget = 0;
    for (var b in _budgets) {
      if (b.year == selectedYear && b.month <= monthLimit) {
        totalBudget += b.amount;
      }
    }

    double totalExpense = 0;
    final yearStr = selectedYear.toString();
    final monthLimitFormat = isCurrentYear
        ? DateFormat('yyyy-MM').format(now)
        : '$yearStr-12';

    for (var tx in _transactions) {
      if (tx.date.length >= 7) {
        final txYearMonth = (tx.date.length >= 7
            ? tx.date.substring(0, 7)
            : '');
        final txYear = (tx.date.length >= 4 ? tx.date.substring(0, 4) : '');
        if (txYear == yearStr && txYearMonth.compareTo(monthLimitFormat) <= 0) {
          final cat = _categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => model.Category(
              id: 0,
              name: '',
              type: model.TransactionType.expense,
            ),
          );
          if (cat.type == model.TransactionType.expense) {
            totalExpense += tx.amount;
          }
        }
      }
    }

    return {'budget': totalBudget, 'expense': totalExpense};
  }

  List<Map<String, dynamic>> _getLast6MonthsComparison() {
    final List<Map<String, dynamic>> result = [];
    final now = DateTime.now();

    for (int i = 5; i >= 0; i--) {
      final targetDate = DateTime(now.year, now.month - i, 1);
      final monthKey = DateFormat('yyyy-MM').format(targetDate);
      final monthLabel = DateFormat(
        'MMM',
        widget.languageCode == 'ms' ? 'ms_MY' : 'id_ID',
      ).format(targetDate);

      double incomeSum = 0;
      double expenseSum = 0;

      for (var tx in _transactions) {
        if (tx.date.startsWith(monthKey)) {
          final cat = _categories.firstWhere(
            (c) => c.id == tx.categoryId,
            orElse: () => model.Category(
              id: 0,
              name: '',
              type: model.TransactionType.expense,
            ),
          );
          if (cat.type == model.TransactionType.income) {
            incomeSum += tx.amount;
          } else {
            expenseSum += tx.amount;
          }
        }
      }

      result.add({
        'label': monthLabel,
        'income': incomeSum,
        'expense': expenseSum,
      });
    }
    return result;
  }

  void _showAnalyticsModal(BuildContext context) {
    final loc = AppLocalizations(widget.languageCode);
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );

    Set<int> availableYears = {
      ..._transactions.map(
        (t) =>
            int.tryParse((t.date.length >= 4 ? t.date.substring(0, 4) : '')) ??
            DateTime.now().year,
      ),
      ..._budgets.map((b) => b.year),
      DateTime.now().year,
    };
    List<int> yearsList = availableYears.toList()
      ..sort((a, b) => b.compareTo(a));

    int selectedYear = DateTime.now().year;

    final List<Color> chartColors = [
      const Color(0xFF3F51B5),
      const Color(0xFF00ACC1),
      const Color(0xFFFF7043),
      const Color(0xFFAB47BC),
      const Color(0xFF26A69A),
      const Color(0xFFFFCA28),
      const Color(0xFFEC407A),
      const Color(0xFF5C6BC0),
      const Color(0xFF26C6DA),
    ];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            bool isExpenseByCategory = true;

            final budgetVsExpense = _getBudgetVsExpenseForYear(selectedYear);
            final incomeByCat = _getIncomeByCategoryForYear(selectedYear);
            final expenseByCat = _getExpenseByCategoryForYear(selectedYear);
            final expenseByItem = _getExpenseByItemForYear(selectedYear);

            return Container(
              height: MediaQuery.of(context).size.height * 0.88,
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
              ),
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        loc.translate(
                          'advanced_analytics',
                          fallback: 'Grafik Analisis Lengkap',
                        ),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Pilih Tahun:',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade100,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: DropdownButton<int>(
                          value: yearsList.contains(selectedYear)
                              ? selectedYear
                              : yearsList.first,
                          underline: const SizedBox(),
                          isDense: true,
                          items: yearsList.map((year) {
                            return DropdownMenuItem<int>(
                              value: year,
                              child: Text(
                                year.toString(),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A237E),
                                ),
                              ),
                            );
                          }).toList(),
                          onChanged: (newYear) {
                            if (newYear != null) {
                              setModalState(() {
                                selectedYear = newYear;
                              });
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      physics: const BouncingScrollPhysics(),
                      children: [
                        _buildAnalyticsCard(
                          title:
                              '${loc.translate('budget_vs_expense_chart_title')} ($selectedYear)',
                          child: Column(
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceAround,
                                children: [
                                  _buildSummaryBadge(
                                    loc.translate('total_budget_ytd'),
                                    currencyFormatter.format(
                                      budgetVsExpense['budget'],
                                    ),
                                    Colors.blue.shade700,
                                  ),
                                  _buildSummaryBadge(
                                    loc.translate('total_spent_ytd'),
                                    currencyFormatter.format(
                                      budgetVsExpense['expense'],
                                    ),
                                    Colors.orange.shade700,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 18),
                              SizedBox(
                                height: 120,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    _buildVerticalBar(
                                      label: 'Budget',
                                      value:
                                          budgetVsExpense['budget'] as double,
                                      maxVal: math.max(
                                        budgetVsExpense['budget'] as double,
                                        budgetVsExpense['expense'] as double,
                                      ),
                                      color: Colors.blue.shade600,
                                    ),
                                    const SizedBox(width: 40),
                                    _buildVerticalBar(
                                      label: loc.translate('grafik_expense'),
                                      value:
                                          budgetVsExpense['expense'] as double,
                                      maxVal: math.max(
                                        budgetVsExpense['budget'] as double,
                                        budgetVsExpense['expense'] as double,
                                      ),
                                      color:
                                          (budgetVsExpense['expense']
                                                  as double) >
                                              (budgetVsExpense['budget']
                                                  as double)
                                          ? Colors.red.shade600
                                          : Colors.orange.shade600,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value:
                                      (budgetVsExpense['budget'] as double) == 0
                                      ? 0
                                      : ((budgetVsExpense['expense']
                                                    as double) /
                                                (budgetVsExpense['budget']
                                                    as double))
                                            .clamp(0.0, 1.0),
                                  minHeight: 12,
                                  backgroundColor: Colors.grey.shade200,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    (budgetVsExpense['expense'] as double) >
                                            (budgetVsExpense['budget']
                                                as double)
                                        ? Colors.red.shade600
                                        : Colors.green.shade600,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Center(
                                child: Text(
                                  (budgetVsExpense['budget'] as double) == 0
                                      ? loc.translate('no_usage')
                                      : '${loc.translate('rasio_usage')}: ${(((budgetVsExpense['expense'] as double) / (budgetVsExpense['budget'] as double)) * 100).toStringAsFixed(1)}%',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade700,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildAnalyticsCard(
                          title:
                              '${loc.translate('income_by_category_chart_title')} ($selectedYear)',
                          child: incomeByCat.isEmpty
                              ? Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Text(
                                    loc.translate('no_revenue'),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                )
                              : Column(
                                  children: [
                                    SizedBox(
                                      height: 180,
                                      child: CustomPaint(
                                        painter: DonutChartPainter(
                                          items: incomeByCat,
                                          colors: chartColors,
                                        ),
                                        child: Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                loc.translate(
                                                  'total_income_label',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  color: Colors.grey,
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                              const SizedBox(height: 2),
                                              Text(
                                                currencyFormatter.format(
                                                  incomeByCat.fold(
                                                    0.0,
                                                    (sum, item) =>
                                                        sum +
                                                        (item['amount']
                                                            as double),
                                                  ),
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF0F172A),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                    ...incomeByCat.asMap().entries.map((entry) {
                                      final index = entry.key;
                                      final item = entry.value;
                                      final color =
                                          chartColors[index %
                                              chartColors.length];
                                      return _buildLegendRow(
                                        color,
                                        item['name'],
                                        currencyFormatter.format(
                                          item['amount'],
                                        ),
                                        '${(item['percentage'] as double).toStringAsFixed(1)}%',
                                      );
                                    }),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 16),
                        StatefulBuilder(
                          builder: (context, setSwitchState) {
                            final currentExpenseData = isExpenseByCategory
                                ? expenseByCat
                                : expenseByItem;
                            final totalExpenseSum = currentExpenseData.fold(
                              0.0,
                              (sum, item) => sum + (item['amount'] as double),
                            );

                            return _buildAnalyticsCard(
                              title:
                                  '${isExpenseByCategory ? loc.translate('expense_by_category_title') : loc.translate('expense_by_item_title')} ($selectedYear)',
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setSwitchState(
                                              () => isExpenseByCategory = true,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isExpenseByCategory
                                                    ? const Color(0xFF1A237E)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Per Kategori',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: isExpenseByCategory
                                                      ? Colors.white
                                                      : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                        Expanded(
                                          child: GestureDetector(
                                            onTap: () => setSwitchState(
                                              () => isExpenseByCategory = false,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    vertical: 8,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: !isExpenseByCategory
                                                    ? const Color(0xFF1A237E)
                                                    : Colors.transparent,
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                              alignment: Alignment.center,
                                              child: Text(
                                                'Per Item',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.bold,
                                                  color: !isExpenseByCategory
                                                      ? Colors.white
                                                      : Colors.grey.shade700,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  currentExpenseData.isEmpty
                                      ? Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Text(
                                            loc.translate('no_usage'),
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.grey,
                                            ),
                                          ),
                                        )
                                      : Column(
                                          children: [
                                            SizedBox(
                                              height: 180,
                                              child: CustomPaint(
                                                painter: DonutChartPainter(
                                                  items: currentExpenseData,
                                                  colors: chartColors,
                                                ),
                                                child: Center(
                                                  child: Column(
                                                    mainAxisSize:
                                                        MainAxisSize.min,
                                                    children: [
                                                      Text(
                                                        isExpenseByCategory
                                                            ? loc.translate(
                                                                'total_category_label',
                                                              )
                                                            : loc.translate(
                                                                'total_item_label',
                                                              ),
                                                        style: const TextStyle(
                                                          fontSize: 10,
                                                          color: Colors.grey,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        currencyFormatter
                                                            .format(
                                                              totalExpenseSum,
                                                            ),
                                                        style: const TextStyle(
                                                          fontSize: 12,
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          color: Color(
                                                            0xFF0F172A,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            ...currentExpenseData
                                                .asMap()
                                                .entries
                                                .map((entry) {
                                                  final index = entry.key;
                                                  final item = entry.value;
                                                  final color =
                                                      chartColors[index %
                                                          chartColors.length];
                                                  return _buildLegendRow(
                                                    color,
                                                    item['name'],
                                                    currencyFormatter.format(
                                                      item['amount'],
                                                    ),
                                                    '${(item['percentage'] as double).toStringAsFixed(1)}%',
                                                  );
                                                }),
                                          ],
                                        ),
                                ],
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildVerticalBar({
    required String label,
    required double value,
    required double maxVal,
    required Color color,
  }) {
    double barHeight = 80;
    if (maxVal > 0) {
      barHeight = (value / maxVal) * 80;
      if (barHeight < 10) barHeight = 10;
      if (barHeight > 80) barHeight = 80;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Text(
          value >= 1000000
              ? '${(value / 1000000).toStringAsFixed(1)}jt'
              : '${(value / 1000).toStringAsFixed(0)}k',
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          width: 28,
          height: barHeight,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(6),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Color(0xFF0F172A),
          ),
        ),
      ],
    );
  }

  Widget _buildLegendRow(
    Color color,
    String name,
    String amount,
    String percentage,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF0F172A),
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Text(
                amount,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1A237E),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  percentage,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey.shade700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCard({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A237E),
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _buildSummaryBadge(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey.shade600,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations(widget.languageCode);
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final recentTransactions = _transactions.take(5).toList();
    final chartData = _getLast6MonthsComparison();

    double maxVal = 100000.0;
    for (var data in chartData) {
      if ((data['income'] as double) > maxVal) {
        maxVal = data['income'] as double;
      }
      if ((data['expense'] as double) > maxVal) {
        maxVal = data['expense'] as double;
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)),
            )
          : RefreshIndicator(
              onRefresh: _loadData,
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverAppBar(
                    expandedHeight: 110.0,
                    floating: false,
                    pinned: true,
                    backgroundColor: const Color(0xFF1A237E),
                    elevation: 0,
                    flexibleSpace: FlexibleSpaceBar(
                      titlePadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 16,
                      ),
                      title: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('app_title'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                '${loc.translate('hello')}, ${widget.userName}',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Colors.white.withValues(alpha: 0.8),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: Colors.white.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: _buildAppLogoWidget(widget.appLogo),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [
                                  Color(0xFF1A237E),
                                  Color(0xFF3F51B5),
                                  Color(0xFF00838F),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(24),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF3F51B5)
                                      .withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      loc.translate('remaining_balance'),
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withValues(
                                          alpha: 0.2,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Text(
                                        loc.translate('main_wallet'),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  currencyFormatter.format(_balance),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 30,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 18.0,
                                  ),
                                  child: Divider(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    height: 1,
                                  ),
                                ),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildInfoColumn(
                                      loc.translate('monthly_income'),
                                      currencyFormatter.format(
                                        _currentMonthIncome,
                                      ),
                                      const Color(0xFF69F0AE),
                                      Icons.arrow_downward_rounded,
                                    ),
                                    Container(
                                      height: 35,
                                      width: 1,
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                    ),
                                    _buildInfoColumn(
                                      loc.translate('monthly_expense'),
                                      currencyFormatter.format(
                                        _currentMonthExpense,
                                      ),
                                      const Color(0xFFFF8A80),
                                      Icons.arrow_upward_rounded,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),

                          // ==========================================
                          // BANNER SHORTCUT KALENDER TAGIHAN & CICILAN
                          // ==========================================
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => CalendarScheduleScreen(
                                    currentLanguage: widget.languageCode,
                                  ),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(20),
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.indigo.shade800,
                                    Colors.indigo.shade600,
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.indigo.withValues(alpha: 0.2),
                                    blurRadius: 10,
                                    offset: const Offset(0, 4),
                                  ),
                                ],
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                    child: const Icon(
                                      Icons.calendar_month_rounded,
                                      color: Colors.white,
                                      size: 28,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          widget.languageCode == 'en'
                                              ? 'Schedule & Installments Calendar'
                                              : 'Kalender Tagihan & Cicilan',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 15,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          widget.languageCode == 'en'
                                              ? 'Tap to view due dates & quick pay'
                                              : 'Ketuk untuk lihat jatuh tempo & bayar instan',
                                          style: TextStyle(
                                            color: Colors.white.withValues(
                                              alpha: 0.8,
                                            ),
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: Colors.white70,
                                    size: 16,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          // ==========================================

                          const SizedBox(height: 28),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                loc.translate('monthly_comparison'),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  _buildLegendIndicator(
                                    loc.translate('income_legend'),
                                    const Color(0xFF00ACC1),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildLegendIndicator(
                                    loc.translate('expense_legend'),
                                    const Color(0xFF3F51B5),
                                  ),
                                  const SizedBox(width: 12),
                                  _buildLegendIndicator(
                                    loc.translate('deficit_legend'),
                                    Colors.red.shade600,
                                  ),
                                ],
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white,
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.03),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                SizedBox(
                                  height: 180,
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.end,
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceAround,
                                    children: chartData.map((data) {
                                      final double income =
                                          data['income'] as double;
                                      final double expense =
                                          data['expense'] as double;
                                      final bool isDeficit = expense > income;

                                      final double incomeHeight =
                                          (income / maxVal) * 110;
                                      final double expenseHeight =
                                          (expense / maxVal) * 110;

                                      return Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.end,
                                        children: [
                                          Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.end,
                                            children: [
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  if (income > 0)
                                                    Text(
                                                      '${(income / 1000).toStringAsFixed(0)}k',
                                                      style: const TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFF00ACC1,
                                                        ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    width: 12,
                                                    height: incomeHeight < 6
                                                        ? 6
                                                        : incomeHeight,
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF00ACC1,
                                                      ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                              const SizedBox(width: 4),
                                              Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.end,
                                                children: [
                                                  if (expense > 0)
                                                    Text(
                                                      '${(expense / 1000).toStringAsFixed(0)}k',
                                                      style: TextStyle(
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isDeficit
                                                            ? Colors
                                                                  .red
                                                                  .shade700
                                                            : const Color(
                                                                0xFF3F51B5,
                                                              ),
                                                      ),
                                                    ),
                                                  const SizedBox(height: 4),
                                                  Container(
                                                    width: 12,
                                                    height: expenseHeight < 6
                                                        ? 6
                                                        : expenseHeight,
                                                    decoration: BoxDecoration(
                                                      color: isDeficit
                                                          ? Colors.red.shade600
                                                          : const Color(
                                                              0xFF3F51B5,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            4,
                                                          ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            data['label'],
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      );
                                    }).toList(),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton.icon(
                                    style: TextButton.styleFrom(
                                      backgroundColor: Colors.indigo.shade50
                                          .withValues(alpha: 0.5),
                                      foregroundColor: const Color(0xFF1A237E),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () =>
                                        _showAnalyticsModal(context),
                                    icon: const Icon(
                                      Icons.insights_rounded,
                                      size: 18,
                                    ),
                                    label: Text(
                                      loc.translate('show_more_analytics'),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 28),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                loc.translate('recent_activity'),
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              Text(
                                '${_transactions.length} ${loc.translate('total_transactions')}',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey.shade500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          recentTransactions.isEmpty
                              ? Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 40,
                                    horizontal: 24,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(color: Colors.white),
                                  ),
                                  child: Column(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: Colors.indigo.shade50,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          Icons.receipt_long_rounded,
                                          size: 36,
                                          color: Colors.indigo.shade700,
                                        ),
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        loc.translate('no_transactions'),
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF0F172A),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        loc.translate('no_transactions_desc'),
                                        textAlign: TextAlign.center,
                                        style: TextStyle(
                                          fontSize: 13,
                                          color: Colors.grey.shade500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: recentTransactions.length,
                                  itemBuilder: (ctx, index) {
                                    final tx = recentTransactions[index];
                                    final cat = _categories.firstWhere(
                                      (c) => c.id == tx.categoryId,
                                      orElse: () => model.Category(
                                        id: 0,
                                        name: loc.translate('others'),
                                        type: model.TransactionType.expense,
                                      ),
                                    );
                                    final isIncome =
                                        cat.type ==
                                        model.TransactionType.income;

                                    return Dismissible(
                                      key: Key('tx_${tx.id}_$index'),
                                      direction: DismissDirection.endToStart,
                                      background: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 20,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade600,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                        ),
                                        alignment: Alignment.centerRight,
                                        child: const Icon(
                                          Icons.delete_rounded,
                                          color: Colors.white,
                                          size: 24,
                                        ),
                                      ),
                                      confirmDismiss: (direction) async {
                                        return await showDialog(
                                          context: context,
                                          builder: (BuildContext context) {
                                            return AlertDialog(
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                              ),
                                              title: Text(
                                                loc.translate(
                                                  'delete_transaction',
                                                ),
                                                style: const TextStyle(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              content: Text(
                                                loc
                                                    .translate(
                                                      'delete_transaction_confirm',
                                                    )
                                                    .replaceFirst(
                                                      '{title}',
                                                      tx.title,
                                                    )
                                                    .replaceFirst(
                                                      '{amount}',
                                                      currencyFormatter.format(
                                                        tx.amount,
                                                      ),
                                                    ),
                                              ),
                                              actions: [
                                                TextButton(
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(false),
                                                  child: Text(
                                                    loc.translate('cancel'),
                                                    style: const TextStyle(
                                                      color: Colors.grey,
                                                    ),
                                                  ),
                                                ),
                                                ElevatedButton(
                                                  style:
                                                      ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            Colors.red.shade600,
                                                        foregroundColor:
                                                            Colors.white,
                                                      ),
                                                  onPressed: () =>
                                                      Navigator.of(context)
                                                          .pop(true),
                                                  child: Text(
                                                    loc.translate('delete'),
                                                  ),
                                                ),
                                              ],
                                            );
                                          },
                                        );
                                      },
                                      onDismissed: (direction) async {
                                        if (tx.id != null) {
                                          await DatabaseHelper.instance
                                              .deleteTransaction(tx.id!);
                                          await _loadData();
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  SnackBar(
                                                    content: Text(
                                                      loc.translate(
                                                        'transaction_deleted_success',
                                                      ),
                                                    ),
                                                    backgroundColor: Colors.red,
                                                  ),
                                                );
                                          }
                                        }
                                      },
                                      child: Material(
                                        color: Colors.transparent,
                                        child: Container(
                                          margin: const EdgeInsets.only(
                                            bottom: 12,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              18,
                                            ),
                                            border: Border.all(
                                              color: Colors.white,
                                              width: 1.5,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(
                                                  alpha: 0.02,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 3),
                                              ),
                                            ],
                                          ),
                                          child: ListTile(
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  horizontal: 16,
                                                  vertical: 8,
                                                ),
                                            leading: _buildTransactionItemIcon(
                                              tx,
                                              isIncome,
                                            ),
                                            title: Text(
                                              tx.title,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                                color: Color(0xFF0F172A),
                                              ),
                                            ),
                                            subtitle: Padding(
                                              padding: const EdgeInsets.only(
                                                top: 4.0,
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 8,
                                                              vertical: 2,
                                                            ),
                                                        decoration: BoxDecoration(
                                                          color: Colors
                                                              .grey
                                                              .shade100,
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                6,
                                                              ),
                                                        ),
                                                        child: Text(
                                                          cat.name,
                                                          style: TextStyle(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: Colors
                                                                .grey
                                                                .shade700,
                                                          ),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        tx.date.substring(
                                                          0,
                                                          10,
                                                        ),
                                                        style: TextStyle(
                                                          fontSize: 11,
                                                          color: Colors
                                                              .grey
                                                              .shade400,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  if (tx.note != null &&
                                                      tx.note!.isNotEmpty) ...[
                                                    const SizedBox(height: 4),
                                                    Text(
                                                      '"${tx.note}"',
                                                      style: TextStyle(
                                                        fontSize: 12,
                                                        fontStyle:
                                                            FontStyle.italic,
                                                        color: Colors
                                                            .grey
                                                            .shade600,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                            trailing: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Text(
                                                  '${isIncome ? "+ " : "- "}${currencyFormatter.format(tx.amount)}',
                                                  style: TextStyle(
                                                    color: isIncome
                                                        ? Colors.green.shade700
                                                        : Colors.red.shade700,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 13,
                                                  ),
                                                ),
                                                const SizedBox(width: 4),
                                                IconButton(
                                                  icon: const Icon(
                                                    Icons
                                                        .delete_outline_rounded,
                                                    size: 18,
                                                    color: Colors.grey,
                                                  ),
                                                  onPressed: () async {
                                                    bool?
                                                    confirm = await showDialog(
                                                      context: context,
                                                      builder: (context) => AlertDialog(
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                16,
                                                              ),
                                                        ),
                                                        title: Text(
                                                          loc.translate(
                                                            'delete_transaction',
                                                          ),
                                                          style:
                                                              const TextStyle(
                                                                fontSize: 16,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                        content: Text(
                                                          loc.translate(
                                                            'delete_confirmation_simple',
                                                          ),
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  false,
                                                                ),
                                                            child: Text(
                                                              loc.translate(
                                                                'cancel',
                                                              ),
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  Colors
                                                                      .red
                                                                      .shade600,
                                                              foregroundColor:
                                                                  Colors.white,
                                                            ),
                                                            onPressed: () =>
                                                                Navigator.pop(
                                                                  context,
                                                                  true,
                                                                ),
                                                            child: Text(
                                                              loc.translate(
                                                                'delete',
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                    if (confirm == true &&
                                                        tx.id != null) {
                                                      await DatabaseHelper
                                                          .instance
                                                          .deleteTransaction(
                                                            tx.id!,
                                                          );
                                                      await _loadData();
                                                    }
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoColumn(
    String label,
    String amount,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 16),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(color: Colors.white70, fontSize: 11),
            ),
            const SizedBox(height: 2),
            Text(
              amount,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLegendIndicator(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.bold,
            color: Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

class DonutChartPainter extends CustomPainter {
  final List<Map<String, dynamic>> items;
  final List<Color> colors;

  DonutChartPainter({required this.items, required this.colors});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width / 2, size.height / 2) - 8;
    const strokeWidth = 32.0;

    double total = items.fold(
      0.0,
      (sum, item) => sum + (item['amount'] as double),
    );

    if (total <= 0) {
      final paint = Paint()
        ..color = Colors.grey.shade200
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth;
      canvas.drawCircle(center, radius - (strokeWidth / 2), paint);
      return;
    }

    double startAngle = -math.pi / 2;
    for (int i = 0; i < items.length; i++) {
      final item = items[i];
      final amount = item['amount'] as double;
      if (amount <= 0) continue;

      final sweepAngle = (amount / total) * 2 * math.pi;
      final paint = Paint()
        ..color = colors[i % colors.length]
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - (strokeWidth / 2)),
        startAngle,
        sweepAngle,
        false,
        paint,
      );
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
