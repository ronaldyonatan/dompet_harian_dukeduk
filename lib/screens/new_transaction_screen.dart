import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../helpers/database_helper.dart';
import '../models/finance_model.dart' as model;
import '../helpers/localization_helper.dart';
import '../helpers/currency_formatter_helper.dart';
import 'barcode_scanner_screen.dart';

class NewTransactionScreen extends StatefulWidget {
  final String languageCode;

  const NewTransactionScreen({
    super.key,
    required this.languageCode,
  });

  @override
  State<NewTransactionScreen> createState() => _NewTransactionScreenState();
}

class _NewTransactionScreenState extends State<NewTransactionScreen> {
  List<model.Category> _categories = [];
  List<model.ItemModel> _items = [];
  bool _isLoading = true;

  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  final _barcodeController = TextEditingController();

  String _itemSearchQuery = '';
  model.ItemModel? _selectedItem;
  model.Category? _resolvedCategory;
  DateTime _selectedDate = DateTime.now();
  String? _scannedBarcode;

  @override
  void initState() {
    super.initState();
    _loadDependencies();
  }

  Future<void> _loadDependencies() async {
    setState(() => _isLoading = true);
    final results = await Future.wait([
      DatabaseHelper.instance.getCategories(),
      DatabaseHelper.instance.getItems(),
    ]);

    setState(() {
      _categories = results[0] as List<model.Category>;
      _items = results[1] as List<model.ItemModel>;
      if (_items.isNotEmpty) {
        _selectedItem = _items.first;
        _updateCategory(_selectedItem);
        _updateBarcodeFromItem(_selectedItem);
      }
      _isLoading = false;
    });
  }

  void _updateCategory(model.ItemModel? item) {
    if (item != null) {
      _resolvedCategory = _categories.firstWhere(
        (c) => c.id == item.categoryId,
        orElse: () => _categories.isNotEmpty 
            ? _categories.first 
            : model.Category(id: 0, name: '', type: model.TransactionType.expense),
      );
    } else {
      _resolvedCategory = null;
    }
  }

  void _updateBarcodeFromItem(model.ItemModel? item) {
    if (item != null && item.barcode != null && item.barcode!.isNotEmpty) {
      _barcodeController.text = item.barcode!;
      _scannedBarcode = item.barcode;
    } else {
      _barcodeController.text = '';
      _scannedBarcode = null;
    }
  }

  void _onSearchQueryChanged(String query) {
    setState(() {
      _itemSearchQuery = query;

      final filtered = _items.where((item) {
        return item.name.toLowerCase().contains(query.toLowerCase());
      }).toList();

      if (filtered.isNotEmpty) {
        // Jika ketemu tepat 1 item ATAU item yang terpilih sebelumnya tidak ada di daftar filtered
        if (filtered.length == 1 || !filtered.any((item) => item.id == _selectedItem?.id)) {
          _selectedItem = filtered.first;
          _updateCategory(_selectedItem);
          _updateBarcodeFromItem(_selectedItem);
        }
      } else {
        _selectedItem = null;
        _resolvedCategory = null;
        _barcodeController.text = '';
        _scannedBarcode = null;
      }
    });
  }

