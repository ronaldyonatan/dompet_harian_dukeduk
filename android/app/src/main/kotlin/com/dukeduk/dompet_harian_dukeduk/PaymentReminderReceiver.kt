package com.dukeduk.dompet_harian_dukeduk

import android.Manifest
import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import org.json.JSONArray
import java.util.Calendar

/** One inexact daily alarm, persisted independently of the Flutter process.
 * It continues until the user pays/disables the reminders, without a finite
 * scheduling horizon or the restricted exact-alarm permission. */
class PaymentReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        try {
            if (intent.action == ACTION_REMIND) showDueReminders(context)
        } finally {
            scheduleNext(context)
        }
    }

    companion object {
        private const val PREFS = "payment_reminders_v1"
        private const val ROWS = "rows"
        private const val CHANNEL = "payment_reminder_channel"
        private const val TAG = "payment_reminder"
        private const val REQUEST = 745821
        private const val ACTION_REMIND = "com.dukeduk.dompet_harian_dukeduk.PAYMENT_REMINDER"

        private fun read(context: Context): JSONArray = try {
            JSONArray(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(ROWS, "[]"))
        } catch (_: Exception) { JSONArray() }

        fun replace(context: Context, rows: JSONArray) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            for (i in 0 until read(context).length()) manager.cancel(TAG, i + 1)
            // commit() finishes before returning to Flutter; logout cannot leave
            // an old user's reminders behind after the process is terminated.
            check(context.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit()
                .putString(ROWS, rows.toString()).commit()) { "Gagal menyimpan jadwal pengingat" }
            scheduleNext(context)
        }

        private fun pending(context: Context): PendingIntent = PendingIntent.getBroadcast(
            context, REQUEST, Intent(context, PaymentReminderReceiver::class.java).setAction(ACTION_REMIND),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        internal fun nextEight(now: Calendar): Calendar = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, 8)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (!after(now)) add(Calendar.DAY_OF_YEAR, 1)
        }

        private fun dateKey(calendar: Calendar): String = String.format(
            java.util.Locale.ROOT, "%04d-%02d-%02d", calendar.get(Calendar.YEAR),
            calendar.get(Calendar.MONTH) + 1, calendar.get(Calendar.DAY_OF_MONTH)
        )

        fun scheduleNext(context: Context) {
            val alarm = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
            val pending = pending(context)
            alarm.cancel(pending)
            if (read(context).length() == 0) return
            // Calendar uses the device's current timezone, including after a
            // timezone change. Inexact delivery may be delayed by Android Doze.
            alarm.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP,
                nextEight(Calendar.getInstance()).timeInMillis, pending)
        }

        private fun showDueReminders(context: Context) {
            val rows = read(context)
            if (rows.length() == 0) return
            if (Build.VERSION.SDK_INT >= 33 && context.checkSelfPermission(
                    Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) return
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            if (Build.VERSION.SDK_INT >= 26) {
                manager.createNotificationChannel(NotificationChannel(CHANNEL,
                    "Payment Reminders", NotificationManager.IMPORTANCE_HIGH).apply {
                    description = "Pengingat cicilan hutang dan piutang harian"
                })
            }
            val today = dateKey(Calendar.getInstance())
            val launch = PendingIntent.getActivity(context, 0,
                Intent(context, MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP),
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE)
            for (i in 0 until rows.length()) {
                val row = rows.optJSONObject(i) ?: continue
                val start = row.optString("startDate")
                if (start.isEmpty() || start > today) continue
                val builder = if (Build.VERSION.SDK_INT >= 26) Notification.Builder(context, CHANNEL)
                    else @Suppress("DEPRECATION") Notification.Builder(context)
                val notification = builder.setSmallIcon(R.drawable.ic_notification)
                    .setContentTitle(row.optString("title"))
                    .setContentText(row.optString("body"))
                    .setStyle(Notification.BigTextStyle().bigText(row.optString("body")))
                    .setContentIntent(launch).setAutoCancel(true)
                    .setCategory(Notification.CATEGORY_REMINDER).build()
                try { manager.notify(TAG, i + 1, notification) }
                catch (_: SecurityException) { /* Permission may be revoked while posting. */ }
            }
        }
    }
}
