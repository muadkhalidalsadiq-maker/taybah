package com.muadalsadiq.taybah

import android.app.AlarmManager
import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.os.Build
import android.os.SystemClock
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONObject
import java.util.Calendar
import java.util.TimeZone

/**
 * ودجت «الصلاة القادمة»: يقرأ مواقيت اليوم والغد التي يحفظها التطبيق،
 * ويحسب الصلاة القادمة والعد التنازلي بنفسه، ثم يجدول تحديثه التالي عند دخول الوقت.
 */
class PrayerWidgetProvider : HomeWidgetProvider() {

    private val keys = listOf("Fajr", "Sunrise", "Dhuhr", "Asr", "Maghrib", "Isha")
    private val names = mapOf(
        "Fajr" to "الفجر", "Sunrise" to "الشروق", "Dhuhr" to "الظهر",
        "Asr" to "العصر", "Maghrib" to "المغرب", "Isha" to "العشاء"
    )
    private val libya: TimeZone = TimeZone.getTimeZone("Africa/Tripoli")

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val today = parse(widgetData.getString("today", null))
        val tomorrow = parse(widgetData.getString("tomorrow", null))
        val city = widgetData.getString("city", "") ?: ""
        val now = System.currentTimeMillis()

        // الصلاة القادمة (الشروق ليس صلاة لكنه يظهر كتنبيه)
        var nextKey: String? = null
        var nextAt = 0L
        var nextStr: String? = null
        for (k in keys) {
            val t = at(today[k], 0) ?: continue
            if (t > now) { nextKey = k; nextAt = t; nextStr = today[k]; break }
        }
        if (nextKey == null) {
            nextKey = "Fajr"
            nextStr = tomorrow["Fajr"] ?: today["Fajr"]
            nextAt = at(nextStr, 1) ?: (now + 3600_000L)
        }

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.prayer_widget)
            views.setTextViewText(R.id.widget_city, city)
            views.setTextViewText(R.id.widget_name, names[nextKey] ?: "")
            views.setTextViewText(R.id.widget_time, to12h(nextStr))
            val base = SystemClock.elapsedRealtime() + (nextAt - now)
            views.setChronometer(R.id.widget_countdown, base, null, true)
            views.setChronometerCountDown(R.id.widget_countdown, true)

            views.setTextViewText(R.id.t_fajr, to12h(today["Fajr"]))
            views.setTextViewText(R.id.t_dhuhr, to12h(today["Dhuhr"]))
            views.setTextViewText(R.id.t_asr, to12h(today["Asr"]))
            views.setTextViewText(R.id.t_maghrib, to12h(today["Maghrib"]))
            views.setTextViewText(R.id.t_isha, to12h(today["Isha"]))

            val launch = HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java)
            views.setOnClickPendingIntent(R.id.widget_root, launch)
            appWidgetManager.updateAppWidget(id, views)
        }

        scheduleNextUpdate(context, nextAt + 30_000L)
    }

    private fun parse(raw: String?): Map<String, String> {
        if (raw.isNullOrEmpty()) return emptyMap()
        return try {
            val o = JSONObject(raw)
            keys.associateWith { o.optString(it, "") }
        } catch (e: Exception) {
            emptyMap()
        }
    }

    /** وقت "HH:mm" بتوقيت ليبيا لليوم (+ أيام) كلحظة زمنية. */
    private fun at(hhmm: String?, plusDays: Int): Long? {
        if (hhmm.isNullOrEmpty() || !hhmm.contains(":")) return null
        val p = hhmm.split(":")
        val h = p[0].trim().toIntOrNull() ?: return null
        val m = p[1].trim().take(2).toIntOrNull() ?: return null
        val c = Calendar.getInstance(libya)
        c.add(Calendar.DAY_OF_YEAR, plusDays)
        c.set(Calendar.HOUR_OF_DAY, h)
        c.set(Calendar.MINUTE, m)
        c.set(Calendar.SECOND, 0)
        c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    private fun to12h(hhmm: String?): String {
        if (hhmm.isNullOrEmpty() || !hhmm.contains(":")) return "--:--"
        val p = hhmm.split(":")
        val h = p[0].trim().toIntOrNull() ?: return hhmm
        val m = p[1].trim().take(2)
        val suffix = if (h < 12) "ص" else "م"
        val h12 = if (h % 12 == 0) 12 else h % 12
        return "$h12:$m $suffix"
    }

    private fun scheduleNextUpdate(context: Context, atMillis: Long) {
        val am = context.getSystemService(Context.ALARM_SERVICE) as AlarmManager
        val intent = Intent(context, PrayerWidgetProvider::class.java).apply {
            action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
            val ids = AppWidgetManager.getInstance(context)
                .getAppWidgetIds(ComponentName(context, PrayerWidgetProvider::class.java))
            putExtra(AppWidgetManager.EXTRA_APPWIDGET_IDS, ids)
        }
        val pi = PendingIntent.getBroadcast(
            context, 4711, intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val canExact = Build.VERSION.SDK_INT < Build.VERSION_CODES.S || am.canScheduleExactAlarms()
        try {
            if (canExact) {
                am.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            } else {
                am.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, atMillis, pi)
            }
        } catch (e: SecurityException) {
            am.set(AlarmManager.RTC, atMillis, pi)
        }
    }
}