  Future<void> _scanAndFillBarcode() async {
    final loc = AppLocalizations(widget.languageCode);
    final scannedCode = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const BarcodeScannerScreen()),
    );

    if (scannedCode != null && scannedCode.isNotEmpty) {
      _scannedBarcode = scannedCode;
      _barcodeController.text = scannedCode;

      model.ItemModel? foundItem = await DatabaseHelper.instance.getItemByBarcode(scannedCode);
      
      if (foundItem != null) {
        model.ItemModel matchedItem = _items.firstWhere(
          (item) => item.id == foundItem.id,
          orElse: () => foundItem,
        );

        setState(() {
          _selectedItem = matchedItem;
          _updateCategory(matchedItem);
        });

        final lastTx = await DatabaseHelper.instance.getLastTransactionByItem(matchedItem.id!);
        if (lastTx != null) {
          _amountController.text = lastTx.amount.toStringAsFixed(0);
        } else if ((matchedItem.defaultPrice ?? 0) > 0) {
          _amountController.text = matchedItem.defaultPrice!.toStringAsFixed(0);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${loc.translate('item_found')}: ${matchedItem.name}'), 
              backgroundColor: Colors.green,
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(loc.translate('new_barcode_notice')),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    }
  }

  Future<void> _saveTransaction() async {
    final loc = AppLocalizations(widget.languageCode);
    final cleanAmountText = _amountController.text.replaceAll('.', '');
    final amount = double.tryParse(cleanAmountText) ?? 0;
    
    if (amount <= 0 || _selectedItem == null || _resolvedCategory == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(loc.translate('fill_all_fields') ?? 'Mohon isi nominal dan item dengan benar'), 
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_scannedBarcode != null && _scannedBarcode!.isNotEmpty) {
      model.ItemModel? ownerItem = await DatabaseHelper.instance.getOwnerItemByBarcode(
        _scannedBarcode!, 
        excludeItemId: _selectedItem!.id
      );

      if (ownerItem != null && ownerItem.id != _selectedItem!.id) {
        if (!mounted) return;
        bool? confirmTransfer = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Text(loc.translate('duplicate_barcode_warning'), style: const TextStyle(fontWeight: FontWeight.bold)),
            content: Text(
              loc.translate('duplicate_barcode_message')
                  .replaceFirst('{owner}', ownerItem.name)
                  .replaceFirst('{target}', _selectedItem!.name),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(loc.translate('cancel'), style: const TextStyle(color: Colors.grey)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade600, foregroundColor: Colors.white),
                onPressed: () => Navigator.pop(context, true),
                child: Text(loc.translate('yes_transfer')),
              ),
            ],
          ),
        );

        if (confirmTransfer != true) return;
      }

      await DatabaseHelper.instance.updateItemBarcode(_selectedItem!.id!, _scannedBarcode!);
    }

    final newTx = model.TransactionModel(
      title: _selectedItem!.name,
      amount: amount,
      date: _selectedDate.toIso8601String(),
      categoryId: _resolvedCategory!.id!,
      itemId: _selectedItem!.id,
      note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
    );

    await DatabaseHelper.instance.insertTransaction(newTx);
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations(widget.languageCode);
    final filteredItems = _items.where((item) {
      return item.name.toLowerCase().contains(_itemSearchQuery.toLowerCase());
    }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Text(
          loc.translate('record_transaction_scan'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner_rounded, color: Colors.white),
            tooltip: loc.translate('scan_barcode'),
            onPressed: _scanAndFillBarcode,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextField(
                    controller: _barcodeController,
                    readOnly: true,
                    decoration: InputDecoration(
                      labelText: loc.translate('barcode_id_readonly'),
                      hintText: loc.translate('no_barcode_scanned'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                      prefixIcon: const Icon(Icons.qr_code, color: Color(0xFF1A237E)),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    decoration: InputDecoration(
                      labelText: loc.translate('search_master_item'),
                      prefixIcon: const Icon(Icons.search, color: Color(0xFF1A237E)),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                    onChanged: _onSearchQueryChanged,
                  ),
                  const SizedBox(height: 14),
                  DropdownButtonFormField<model.ItemModel>(
                    value: filteredItems.any((item) => item.id == _selectedItem?.id)
                        ? filteredItems.firstWhere((item) => item.id == _selectedItem?.id)
                        : null,
                    decoration: InputDecoration(
                      labelText: loc.translate('select_master_item'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                    items: filteredItems.map((item) {
                      return DropdownMenuItem(
                        value: item, 
                        child: Text(item.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _selectedItem = newValue;
                        _updateCategory(newValue);
                        _updateBarcodeFromItem(newValue);
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.indigo.shade100),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          loc.translate('category_group'), 
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF3F51B5)),
                        ),
                        Text(
                          _resolvedCategory?.name ?? '-', 
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1A237E)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  InkWell(
                    onTap: () async {
                      final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030),
                      );
                      if (pickedDate != null) {
                        setState(() {
                          _selectedDate = pickedDate;
                        });
                      }
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: InputDecorator(
                      decoration: InputDecoration(
                        labelText: loc.translate('transaction_date'),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                        filled: true,
                        fillColor: Colors.white,
                        suffixIcon: const Icon(Icons.calendar_today_rounded, size: 20, color: Color(0xFF1A237E)),
                      ),
                      child: Text(
                        DateFormat('dd MMMM yyyy', widget.languageCode == 'ms' ? 'ms_MY' : 'id_ID').format(_selectedDate),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _noteController,
                    decoration: InputDecoration(
                      labelText: loc.translate('note_optional'),
                      hintText: loc.translate('note_hint'),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [CurrencyInputFormatter()],
                    decoration: InputDecoration(
                      labelText: loc.translate('nominal_amount'),
                      prefixText: 'Rp ',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF1A237E),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      onPressed: _saveTransaction,
                      child: Text(
                        loc.translate('save_transaction'), 
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}