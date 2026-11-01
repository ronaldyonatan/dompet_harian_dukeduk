import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../models/finance_model.dart' as model;
import '../helpers/loading_helper.dart';
import '../constants/app_icons.dart';

class ItemScreen extends StatefulWidget {
  final String currentLanguage;

  const ItemScreen({super.key, required this.currentLanguage});

  @override
  State<ItemScreen> createState() => _ItemScreenState();
}

class _ItemScreenState extends State<ItemScreen> {
  List<model.ItemModel> _items = [];
  List<model.Category> _categories = [];
  bool _isLoading = true;
  final _itemNameController = TextEditingController();
  model.Category? _selectedCategory;

  String _selectedIcon = 'shopping_bag';
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadDataFirstTime();
  }

  @override
  void dispose() {
    _itemNameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadDataFirstTime() async {
    setState(() => _isLoading = true);
    await _fetchDataLogic();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchDataLogic() async {
    final its = await DatabaseHelper.instance.getItems();
    final cats = await DatabaseHelper.instance.getCategories();
    
    if (mounted) {
      setState(() {
        _items = its.where((i) => i.isActive).toList();
        _categories = cats.where((c) => c.isActive).toList();
        
        if (_categories.isNotEmpty && (_selectedCategory == null || !_categories.contains(_selectedCategory))) {
          _selectedCategory = _categories.first;
        }
      });
    }
  }

  void _showIconPickerSheet() {
    final isEn = widget.currentLanguage == 'en';
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          initialChildSize: 0.70,
          minChildSize: 0.40,
          maxChildSize: 0.90,
          expand: false,
          builder: (context, scrollController) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
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
                  Text(
                    isEn ? 'Select Item Icon' : 'Pilih Ikon Item',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: GridView.builder(
                      controller: scrollController,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 4,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 1.0,
                      ),
                      itemCount: AppIcons.availableIcons.length,
                      itemBuilder: (context, index) {
                        final item = AppIcons.availableIcons[index];
                        final isSelected = _selectedIcon == item['name'];
                        final tColor = AppIcons.getIconThemeColor(item['name']);
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedIcon = item['name'];
                            });
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            decoration: BoxDecoration(
                              color: tColor['bg'],
                              border: Border.all(
                                color: isSelected ? tColor['fg']! : tColor['fg']!.withOpacity(0.5),
                                width: isSelected ? 2.5 : 1.2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  item['icon'],
                                  color: tColor['fg'],
                                  size: 26,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  item['label'],
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: tColor['fg'],
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
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
  }

  void _confirmDeleteItem(model.ItemModel item) {
    final isEn = widget.currentLanguage == 'en';
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(
            isEn ? 'Hide Item' : 'Sembunyikan Item', 
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)
          ),
          content: Text(
            isEn 
              ? 'Item "${item.name}" will be hidden from choices, but past transaction history using this item will remain safe and tracked.'
              : 'Item "${item.name}" akan disembunyikan dari pilihan, namun riwayat transaksi masa lalu yang menggunakan item ini akan tetap aman dan terdeteksi.',
            style: const TextStyle(fontSize: 13, color: Color(0xFF475569)),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(isEn ? 'Cancel' : 'Batal', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade700,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(context);
                LoadingHelper.show(context, message: isEn ? 'Hiding item...' : 'Menyembunyikan item...');

                await DatabaseHelper.instance.softDeleteItem(item.id!);
                await _fetchDataLogic();

                if (!mounted) return;
                LoadingHelper.hide(context);

                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(isEn ? 'Item hidden successfully.' : 'Item berhasil disembunyikan.'), 
                    backgroundColor: Colors.green
                  ),
                );
              },
              child: Text(isEn ? 'Hide' : 'Sembunyikan'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.currentLanguage == 'en';

    final filteredItems = _items.where((item) {
      return item.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          (item.barcode != null && item.barcode!.toLowerCase().contains(_searchQuery.toLowerCase()));
    }).toList();

    final currentSelectedData = AppIcons.availableIcons.firstWhere(
      (element) => element['name'] == _selectedIcon,
      orElse: () => AppIcons.availableIcons.first,
    );
    final currentThemeColor = AppIcons.getIconThemeColor(_selectedIcon);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text(
          isEn ? 'Manage Master Items' : 'Kelola Master Item', 
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
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
                        Text(
                          isEn ? 'Add New Item & Link Category' : 'Tambah Item Baru & Hubungkan Kategori', 
                          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _itemNameController,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Item Name (Ex: Coffee / Salary)' : 'Nama Item (Cth: Kopi Susu / Gaji Pokok)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<model.Category>(
                          value: _selectedCategory,
                          decoration: InputDecoration(
                            labelText: isEn ? 'Select Category (Bridge)' : 'Pilih Kategori (Bridge)',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            filled: true,
                            fillColor: Colors.grey.shade50,
                          ),
                          items: _categories.map((cat) {
                            return DropdownMenuItem(value: cat, child: Text(cat.name, style: const TextStyle(fontSize: 13)));
                          }).toList(),
                          onChanged: (val) => setState(() => _selectedCategory = val),
                        ),
                        const SizedBox(height: 12),

                        InkWell(
                          onTap: _showIconPickerSheet,
                          borderRadius: BorderRadius.circular(12),
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: isEn ? 'Item Icon' : 'Ikon Item',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: Colors.grey.shade50,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(6),
                                      decoration: BoxDecoration(
                                        color: currentThemeColor['bg'],
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Icon(currentSelectedData['icon'], color: currentThemeColor['fg'], size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(currentSelectedData['label'], style: const TextStyle(fontSize: 14)),
                                  ],
                                ),
                                const Icon(Icons.arrow_drop_down, color: Colors.grey),
                              ],
                            ),
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
                          onPressed: () async {
                            final name = _itemNameController.text.trim();
                            if (name.isEmpty || _selectedCategory == null) return;

                            LoadingHelper.show(context, message: isEn ? 'Saving item...' : 'Menyimpan item...');

                            await DatabaseHelper.instance.insertItem(model.ItemModel(
                              name: name,
                              categoryId: _selectedCategory!.id!,
                              isActive: true,
                              icon: _selectedIcon,
                            ));
                            
                            _itemNameController.clear();
                            setState(() => _selectedIcon = 'shopping_bag');
                            await _fetchDataLogic();

                            if (!context.mounted) return;
                            LoadingHelper.hide(context);

                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(isEn ? 'Item saved successfully!' : 'Item berhasil disimpan!'), 
                                backgroundColor: Colors.green
                              ),
                            );
                          },
                          child: Text(isEn ? 'Save Item' : 'Simpan Item', style: const TextStyle(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      labelText: isEn ? 'Search Item Name or Barcode...' : 'Cari Nama Item atau Barcode...',
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

                  Text(
                    isEn ? 'Connected Master Items' : 'Daftar Master Item Terhubung', 
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF0F172A))
                  ),
                  const SizedBox(height: 10),
                  
                  filteredItems.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32.0),
                          child: Center(
                            child: Text(
                              isEn ? 'No items found.' : 'Tiada item dijumpai.', 
                              style: const TextStyle(color: Colors.grey)
                            ),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredItems.length,
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemBuilder: (context, index) {
                            final item = filteredItems[index];
                            final cat = _categories.firstWhere(
                              (c) => c.id == item.categoryId,
                              orElse: () => model.Category(id: 0, name: isEn ? 'General' : 'Umum', type: model.TransactionType.expense),
                            );
                            
                            final themeColor = AppIcons.getIconThemeColor(item.icon);

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: Colors.grey.shade200),
                                boxShadow: [
                                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 6, offset: const Offset(0, 2)),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: themeColor['bg'],
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            AppIcons.getIconData(item.icon), 
                                            size: 24, 
                                            color: themeColor['fg'],
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                item.name, 
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Color(0xFF0F172A))
                                              ),
                                              const SizedBox(height: 3),
                                              Text(
                                                isEn ? 'Category: ${cat.name}' : 'Kategori: ${cat.name}', 
                                                style: TextStyle(fontSize: 12, color: Colors.indigo.shade700, fontWeight: FontWeight.w500)
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 22),
                                    onPressed: () => _confirmDeleteItem(item),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                ],
              ),
            ),
    );
  }
}