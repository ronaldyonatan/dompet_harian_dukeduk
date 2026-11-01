class ReceivableModel {
  final int? id;
  final int? itemId;              // Relasi ke Master Item (opsional)[cite: 9]
  final int? customerId;          // Relasi ke Master Customer (Debitur)
  final String debtorName;        // Nama peminjam / pihak yang berhutang[cite: 9]
  final double amount;            // Total nilai piutang[cite: 9]
  final String startDate;         // Tanggal mulai (format: 'YYYY-MM-DD')[cite: 9]
  final int installmentMonths;    // Lama cicilan (dalam bulan)[cite: 9]
  final double monthlyInstallment;// Cicilan per bulan[cite: 9]
  final String firstDueDate;      // Tanggal jatuh tempo pertama[cite: 9]
  final bool isReminderActive;    // Status reminder[cite: 9]
  final bool isRealized;          // Status realisasi ke transaksi[cite: 9]

  ReceivableModel({
    this.id,
    this.itemId,
    this.customerId,
    required this.debtorName,
    required this.amount,
    required this.startDate,
    required this.installmentMonths,
    required this.monthlyInstallment,
    required this.firstDueDate,
    this.isReminderActive = true,
    this.isRealized = false,
  });

  factory ReceivableModel.fromMap(Map<String, dynamic> map) {
    return ReceivableModel(
      id: map['id'],
      itemId: map['item_id'] ?? map['itemId'],
      customerId: map['customer_id'] ?? map['customerId'],
      debtorName: map['debtor_name'] ?? map['debtorName'] ?? '',
      amount: map['amount'] is int ? (map['amount'] as int).toDouble() : (map['amount'] ?? 0.0),
      startDate: map['start_date'] ?? map['startDate'] ?? '',
      installmentMonths: map['installment_months'] ?? map['installmentMonths'] ?? 1,
      monthlyInstallment: map['monthly_installment'] is int ? (map['monthly_installment'] as int).toDouble() : (map['monthly_installment'] ?? 0.0),
      firstDueDate: map['first_due_date'] ?? map['firstDueDate'] ?? '',
      isReminderActive: map['is_reminder_active'] == 1 || map['is_reminder_active'] == true,
      isRealized: map['is_realized'] == 1 || map['is_realized'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'customer_id': customerId,
      'debtor_name': debtorName,
      'amount': amount,
      'start_date': startDate,
      'installment_months': installmentMonths,
      'monthly_installment': monthlyInstallment,
      'first_due_date': firstDueDate,
      'is_reminder_active': isReminderActive ? 1 : 0,
      'is_realized': isRealized ? 1 : 0,
    };
  }

  ReceivableModel copyWith({
    int? id,
    int? itemId,
    int? customerId,
    String? debtorName,
    double? amount,
    String? startDate,
    int? installmentMonths,
    double? monthlyInstallment,
    String? firstDueDate,
    bool? isReminderActive,
    bool? isRealized,
  }) {
    return ReceivableModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      customerId: customerId ?? this.customerId,
      debtorName: debtorName ?? this.debtorName,
      amount: amount ?? this.amount,
      startDate: startDate ?? this.startDate,
      installmentMonths: installmentMonths ?? this.installmentMonths,
      monthlyInstallment: monthlyInstallment ?? this.monthlyInstallment,
      firstDueDate: firstDueDate ?? this.firstDueDate,
      isReminderActive: isReminderActive ?? this.isReminderActive,
      isRealized: isRealized ?? this.isRealized,
    );
  }
}