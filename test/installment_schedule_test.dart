import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_harian_dukeduk/helpers/installment_schedule.dart';

void main() {
  test('month end clamps February and preserves original anchor in March', () {
    final first = DateTime(2027, 1, 31);
    expect(installmentDueDate(first, 1), DateTime(2027, 2, 28));
    expect(installmentDueDate(first, 2), DateTime(2027, 3, 31));
    expect(installmentDueDate(DateTime(2028, 1, 31), 1), DateTime(2028, 2, 29));
  });

  test(
    'edit keeps paid amount, date and history while changing unpaid bills',
    () {
      final paid = <String, dynamic>{
        'parent_id': 1,
        'installment_number': 1,
        'amount': 100.0,
        'due_date': '2026-10-31',
        'is_paid': true,
        'paid_date': '2026-10-30',
      };
      final rows = buildInstallments(
        parentId: 1,
        firstDueDate: DateTime(2026, 11, 30),
        months: 3,
        monthlyAmount: 200,
        existing: [paid],
      );
      expect(rows.first, paid);
      expect(rows[1]['is_paid'], false);
      expect(rows[1]['amount'], 200);
      expect(rows[1]['due_date'], '2026-12-30');
    },
  );

  test('shortening term cannot remove a paid installment', () {
    expect(
      () => buildInstallments(
        parentId: 1,
        firstDueDate: DateTime(2026, 11, 1),
        months: 1,
        monthlyAmount: 100,
        existing: [
          {'installment_number': 2, 'is_paid': true},
        ],
      ),
      throwsArgumentError,
    );
  });

  test('invalid tenor and amounts are rejected before a write', () {
    for (final months in [0, -1, 601]) {
      expect(
        () => buildInstallments(
          parentId: 1,
          firstDueDate: DateTime(2026, 11, 1),
          months: months,
          monthlyAmount: 100,
          existing: [],
        ),
        throwsArgumentError,
      );
    }
    for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
      expect(
        () => buildInstallments(
          parentId: 1,
          firstDueDate: DateTime(2026, 11, 1),
          months: 1,
          monthlyAmount: amount,
          existing: [],
        ),
        throwsArgumentError,
      );
    }
  });
}
