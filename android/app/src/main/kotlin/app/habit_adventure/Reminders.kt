package app.habit_adventure

import android.app.AlarmManager
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.os.Build
import org.json.JSONArray
import org.json.JSONObject

/**
 * The only notification the app sends (DESIGN §6.1, §14): an optional local
 * reminder the user sets on a quest. Off unless set.
 *
 * The Dart side plans up to a week of reminders each time the app is opened
 * and hands the whole plan over; this side keeps the plan, sets one inexact
 * alarm per reminder, and shows the notification when an alarm goes off.
 * After a restart of the device the kept plan is set again. If the app is
 * not opened for a week the reminders simply stop. They never pile up.
 */
object Reminders {
    private const val PREFS = "reminders"
    private const val KEY_PLAN = "plan"
    private const val CHANNEL_ID = "quest_reminders"
    const val ACTION = "app.habit_adventure.REMINDER"

    private fun prefs(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    private fun plan(context: Context): JSONArray = try {
        JSONArray(prefs(context).getString(KEY_PLAN, "[]"))
    } catch (e: Exception) {
        JSONArray()
    }

    private fun alarmIntent(context: Context, id: Int, title: String, body: String): PendingIntent =
        PendingIntent.getBroadcast(
            context,
            id,
            Intent(context, ReminderReceiver::class.java)
                .setAction(ACTION)
                .putExtra("id", id)
                .putExtra("title", title)
                .putExtra("body", body),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )

    /** Replaces the whole plan with [items]: maps of id, at, title, body. */
    fun sync(context: Context, items: List<*>) {
        cancelAll(context)
        val next = JSONArray()
        for (item in items) {
            if (item !is Map<*, *>) continue
            val id = (item["id"] as? Number)?.toInt() ?: continue
            val at = (item["at"] as? Number)?.toLong() ?: continue
            next.put(
                JSONObject()
                    .put("id", id)
                    .put("at", at)
                    .put("title", item["title"] as? String ?: "")
                    .put("body", item["body"] as? String ?: "")
            )
        }
        prefs(context).edit().putString(KEY_PLAN, next.toString()).apply()
        scheduleAll(context)
    }

    private fun cancelAll(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val old = plan(context)
        for (i in 0 until old.length()) {
            val o = old.optJSONObject(i) ?: continue
            alarms.cancel(alarmIntent(context, o.optInt("id"), o.optString("title"), o.optString("body")))
        }
    }

    /** Sets an alarm for every planned reminder still ahead. */
    fun scheduleAll(context: Context) {
        val alarms = context.getSystemService(AlarmManager::class.java) ?: return
        val now = System.currentTimeMillis()
        val items = plan(context)
        for (i in 0 until items.length()) {
            val o = items.optJSONObject(i) ?: continue
            val at = o.optLong("at")
            if (at <= now) continue
            // Inexact on purpose: a reminder may arrive a few minutes late, and
            // the app needs no special alarm permission.
            alarms.setAndAllowWhileIdle(
                AlarmManager.RTC_WAKEUP,
                at,
                alarmIntent(context, o.optInt("id"), o.optString("title"), o.optString("body")),
            )
        }
    }

    fun show(context: Context, id: Int, title: String, body: String) {
        val manager = context.getSystemService(NotificationManager::class.java) ?: return
        val open = PendingIntent.getActivity(
            context,
            0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        val builder = if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(
                NotificationChannel(
                    CHANNEL_ID,
                    "Quest reminders",
                    NotificationManager.IMPORTANCE_DEFAULT,
                ).apply { description = "The optional reminder you set on a quest." }
            )
            Notification.Builder(context, CHANNEL_ID)
        } else {
            @Suppress("DEPRECATION")
            Notification.Builder(context)
        }
        val notification = builder
            .setSmallIcon(R.drawable.ic_stat_lantern)
            .setContentTitle(title)
            .setContentText(body)
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        try {
            manager.notify(id, notification)
        } catch (e: SecurityException) {
            // Notifications are not allowed: the reminder is simply not shown.
        }
    }
}

/** Receives the reminder alarms, and sets them again after a restart. */
class ReminderReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        when (intent.action) {
            Intent.ACTION_BOOT_COMPLETED -> Reminders.scheduleAll(context)
            Reminders.ACTION -> Reminders.show(
                context,
                intent.getIntExtra("id", 0),
                intent.getStringExtra("title") ?: "",
                intent.getStringExtra("body") ?: "",
            )
        }
    }
}
