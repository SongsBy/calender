package com.fastapi.template.frontend

import android.Manifest
import android.content.ContentUris
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.CalendarContract
import android.provider.CalendarContract.Calendars as C
import android.provider.CalendarContract.Instances as I
import android.provider.Settings
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.util.UUID
import java.io.File
import java.util.concurrent.Executors

class MainActivity : FlutterActivity() {
    private var permissionResult: MethodChannel.Result? = null
    private val worker = Executors.newSingleThreadExecutor()

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "shared_calendar/device")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "permission" -> {
                        if (checkSelfPermission(Manifest.permission.READ_CALENDAR) == PackageManager.PERMISSION_GRANTED) result.success(true)
                        else if (permissionResult != null) result.error("BUSY", "권한 요청 중입니다.", null)
                        else {
                            permissionResult = result
                            requestPermissions(arrayOf(Manifest.permission.READ_CALENDAR), 731)
                        }
                    }
                    "settings" -> {
                        startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:$packageName")))
                        result.success(null)
                    }
                    "installationId" -> {
                        val file = File(noBackupFilesDir, "calendar_import_id")
                        val id = if (file.exists()) file.readText() else UUID.randomUUID().toString().also { file.writeText(it) }
                        result.success(id)
                    }
                    "calendars", "events" -> worker.execute {
                        try {
                            if (checkSelfPermission(Manifest.permission.READ_CALENDAR) != PackageManager.PERMISSION_GRANTED) throw SecurityException()
                            val rows = mutableListOf<Map<String, Any?>>()
                            if (call.method == "calendars") {
                                val cursor = contentResolver.query(C.CONTENT_URI, arrayOf(C._ID, C.CALENDAR_DISPLAY_NAME), "${C.CALENDAR_ACCESS_LEVEL} >= ?", arrayOf("200"), "${C.CALENDAR_DISPLAY_NAME} ASC") ?: error("캘린더를 읽지 못했습니다.")
                                cursor.use { while (it.moveToNext()) rows.add(mapOf("id" to it.getLong(0).toString(), "name" to it.getString(1))) }
                            } else {
                                val from = call.argument<Number>("from")!!.toLong()
                                val to = call.argument<Number>("to")!!.toLong()
                                require(to > from && to - from <= 96L * 86400000)
                                val uri = CalendarContract.Instances.CONTENT_URI.buildUpon()
                                ContentUris.appendId(uri, from)
                                ContentUris.appendId(uri, to)
                                val projection = arrayOf(I.EVENT_ID, I.TITLE, I.DESCRIPTION, I.ALL_DAY, I.BEGIN, I.END, I.ORIGINAL_INSTANCE_TIME, I.ORIGINAL_ID)
                                val cursor = contentResolver.query(uri.build(), projection, "${I.CALENDAR_ID} = ? AND (${I.STATUS} IS NULL OR ${I.STATUS} != 2)", arrayOf(call.argument<String>("calendarId")!!), "${I.BEGIN} ASC") ?: error("일정을 읽지 못했습니다.")
                                cursor.use {
                                    while (it.moveToNext()) {
                                        if (rows.size >= 1000) error("일정이 1,000개를 초과합니다. 조회 기간을 줄여주세요.")
                                        rows.add(mapOf("id" to (if(it.isNull(7)) it.getLong(0) else it.getLong(7)).toString(), "title" to it.getString(1), "description" to it.getString(2), "allDay" to (it.getInt(3) == 1), "start" to it.getLong(4), "end" to it.getLong(5), "original" to if(it.isNull(6)) it.getLong(4) else it.getLong(6)))
                                    }
                                }
                            }
                            runOnUiThread { result.success(rows) }
                        } catch (e: SecurityException) {
                            runOnUiThread { result.error("PERMISSION", "캘린더 읽기 권한을 허용해주세요.", null) }
                        } catch (e: Exception) {
                            runOnUiThread { result.error("READ_FAILED", e.message ?: "일정을 읽지 못했습니다.", null) }
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 731) {
            permissionResult?.success(grantResults.firstOrNull() == PackageManager.PERMISSION_GRANTED)
            permissionResult = null
        }
    }
}
