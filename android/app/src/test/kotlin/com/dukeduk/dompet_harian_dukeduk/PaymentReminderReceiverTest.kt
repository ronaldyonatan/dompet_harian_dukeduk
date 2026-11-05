package com.dukeduk.dompet_harian_dukeduk

import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

class PaymentReminderReceiverTest {
    private fun clock(hour: Int, minute: Int = 0): Calendar =
        Calendar.getInstance(TimeZone.getTimeZone("Asia/Jakarta")).apply {
            clear()
            set(2026, Calendar.NOVEMBER, 1, hour, minute)
        }

    @Test fun beforeEightSchedulesToday() {
        val next = PaymentReminderReceiver.nextEight(clock(7, 59))
        assertEquals(1, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
        assertEquals(0, next.get(Calendar.MINUTE))
    }

    @Test fun afterEightSchedulesTomorrow() {
        val next = PaymentReminderReceiver.nextEight(clock(9))
        assertEquals(2, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
    }

    @Test fun exactEightDoesNotImmediatelyRepeatTheSameAlarm() {
        val next = PaymentReminderReceiver.nextEight(clock(8))
        assertEquals(2, next.get(Calendar.DAY_OF_MONTH))
    }

    @Test fun monthBoundaryAndTimezoneRemainLocal() {
        val now = clock(23, 59).apply { set(Calendar.DAY_OF_MONTH, 30) }
        val next = PaymentReminderReceiver.nextEight(now)
        assertEquals(Calendar.DECEMBER, next.get(Calendar.MONTH))
        assertEquals(1, next.get(Calendar.DAY_OF_MONTH))
        assertEquals(now.timeZone, next.timeZone)
        assertEquals(8, next.get(Calendar.HOUR_OF_DAY))
    }
}
