import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class NotificationHelper {
  static final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await _notificationsPlugin.initialize(initializationSettings);
  }

  // Fungsi untuk menjadwalkan reminder dari H-3 sampai lunas (secara harian)
  static Future<void> schedulePaymentReminder({
    required int id,
    required String title,
    required String body,
    required DateTime dueDate,
  }) async {
    // Waktu mulai reminder: H-3 dari tanggal jatuh tempo (jam 08:00 pagi)
    DateTime hMinus3 = dueDate.subtract(const Duration(days: 3));
    hMinus3 = DateTime(hMinus3.year, hMinus3.month, hMinus3.day, 11, 0, 0);

    // Jika H-3 sudah lewat dari hari ini, mulai dari hari ini jam 08:00
    DateTime startTime = hMinus3.isBefore(DateTime.now()) 
        ? DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 8, 0, 0)
        : hMinus3;

    // Jadwalkan pengulangan harian sampai tanggal jatuh tempo (atau lewat dari jatuh tempo)
    // Kita buat loop harian selama beberapa hari ke depan (misal: 10 hari berturut-turut atau hingga hari H+7)
    for (int i = 0; i <= 10; i++) {
      DateTime scheduledDate = startTime.add(Duration(days: i));
      
      // Jangan jadwalkan jika waktunya di masa lalu
      if (scheduledDate.isBefore(DateTime.now())) continue;

      int notificationId = id * 100 + i; // Unique ID per reminder

      AndroidNotificationDetails androidDetails = const AndroidNotificationDetails(
        'payment_reminder_channel',
        'Payment Reminders',
        channelDescription: 'Pengingat cicilan hutang dan piutang harian',
        importance: Importance.max,
        priority: Priority.high,
      );

      NotificationDetails platformDetails = NotificationDetails(android: androidDetails);

      await _notificationsPlugin.zonedSchedule(
        notificationId,
        title,
        body,
        tz.TZDateTime.from(scheduledDate, tz.local),
        platformDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  // Fungsi untuk membatalkan reminder jika sudah lunas/teralisasi
  static Future<void> cancelReminder(int id) async {
    for (int i = 0; i <= 10; i++) {
      int notificationId = id * 100 + i;
      await _notificationsPlugin.cancel(notificationId);
    }
  }
}