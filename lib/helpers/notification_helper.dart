import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class PaymentReminder {
  final String key;
  final String title;
  final String body;
  final DateTime dueDate;
  const PaymentReminder({
    required this.key,
    required this.title,
    required this.body,
    required this.dueDate,
  });
}

class NotificationHelper {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _initialized = false;
  static const _native = MethodChannel(
    'com.dukeduk.dompet_harian_dukeduk/payment_reminders',
  );

  static Future<void> init() async {
    if (_initialized ||
        kIsWeb ||
        defaultTargetPlatform != TargetPlatform.android) {
      return;
    }
    await _plugin.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@drawable/ic_notification'),
      ),
    );
    _initialized = true;
  }

  static Future<bool> requestPermission() async {
    await init();
    if (!_initialized) return false;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        false;
  }

  static Future<bool> notificationsEnabled() async {
    if (!_initialized) return false;
    return await _plugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.areNotificationsEnabled() ??
        false;
  }

  static Future<void> showTestNotification() async {
    if (!await requestPermission()) {
      throw StateError(
        'Izin notifikasi belum diberikan. Aktifkan di pengaturan aplikasi Android.',
      );
    }
    await _plugin.show(
      2147483646,
      'Notifikasi berhasil diaktifkan',
      'Pengingat cicilan akan ditampilkan sekitar pukul 08.00 sesuai jadwal.',
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'payment_reminder_channel',
          'Payment Reminders',
          channelDescription: 'Pengingat cicilan hutang dan piutang harian',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@drawable/ic_notification',
        ),
      ),
    );
  }

  static Future<void> cancelAll() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    await _native.invokeMethod<void>('replace', '[]');
    if (_initialized) await _plugin.cancelAll();
  }

  // One native inexact alarm checks all active unpaid bills at 08:00 every day.
  // No exact-alarm access, finite horizon, or running Flutter process is needed.
  static Future<void> replaceReminders(List<PaymentReminder> reminders) async {
    await init();
    if (!_initialized) return;
    // Clear the finite schedules and colliding IDs from previous app versions.
    await _plugin.cancelAll();
    await _native.invokeMethod<void>(
      'replace',
      jsonEncode(
        buildPlan(reminders, DateTime.now())
            .map(
              (entry) => {
                'key': entry.reminder.key,
                'title': entry.reminder.title,
                'body': entry.reminder.body,
                'startDate': entry.at.toIso8601String().split('T').first,
              },
            )
            .toList(),
      ),
    );
  }

  @visibleForTesting
  static List<({PaymentReminder reminder, DateTime at})> buildPlan(
    List<PaymentReminder> reminders,
    DateTime now,
  ) {
    final today = DateTime(now.year, now.month, now.day, 8);
    final next = today.isAfter(now)
        ? today
        : DateTime(now.year, now.month, now.day + 1, 8);
    return reminders.map((r) {
      final start = DateTime(
        r.dueDate.year,
        r.dueDate.month,
        r.dueDate.day - 3,
        8,
      );
      return (reminder: r, at: start.isAfter(next) ? start : next);
    }).toList()..sort((a, b) => a.at.compareTo(b.at));
  }
}
