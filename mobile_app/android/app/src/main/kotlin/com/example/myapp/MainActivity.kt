package com.example.myapp

import android.media.RingtoneManager
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "com.example.myapp/ringtones"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getRingtones") {
                try {
                    val ringtones = getSystemRingtones()
                    result.success(ringtones)
                } catch (e: Exception) {
                    result.error("ERROR", "Failed to retrieve ringtones: ${e.message}", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getSystemRingtones(): List<Map<String, String>> {
        val manager = RingtoneManager(this)
        manager.setType(RingtoneManager.TYPE_ALARM or RingtoneManager.TYPE_RINGTONE)
        val cursor = manager.cursor
        val ringtonesList = mutableListOf<Map<String, String>>()
        
        if (cursor != null) {
            while (cursor.moveToNext()) {
                val title = cursor.getString(RingtoneManager.TITLE_COLUMN_INDEX)
                val uri = manager.getRingtoneUri(cursor.position)
                if (uri != null) {
                    ringtonesList.add(mapOf("title" to title, "uri" to uri.toString()))
                }
            }
        }
        return ringtonesList
    }
}
