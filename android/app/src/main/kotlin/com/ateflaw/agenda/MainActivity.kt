package com.ateflaw.agenda

import android.Manifest
import android.content.ContentProviderOperation
import android.content.pm.PackageManager
import android.provider.CalendarContract
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelName = "com.ateflaw.agenda/calendar"
    private var permissionResult: MethodChannel.Result? = null
    private val requestCode = 4821

    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        MethodChannel(engine.dartExecutor.binaryMessenger, channelName).setMethodCallHandler { call, result ->
            when (call.method) {
                "calendars" -> {
                    if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED ||
                        checkSelfPermission(Manifest.permission.WRITE_CALENDAR) != PackageManager.PERMISSION_GRANTED) {
                        if (permissionResult != null) {
                            result.error("busy", "Permission request already in progress", null)
                        } else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR, Manifest.permission.WRITE_CALENDAR), requestCode)
                        }
                    } else {
                        listCalendars(result)
                    }
                }
                "addEvents" -> {
                    try {
                        val calendarId = call.argument<Number>("calendarId")!!.toLong()
                        val events = call.argument<List<Map<String, Any>>>("events")!!
                        val ops = ArrayList<ContentProviderOperation>()
                        for (event in events) {
                            val eventIndex = ops.size
                            ops.add(ContentProviderOperation.newInsert(CalendarContract.Events.CONTENT_URI)
                                .withValue(CalendarContract.Events.CALENDAR_ID, calendarId)
                                .withValue(CalendarContract.Events.TITLE, event["title"])
                                .withValue(CalendarContract.Events.DESCRIPTION, event["description"])
                                .withValue(CalendarContract.Events.EVENT_LOCATION, event["location"])
                                .withValue(CalendarContract.Events.DTSTART, (event["start"] as Number).toLong())
                                .withValue(CalendarContract.Events.DTEND, (event["end"] as Number).toLong())
                                .withValue(CalendarContract.Events.EVENT_TIMEZONE, "UTC")
                                .withValue(CalendarContract.Events.ALL_DAY, 1)
                                .withValue(CalendarContract.Events.HAS_ALARM, 1)
                                .build())
                            ops.add(ContentProviderOperation.newInsert(CalendarContract.Reminders.CONTENT_URI)
                                .withValueBackReference(CalendarContract.Reminders.EVENT_ID, eventIndex)
                                .withValue(CalendarContract.Reminders.MINUTES, 1440)
                                .withValue(CalendarContract.Reminders.METHOD, CalendarContract.Reminders.METHOD_ALERT)
                                .build())
                        }
                        contentResolver.applyBatch(CalendarContract.AUTHORITY, ops)
                        result.success(events.size)
                    } catch (e: Exception) {
                        result.error("calendar_error", e.message, null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun listCalendars(result: MethodChannel.Result) {
        try {
            val calendars = ArrayList<Map<String, Any>>()
            val projection = arrayOf(CalendarContract.Calendars._ID, CalendarContract.Calendars.CALENDAR_DISPLAY_NAME, CalendarContract.Calendars.ACCOUNT_NAME)
            contentResolver.query(
                CalendarContract.Calendars.CONTENT_URI, projection,
                "${CalendarContract.Calendars.CALENDAR_ACCESS_LEVEL} >= ? AND ${CalendarContract.Calendars.VISIBLE} = 1",
                arrayOf(CalendarContract.Calendars.CAL_ACCESS_CONTRIBUTOR.toString()), null
            )?.use { cursor ->
                while (cursor.moveToNext()) {
                    calendars.add(mapOf("id" to cursor.getLong(0), "name" to (cursor.getString(1) ?: ""), "account" to (cursor.getString(2) ?: "")))
                }
            }
            result.success(calendars)
        } catch (e: Exception) {
            result.error("calendar_error", e.message, null)
        }
    }

    @Deprecated("Deprecated in Android")
    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == this.requestCode) {
            val pending = permissionResult ?: return
            permissionResult = null
            if (grantResults.size == 2 && grantResults.all { it == PackageManager.PERMISSION_GRANTED }) {
                listCalendars(pending)
            } else {
                pending.error("permission_denied", "Calendar permission denied", null)
            }
        }
    }
}
