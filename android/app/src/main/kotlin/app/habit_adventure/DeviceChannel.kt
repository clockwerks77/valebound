package app.habit_adventure

import android.Manifest
import android.app.NotificationManager
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.health.connect.AggregateRecordsRequest
import android.health.connect.AggregateRecordsResponse
import android.health.connect.HealthConnectException
import android.health.connect.HealthConnectManager
import android.health.connect.TimeInstantRangeFilter
import android.health.connect.datatypes.StepsRecord
import android.os.Build
import android.os.OutcomeReceiver
import android.provider.CalendarContract
import androidx.annotation.RequiresApi
import io.flutter.embedding.android.FlutterActivity
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import java.time.Instant
import java.util.Calendar
import java.util.TimeZone

/**
 * The app's door to the device calendar, Health Connect steps and the one
 * local reminder (DESIGN §9.3, §6.1).
 *
 * Everything here is optional and read-only towards the device: calendar
 * events are read and never changed; steps are read and never written. Each
 * permission is asked for only when the user chooses the feature. There is
 * no network code here or anywhere else in the app.
 */
class DeviceChannel(private val activity: FlutterActivity) {
    companion object {
        const val CHANNEL = "app.habit_adventure/device"
        const val REQUEST_CALENDAR = 4201
        const val REQUEST_STEPS = 4202
        const val REQUEST_NOTIFICATIONS = 4203
        const val READ_STEPS = "android.permission.health.READ_STEPS"
        const val POST_NOTIFICATIONS = "android.permission.POST_NOTIFICATIONS"
        const val VIEW_PERMISSION_USAGE = "android.intent.action.VIEW_PERMISSION_USAGE"
    }

    private var pending: MethodChannel.Result? = null
    private var pendingCode = 0
    private var launchReason: String? = null

    /** Remembers when the app was opened from Health Connect's "why" link. */
    fun noteIntent(intent: Intent?) {
        if (intent?.action == VIEW_PERMISSION_USAGE) launchReason = "health_rationale"
    }

