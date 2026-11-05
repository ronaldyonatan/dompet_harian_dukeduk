/// Calendar-month arithmetic clamps month ends (31 Jan -> 28/29 Feb).
DateTime installmentDueDate(DateTime first, int offset) {
  final month = DateTime(first.year, first.month + offset);
  final lastDay = DateTime(month.year, month.month + 1, 0).day;
  return DateTime(
    month.year,
    month.month,
    first.day > lastDay ? lastDay : first.day,
  );
}

List<Map<String, dynamic>> buildInstallments({
  required int parentId,
  required DateTime firstDueDate,
  required int months,
  required double monthlyAmount,
  required List<Map<String, dynamic>> existing,
}) {
  if (months < 1 ||
      months > 600 ||
      monthlyAmount <= 0 ||
      !monthlyAmount.isFinite) {
    throw ArgumentError(
      'Tenor harus 1–600 bulan dan nominal cicilan harus lebih dari nol.',
    );
  }
  final paid = {
    for (final row in existing.where((r) => r['is_paid'] == true))
      row['installment_number']: row,
  };
  if (paid.keys.any((n) => (n as int) > months)) {
    throw ArgumentError(
      'Tenor tidak boleh menghapus cicilan yang sudah dibayar.',
    );
  }
  return List.generate(months, (index) {
    final number = index + 1;
    // Preserve the amount, actual due date and payment history of paid bills.
    return paid[number] ??
        {
          'parent_id': parentId,
          'installment_number': number,
          'amount': monthlyAmount,
          'due_date': installmentDueDate(
            firstDueDate,
            index,
          ).toIso8601String().split('T')[0],
          'is_paid': false,
          'paid_date': null,
        };
  });
}
