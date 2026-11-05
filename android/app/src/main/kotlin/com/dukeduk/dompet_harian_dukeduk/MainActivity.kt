package com.dukeduk.dompet_harian_dukeduk

import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger,
            "com.dukeduk.dompet_harian_dukeduk/payment_reminders").setMethodCallHandler { call, result ->
            if (call.method != "replace") {
                result.notImplemented()
            } else {
                try {
                    val rows = JSONArray(call.arguments as? String ?: "[]")
                    PaymentReminderReceiver.replace(applicationContext, rows)
                    result.success(null)
                } catch (error: Exception) {
                    result.error("reminder_schedule_failed", error.message, null)
                }
            }
        }
    }
}
