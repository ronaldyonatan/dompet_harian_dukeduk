import 'package:flutter/material.dart';
import '../helpers/database_helper.dart';
import '../helpers/localization_helper.dart';
import '../helpers/loading_helper.dart';

class CustomerScreen extends StatefulWidget {
  final String currentLanguage;

  const CustomerScreen({super.key, required this.currentLanguage});

  @override
  State<CustomerScreen> createState() => _CustomerScreenState();
}

class _CustomerScreenState extends State<CustomerScreen> {
  List<Map<String, dynamic>> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await DatabaseHelper.instance.getCustomers();
      setState(() {
        _customers = customers;
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _customers = [];
        _isLoading = false;
      });
    }
  }

  void _showDeleteConfirmation(int id, String name) {
    final localization = AppLocalizations(widget.currentLanguage);
    final isEn = widget.currentLanguage == 'en';
    final currentContext = context;

    showDialog(
      context: currentContext,
      builder: (dialogContext) => AlertDialog(
        title: Text(localization.translate('delete_customer') ?? (isEn ? 'Delete Customer' : 'Hapus Pelanggan')),
        content: Text(isEn ? 'Are you sure you want to delete "$name"?' : 'Apakah Anda yakin ingin menghapus "$name"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(localization.translate('cancel') ?? (isEn ? 'Cancel' : 'Batal'), style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            onPressed: () async {
              Navigator.pop(dialogContext);
              LoadingHelper.show(currentContext, message: localization.translate('deleting') ?? (isEn ? 'Deleting...' : 'Menghapus...'));
              
              try {
                await DatabaseHelper.instance.deleteCustomer(id);
                await _loadCustomers();

                if (!mounted) return;
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(
                    content: Text(localization.translate('customer_deleted_success') ?? (isEn ? 'Customer deleted successfully' : 'Pelanggan berhasil dihapus')), 
                    backgroundColor: Colors.green,
                  ),
                );
              } catch (e) {
                if (!mounted) return;
                ScaffoldMessenger.of(currentContext).showSnackBar(
                  SnackBar(
                    content: Text(isEn ? 'Failed to delete: $e' : 'Gagal menghapus: $e'), 
                    backgroundColor: Colors.red,
                  ),
                );
              } finally {
                if (mounted) {
                  LoadingHelper.hide(currentContext);
                }
              }
            },
            child: Text(localization.translate('delete') ?? (isEn ? 'Delete' : 'Hapus')),
          ),
        ],
      ),
    );
  }

  void _showCustomerForm({Map<String, dynamic>? customerToEdit}) {
    final localization = AppLocalizations(widget.currentLanguage);
    final isEn = widget.currentLanguage == 'en';
    final nameController = TextEditingController(text: customerToEdit?['name'] ?? '');
    final phoneController = TextEditingController(text: customerToEdit?['phone'] ?? '');
    final addressController = TextEditingController(text: customerToEdit?['address'] ?? '');
    final currentContext = context;

    showModalBottomSheet(
      context: currentContext,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 20,
            left: 20,
            right: 20,
            top: 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                customerToEdit == null ? localization.translate('add_customer') : (localization.translate('edit_customer') ?? 'Edit Customer'),
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: localization.translate('customer_name'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: localization.translate('customer_phone'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: addressController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: localization.translate('customer_address'),
                  border: const OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1A237E),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () async {
                    if (nameController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text(localization.translate('name_cannot_be_empty') ?? 'Nama tidak boleh kosong'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    Navigator.pop(sheetContext);
                    LoadingHelper.show(currentContext, message: localization.translate('saving') ?? 'Menyimpan...');

                    try {
                      Map<String, dynamic> data = {
                        'name': nameController.text.trim(),
                        'phone': phoneController.text.trim(),
                        'address': addressController.text.trim(),
                      };

                      // Jika sedang mode edit, sertakan 'id'-nya agar dikenali sebagai update
                      if (customerToEdit != null && customerToEdit['id'] != null) {
                        data['id'] = customerToEdit['id'];
                      }
                      
                      // Panggil fungsi saveCustomer (menangani insert & update sekaligus)
                      await DatabaseHelper.instance.saveCustomer(data);
                      await _loadCustomers();

                      if (!mounted) return;
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(content: Text(localization.translate('customer_saved_success') ?? 'Pelanggan berhasil disimpan!')),
                      );
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(currentContext).showSnackBar(
                        SnackBar(
                          content: Text(isEn ? 'Failed to save: $e' : 'Gagal menyimpan: $e'), 
                          backgroundColor: Colors.red,
                        ),
                      );
                    } finally {
                      if (mounted) {
                        LoadingHelper.hide(currentContext);
                      }
                    }
                  },
                  child: Text(
                    localization.translate('save'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final localization = AppLocalizations(widget.currentLanguage);

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        title: Text(
          localization.translate('master_customer'),
          style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF1A237E)))
          : _customers.isEmpty
              ? Center(
                  child: Text(
                    localization.translate('no_customer_found'),
                    style: TextStyle(color: Colors.grey.shade600),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _customers.length,
                  itemBuilder: (context, index) {
                    final customer = _customers[index];
                    final id = customer['id'] as int?;
                    final name = customer['name']?.toString() ?? '';
                    final phone = customer['phone']?.toString() ?? '';
                    final address = customer['address']?.toString() ?? '';

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.shade100,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : 'C',
                            style: TextStyle(color: Colors.indigo.shade800, fontWeight: FontWeight.bold),
                          ),
                        ),
                        title: Text(
                          name,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(' $phone', style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
                            Text(' $address', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.grey),
                              onPressed: () => _showCustomerForm(customerToEdit: customer),
                            ),
                            if (id != null)
                              IconButton(
                                icon: const Icon(Icons.delete, color: Colors.red),
                                onPressed: () => _showDeleteConfirmation(id, name),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF1A237E),
        onPressed: () => _showCustomerForm(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}