    fun handle(call: MethodCall, result: MethodChannel.Result) {
        try {
            when (call.method) {
                "calendarGranted" -> result.success(calendarGranted())
                "requestCalendar" ->
                    if (calendarGranted()) {
                        result.success(true)
                    } else {
                        ask(result, Manifest.permission.READ_CALENDAR, REQUEST_CALENDAR)
                    }
                "calendars" -> inBackground(result) { calendars() }
                "events" -> {
                    val start = (call.argument<Number>("start") ?: 0).toLong()
                    val end = (call.argument<Number>("end") ?: 0).toLong()
                    inBackground(result) { events(start, end) }
                }
                "stepsAccess" -> result.success(stepsAccess())
                "requestSteps" ->
                    if (stepsAccess() != "notConnected") {
                        result.success(stepsAccess())
                    } else {
                        ask(result, READ_STEPS, REQUEST_STEPS)
                    }
                "steps" -> {
                    val start = (call.argument<Number>("start") ?: 0).toLong()
                    val end = (call.argument<Number>("end") ?: 0).toLong()
                    if (Build.VERSION.SDK_INT >= 34 && stepsAccess() == "connected" && end > start) {
                        readSteps(start, end, result)
                    } else {
                        result.success(null)
                    }
                }
                "notificationsAllowed" -> result.success(notificationsAllowed())
                "requestNotifications" ->
                    if (Build.VERSION.SDK_INT >= 33 &&
                        activity.checkSelfPermission(POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
                    ) {
                        ask(result, POST_NOTIFICATIONS, REQUEST_NOTIFICATIONS)
                    } else {
                        result.success(notificationsAllowed())
                    }
                "syncReminders" -> {
                    val items = call.argument<List<*>>("reminders") ?: emptyList<Any>()
                    Reminders.sync(activity.applicationContext, items)
                    result.success(true)
                }
                "takeLaunchReason" -> {
                    val reason = launchReason
                    launchReason = null
                    result.success(reason)
                }
                else -> result.notImplemented()
            }
        } catch (e: Exception) {
            result.error("device", e.message, null)
        }
    }

    private fun inBackground(result: MethodChannel.Result, work: () -> Any?) {
        Thread {
            val value = try {
                work()
            } catch (e: Exception) {
                null
            }
            activity.runOnUiThread { result.success(value) }
        }.start()
    }

    // ---- permissions ----------------------------------------------------

    private fun ask(result: MethodChannel.Result, permission: String, code: Int) {
        if (pending != null) {
            // One question at a time: answer with how things stand.
            result.success(answerFor(code))
            return
        }
        pending = result
        pendingCode = code
        try {
            activity.requestPermissions(arrayOf(permission), code)
        } catch (e: Exception) {
            pending = null
            result.success(answerFor(code))
        }
    }

    private fun answerFor(code: Int): Any = when (code) {
        REQUEST_CALENDAR -> calendarGranted()
        REQUEST_STEPS -> stepsAccess()
        else -> notificationsAllowed()
    }

    /** True if [requestCode] was one of ours. */
    fun onPermissionsResult(requestCode: Int): Boolean {
        if (requestCode != REQUEST_CALENDAR && requestCode != REQUEST_STEPS &&
            requestCode != REQUEST_NOTIFICATIONS
        ) {
            return false
        }
        val result = pending
        pending = null
        if (result != null && pendingCode == requestCode) result.success(answerFor(requestCode))
        return true
    }

    // ---- calendar (read only) ---------------------------------------------

    private fun calendarGranted(): Boolean =
        activity.checkSelfPermission(Manifest.permission.READ_CALENDAR) ==
            PackageManager.PERMISSION_GRANTED

    private fun calendars(): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!calendarGranted()) return out
        activity.contentResolver.query(
            CalendarContract.Calendars.CONTENT_URI,
            arrayOf(
                CalendarContract.Calendars._ID,
                CalendarContract.Calendars.CALENDAR_DISPLAY_NAME,
                CalendarContract.Calendars.ACCOUNT_NAME,
            ),
            null,
            null,
            CalendarContract.Calendars.CALENDAR_DISPLAY_NAME + " ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                out.add(
                    mapOf(
                        "id" to cursor.getLong(0).toString(),
                        "name" to (cursor.getString(1) ?: ""),
                        "account" to (cursor.getString(2) ?: ""),
                    )
                )
            }
        }
        return out
    }

    /** Events overlapping the span. Cancelled and declined ones are left out. */
    private fun events(start: Long, end: Long): List<Map<String, Any?>> {
        val out = ArrayList<Map<String, Any?>>()
        if (!calendarGranted() || end <= start) return out
        val uri = CalendarContract.Instances.CONTENT_URI.buildUpon().let {
            ContentUris.appendId(it, start)
            ContentUris.appendId(it, end)
            it.build()
        }
        // All-day events are stored in UTC: keep one only if it covers the
        // local day being asked about.
        val local = Calendar.getInstance().apply { timeInMillis = start }
        val dayUtc = Calendar.getInstance(TimeZone.getTimeZone("UTC")).apply {
            clear()
            set(local.get(Calendar.YEAR), local.get(Calendar.MONTH), local.get(Calendar.DAY_OF_MONTH))
        }.timeInMillis
        activity.contentResolver.query(
            uri,
            arrayOf(
                CalendarContract.Instances.EVENT_ID,
                CalendarContract.Instances.TITLE,
                CalendarContract.Instances.BEGIN,
                CalendarContract.Instances.END,
                CalendarContract.Instances.ALL_DAY,
                CalendarContract.Instances.CALENDAR_ID,
                CalendarContract.Instances.STATUS,
                CalendarContract.Instances.SELF_ATTENDEE_STATUS,
            ),
            null,
            null,
            CalendarContract.Instances.BEGIN + " ASC",
        )?.use { cursor ->
            while (cursor.moveToNext()) {
                val begin = cursor.getLong(2)
                val finish = cursor.getLong(3)
                val allDay = cursor.getInt(4) != 0
                if (cursor.getInt(6) == CalendarContract.Events.STATUS_CANCELED) continue
                if (cursor.getInt(7) == CalendarContract.Attendees.ATTENDEE_STATUS_DECLINED) continue
                if (allDay && !(begin <= dayUtc && dayUtc < finish)) continue
                out.add(
                    mapOf(
                        "id" to cursor.getLong(0).toString(),
                        "title" to (cursor.getString(1) ?: ""),
                        "begin" to begin,
                        "end" to finish,
                        "allDay" to allDay,
                        "calendarId" to cursor.getLong(5).toString(),
                    )
                )
            }
        }
        return out
    }

    // ---- Health Connect steps (Android 14 and later, read only) -----------

    private fun stepsAccess(): String {
        if (Build.VERSION.SDK_INT < 34) return "unavailable"
        return try {
            if (activity.getSystemService(HealthConnectManager::class.java) == null) {
                "unavailable"
            } else if (activity.checkSelfPermission(READ_STEPS) == PackageManager.PERMISSION_GRANTED) {
                "connected"
            } else {
                "notConnected"
            }
        } catch (e: Throwable) {
            "unavailable"
        }
    }

    @RequiresApi(34)
    private fun readSteps(start: Long, end: Long, result: MethodChannel.Result) {
        try {
            val manager = activity.getSystemService(HealthConnectManager::class.java)
            if (manager == null) {
                result.success(null)
                return
            }
            val request = AggregateRecordsRequest.Builder<Long>(
                TimeInstantRangeFilter.Builder()
                    .setStartTime(Instant.ofEpochMilli(start))
                    .setEndTime(Instant.ofEpochMilli(end))
                    .build()
            ).addAggregationType(StepsRecord.STEPS_COUNT_TOTAL).build()
            manager.aggregate(
                request,
                activity.mainExecutor,
                object : OutcomeReceiver<AggregateRecordsResponse<Long>, HealthConnectException> {
                    override fun onResult(response: AggregateRecordsResponse<Long>) {
                        // Null when there is no step data for the span.
                        val total: Long? = response.get(StepsRecord.STEPS_COUNT_TOTAL)
                        result.success(total?.toInt())
                    }

                    override fun onError(error: HealthConnectException) {
                        result.success(null)
                    }
                },
            )
        } catch (e: Throwable) {
            result.success(null)
        }
    }

    // ---- the reminder ------------------------------------------------------

    private fun notificationsAllowed(): Boolean {
        val manager = activity.getSystemService(NotificationManager::class.java)
        if (manager == null || !manager.areNotificationsEnabled()) return false
        return Build.VERSION.SDK_INT < 33 ||
            activity.checkSelfPermission(POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
    }
}
