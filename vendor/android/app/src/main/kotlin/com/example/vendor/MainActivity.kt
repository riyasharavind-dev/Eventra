package com.example.vendor

import android.Manifest
import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val channelId = "eventra_bookings"

    private fun createBookingChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId, "Booking notifications", NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "New booking requests and booking updates"
                enableVibration(true)
            }
            getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
        }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        createBookingChannel()
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "eventra/notifications")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "initialize" -> {
                        createBookingChannel()
                        result.success(null)
                    }
                    "show" -> {
                        if (Build.VERSION.SDK_INT >= 33 &&
                            checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED) {
                            result.success(null)
                            return@setMethodCallHandler
                        }
                        val id = call.argument<String>("id") ?: "booking"
                        val intent = Intent(this, MainActivity::class.java).apply {
                            flags = Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_SINGLE_TOP
                        }
                        val tap = PendingIntent.getActivity(
                            this, id.hashCode(), intent,
                            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                        )
                        val body = call.argument<String>("body") ?: ""
                        val builder = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                            Notification.Builder(this, channelId)
                        } else {
                            Notification.Builder(this)
                        }
                        val notification = builder
                            .setSmallIcon(R.drawable.ic_stat_booking)
                            .setContentTitle(call.argument<String>("title") ?: "Eventra")
                            .setContentText(body)
                            .setStyle(Notification.BigTextStyle().bigText(body))
                            .setAutoCancel(true)
                            .setContentIntent(tap)
                            .setCategory(Notification.CATEGORY_EVENT)
                            .setPriority(Notification.PRIORITY_HIGH)
                            .setDefaults(Notification.DEFAULT_ALL)
                            .build()
                        val manager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
                        manager.notify(id.hashCode(), notification)
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}