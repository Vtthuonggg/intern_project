package com.aibat.app

import io.flutter.embedding.android.FlutterActivity

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import com.google.firebase.FirebaseApp
import android.os.Build
import android.os.Bundle
import android.util.Log
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import com.google.firebase.messaging.FirebaseMessaging


class MainActivity: FlutterActivity() {

    private val CHANNEL = "com.aibat.sale_manager/fcm"
    private var fcmToken: String? = null

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        FirebaseApp.initializeApp(this)
        createNotificationChannel()

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            requestPermissions(arrayOf(android.Manifest.permission.POST_NOTIFICATIONS), 101)
        }

        val sharedPreferences = getSharedPreferences("FCM_PREFS", Context.MODE_PRIVATE)
        fcmToken = sharedPreferences.getString("fcm_token", null)
        if (fcmToken == null) {
            FirebaseMessaging.getInstance().token.addOnCompleteListener { task ->
                if (task.isSuccessful) {
                    fcmToken = task.result
                    val editor = sharedPreferences.edit()
                    editor.putString("fcm_token", fcmToken)
                    editor.apply()
                    Log.d("MainActivity", "Fetched FCM Token: $fcmToken")
                } else {
                    Log.w("MainActivity", "Fetching FCM token failed", task.exception)
                }
            }
        } else {
            Log.d("MainActivity", "Restored FCM Token from SharedPreferences: $fcmToken")
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            if (call.method == "getFCMToken") {
                if (fcmToken != null) {
                    result.success(fcmToken)
                } else {
                    result.error("UNAVAILABLE", "FCM token not available.", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == 101) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                Log.d("MainActivity", "Notification permission granted")
            } else {
                Log.d("MainActivity", "Notification permission denied")
            }
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                "CHANNEL_ID", "Foreground Service Channel",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            val manager = getSystemService(NotificationManager::class.java)
            manager.createNotificationChannel(channel)
        }
    }
}
