package com.nylo.nylo_app

import android.content.Context
import android.content.Intent
import android.util.Log
import com.google.firebase.messaging.FirebaseMessagingService
import com.google.firebase.messaging.RemoteMessage
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

class ConfigFirebaseMessagingService : FirebaseMessagingService() {

    override fun onMessageReceived(remoteMessage: RemoteMessage) {
        if (remoteMessage.notification != null) {
            val title = remoteMessage.notification?.title ?: "Default Title"
            val message = remoteMessage.notification?.body ?: "Default Message"
            showNotification(title, message)
        }
    }

    override fun onNewToken(token: String) {
        super.onNewToken(token)
        Log.d("ConfigFirebaseMessagingService", "New FCM Token: $token")

        val sharedPreferences = getSharedPreferences("FCM_PREFS", Context.MODE_PRIVATE)
        val editor = sharedPreferences.edit()
        editor.putString("fcm_token", token)
        editor.apply()

        Log.d("ConfigFirebaseMessagingService", "FCM Token saved to SharedPreferences")
    }

    private fun showNotification(title: String, message: String) {
        val builder = NotificationCompat.Builder(this, "CHANNEL_ID")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_HIGH)

        val manager = NotificationManagerCompat.from(this)
        manager.notify(0, builder.build())
    }
}