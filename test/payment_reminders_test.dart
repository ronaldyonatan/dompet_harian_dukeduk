import 'package:flutter_test/flutter_test.dart';
import 'package:dompet_harian_dukeduk/helpers/notification_helper.dart';

PaymentReminder bill(String key, DateTime due) =>
    PaymentReminder(key: key, title: key, body: 'Pengingat', dueDate: due);

void main() {
  test('starts on H-3 at 08:00 and never schedules in the past', () {
    final now = DateTime(2026, 11, 1, 9);
    final plan = NotificationHelper.buildPlan([
      bill('debt:1', DateTime(2026, 11, 10)),
    ], now);
    expect(plan.first.at, DateTime(2026, 11, 7, 8));
    expect(plan.every((e) => e.at.isAfter(now) && e.at.hour == 8), isTrue);
  });

  test('overdue bill still has a next reminder years after its due date', () {
    final reminders = [bill('debt:1', DateTime(2026, 10, 1))];
    expect(
      NotificationHelper.buildPlan(
        reminders,
        DateTime(2026, 11, 1, 7),
      ).single.at,
      DateTime(2026, 11, 1, 8),
    );
    expect(
      NotificationHelper.buildPlan(
        reminders,
        DateTime(2030, 1, 1, 9),
      ).single.at,
      DateTime(2030, 1, 2, 8),
    );
  });

  test('debt and receivable with the same record ID both remain scheduled', () {
    final plan = NotificationHelper.buildPlan([
      bill('user:debt:1', DateTime(2026, 11, 1)),
      bill('user:receivable:1', DateTime(2026, 11, 1)),
    ], DateTime(2026, 11, 1, 7));
    expect(plan.take(2).map((e) => e.reminder.key).toSet().length, 2);
  });

  test('no finite pending-alarm limit truncates a large reminder list', () {
    final plan = NotificationHelper.buildPlan(
      List.generate(500, (i) => bill('debt:$i', DateTime(2026, 11, 1))),
      DateTime(2026, 11, 1, 9),
    );
    expect(plan.length, 500);
    expect(plan.every((entry) => entry.at == DateTime(2026, 11, 2, 8)), isTrue);
  });

  test('empty paid-off list leaves no reminders', () {
    expect(NotificationHelper.buildPlan([], DateTime(2026, 11, 1)), isEmpty);
  });
}
