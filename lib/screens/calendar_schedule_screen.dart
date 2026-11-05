import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';

import '../helpers/database_helper.dart';
import '../helpers/Loading_Helper.dart';
import '../models/finance_model.dart' as finance;

class CalendarScheduleScreen extends StatefulWidget {
  final String currentLanguage;

  const CalendarScheduleScreen({super.key, required this.currentLanguage});

  @override
  State<CalendarScheduleScreen> createState() => _CalendarScheduleScreenState();
}

class _CalendarScheduleScreenState extends State<CalendarScheduleScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  CalendarFormat _calendarFormat = CalendarFormat.month;

  bool _isLoading = true;
  List<Map<String, dynamic>> _allInstallments = [];
  List<finance.Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final installments = await DatabaseHelper.instance
          .getAllScheduleInstallments();
      final categories = await DatabaseHelper.instance.getCategories();
      if (mounted) {
        setState(() {
          _allInstallments = installments;
          _categories = categories;
        });
      }
    } catch (e) {
      debugPrint('Error loading schedule data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  List<Map<String, dynamic>> _getInstallmentsForDay(DateTime day) {
    final dayStr = day.toIso8601String().split('T')[0];
    return _allInstallments
        .where((inst) => inst['due_date'] == dayStr)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEn = widget.currentLanguage == 'en';
    final currencyFormatter = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp ',
      decimalDigits: 0,
    );
    final selectedDayInstallments = _getInstallmentsForDay(_selectedDay);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1A237E),
        elevation: 0,
        title: Text(
          isEn ? 'Schedule Calendar' : 'Kalender Tagihan & Cicilan',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1A237E)),
            )
          : Column(
              children: [
                Container(
                  color: Colors.white,
                  child: TableCalendar(
                    firstDay: DateTime(2020),
                    lastDay: DateTime(DateTime.now().year + 50, 12, 31),
                    focusedDay: _focusedDay,
                    calendarFormat: _calendarFormat,
                    selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                    onDaySelected: (selectedDay, focusedDay) {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                    },
                    onFormatChanged: (format) {
                      setState(() {
                        _calendarFormat = format;
                      });
                    },
                    onPageChanged: (focusedDay) {
                      _focusedDay = focusedDay;
                    },
                    eventLoader: _getInstallmentsForDay,
                    calendarStyle: const CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.indigoAccent,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Color(0xFF1A237E),
                        shape: BoxShape.circle,
                      ),
                      markerDecoration: BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, date, events) {
                        if (events.isEmpty) return null;

                        bool hasDebt = events.any(
                          (e) =>
                              (e as Map<String, dynamic>)['type'] == 'debt' &&
                              e['is_paid'] != true,
                        );
                        bool hasReceivable = events.any(
                          (e) =>
                              (e as Map<String, dynamic>)['type'] ==
                                  'receivable' &&
                              e['is_paid'] != true,
                        );

                        return Positioned(
                          bottom: 1,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasDebt)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.red,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasReceivable)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 1,
                                  ),
                                  decoration: const BoxDecoration(
                                    color: Colors.green,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isEn
                            ? 'Schedule on ${_selectedDay.toIso8601String().split('T')[0]}'
                            : 'Jadwal Tanggal: ${_selectedDay.toIso8601String().split('T')[0]}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        '${selectedDayInstallments.length} ${isEn ? "items" : "agenda"}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: selectedDayInstallments.isEmpty
                      ? Center(
                          child: Text(
                            isEn
                                ? 'No installments due on this date.'
                                : 'Tidak ada jadwal tagihan pada tanggal ini.',
                            style: const TextStyle(
                              color: Colors.grey,
                              fontSize: 13,
                            ),
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemCount: selectedDayInstallments.length,
                          itemBuilder: (context, index) {
                            final inst = selectedDayInstallments[index];
                            final String type = inst['type'];
                            final String name = inst['name'] ?? '-';
                            final int instNo = inst['installment_number'];
                            final double amount = (inst['amount'] is int)
                                ? (inst['amount'] as int).toDouble()
                                : inst['amount'];
                            final bool isPaid = inst['is_paid'] == true;
                            final bool isDebt = type == 'debt';

                            return Container(
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isPaid
                                      ? Colors.green.shade200
                                      : (isDebt
                                            ? Colors.red.shade200
                                            : Colors.green.shade200),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.02),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: isDebt
                                                    ? Colors.red.shade50
                                                    : Colors.green.shade50,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                isDebt
                                                    ? (isEn ? 'DEBT' : 'HUTANG')
                                                    : (isEn
                                                          ? 'RECEIVABLE'
                                                          : 'PIUTANG'),
                                                style: TextStyle(
                                                  fontSize: 9,
                                                  fontWeight: FontWeight.bold,
                                                  color: isDebt
                                                      ? Colors.red.shade700
                                                      : Colors.green.shade700,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(
                                                name,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 14,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          '${isEn ? "Installment" : "Cicilan"} #$instNo - ${currencyFormatter.format(amount)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                            color: Color(0xFF0F172A),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  isPaid
                                      ? Chip(
                                          label: Text(
                                            isEn ? 'Paid' : 'Lunas',
                                            style: TextStyle(
                                              color: Colors.green.shade800,
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
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 8,
                                            ),
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                          ),
                                          onPressed: isPaid
                                              ? null
                                              : () async {
                                                  final confirmed = await showDialog<bool>(
                                                    context: context,
                                                    builder: (ctx) => AlertDialog(
                                                      title: Text(
                                                        isEn
                                                            ? 'Confirm Action'
                                                            : 'Konfirmasi Aksi',
                                                      ),
                                                      content: Text(
                                                        isDebt
                                                            ? (isEn
                                                                  ? 'Pay installment #$instNo to "$name" of ${currencyFormatter.format(amount)}?'
                                                                  : 'Bayar cicilan ke-$instNo kepada "$name" sebesar ${currencyFormatter.format(amount)}?')
                                                            : (isEn
                                                                  ? 'Receive payment #$instNo from "$name" of ${currencyFormatter.format(amount)}?'
                                                                  : 'Terima cicilan ke-$instNo dari "$name" sebesar ${currencyFormatter.format(amount)}?'),
                                                      ),
                                                      actions: [
                                                        TextButton(
                                                          onPressed: () =>
                                                              Navigator.pop(
                                                                ctx,
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
                                                                ctx,
                                                                true,
                                                              ),
                                                          child: Text(
                                                            isEn
                                                                ? 'Confirm'
                                                                : 'Ya, Proses',
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  );

                                                  if (confirmed != true) return;

                                                  if (!mounted) return;
                                                  LoadingHelper.show(
                                                    context,
                                                    message: isEn
                                                        ? 'Processing...'
                                                        : 'Memproses...',
                                                  );

                                                  try {
                                                    final defaultCat =
                                                        _categories.isNotEmpty
                                                        ? (_categories
                                                                  .first
                                                                  .id ??
                                                              1)
                                                        : 1;

                                                    await DatabaseHelper
                                                        .instance
                                                        .payInstallment(
                                                          inst['parent_id'],
                                                          instNo,
                                                          defaultCat,
                                                          type,
                                                          isDebt
                                                              ? 'Bayar Hutang: $name'
                                                              : 'Terima Piutang: $name',
                                                        );

                                                    await _loadData();

                                                    if (!mounted) return;
                                                    ScaffoldMessenger.of(
                                                      context,
                                                    ).showSnackBar(
                                                      SnackBar(
                                                        content: Text(
                                                          isEn
                                                              ? 'Payment recorded successfully!'
                                                              : 'Pembayaran cicilan berhasil dicatat!',
                                                        ),
                                                        backgroundColor:
                                                            Colors.green,
                                                      ),
                                                    );
                                                  } catch (e) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        SnackBar(
                                                          content: Text(
                                                            'Error: $e',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                  } finally {
                                                    if (mounted) {
                                                      LoadingHelper.hide(
                                                        context,
                                                      );
                                                    }
                                                  }
                                                },
                                          child: Text(
                                            isDebt
                                                ? (isEn ? 'Pay' : 'Bayar')
                                                : (isEn ? 'Receive' : 'Terima'),
                                            style: const TextStyle(
                                              fontSize: 11,
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
  }
}
