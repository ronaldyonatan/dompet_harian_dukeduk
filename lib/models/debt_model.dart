class DebtModel {
  final int? id;
  final int? itemId;              // Relasi ke Master Item (opsional)
  final int? lenderId;            // Relasi ke Master Lender (Pemberi Pinjaman)[cite: 8]
  final String lenderName;        // Nama pemberi hutang[cite: 8]
  final double amount;            // Total nilai pinjaman[cite: 8]
  final String startDate;         // Tanggal mulai pinjaman (format: 'YYYY-MM-DD')[cite: 8]
  final int installmentMonths;    // Lama cicilan (dalam bulan)[cite: 8]
  final double monthlyInstallment;// Cicilan per bulan[cite: 8]
  final String firstDueDate;      // Tanggal jatuh tempo pertama (format: 'YYYY-MM-DD')[cite: 8]
  final bool isReminderActive;    // Status aktif/non-aktif pop-up reminder pembayaran[cite: 8]
  final bool isRealized;          // Status apakah sudah direalisasikan ke transaksi[cite: 8]

  DebtModel({
    this.id,
    this.itemId,
    this.lenderId,
    required this.lenderName,
    required this.amount,
    required this.startDate,
    required this.installmentMonths,
    required this.monthlyInstallment,
    required this.firstDueDate,
    this.isReminderActive = true,  
    this.isRealized = false,       
  });

  factory DebtModel.fromMap(Map<String, dynamic> map) {
    return DebtModel(
      id: map['id'],
      itemId: map['item_id'] ?? map['itemId'],
      lenderId: map['lender_id'] ?? map['lenderId'],
      lenderName: map['lender_name'] ?? map['lenderName'] ?? '',
      amount: map['amount'] is int 
          ? (map['amount'] as int).toDouble() 
          : (map['amount'] ?? 0.0),
      startDate: map['start_date'] ?? map['startDate'] ?? '',
      installmentMonths: map['installment_months'] ?? map['installmentMonths'] ?? 1,
      monthlyInstallment: map['monthly_installment'] is int 
          ? (map['monthly_installment'] as int).toDouble() 
          : (map['monthly_installment'] ?? 0.0),
      firstDueDate: map['first_due_date'] ?? map['firstDueDate'] ?? '',
      isReminderActive: map['is_reminder_active'] == 1 || map['is_reminder_active'] == true,
      isRealized: map['is_realized'] == 1 || map['is_realized'] == true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'item_id': itemId,
      'lender_id': lenderId,
      'lender_name': lenderName,
      'amount': amount,
      'start_date': startDate,
      'installment_months': installmentMonths,
      'monthly_installment': monthlyInstallment,
      'first_due_date': firstDueDate,
      'is_reminder_active': isReminderActive ? 1 : 0,
      'is_realized': isRealized ? 1 : 0,
    };
  }

  DebtModel copyWith({
    int? id,
    int? itemId,
    int? lenderId,
    String? lenderName,
    double? amount,
    String? startDate,
    int? installmentMonths,
    double? monthlyInstallment,
    String? firstDueDate,
    bool? isReminderActive,
    bool? isRealized,
  }) {
    return DebtModel(
      id: id ?? this.id,
      itemId: itemId ?? this.itemId,
      lenderId: lenderId ?? this.lenderId,
      lenderName: lenderName ?? this.lenderName,
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