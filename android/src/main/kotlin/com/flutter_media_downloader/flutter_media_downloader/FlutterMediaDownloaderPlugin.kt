/*
package com.flutter_media_downloader.flutter_media_downloader

import androidx.annotation.NonNull

import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

*/
/** FlutterMediaDownloaderPlugin *//*

class FlutterMediaDownloaderPlugin: FlutterPlugin, MethodCallHandler {
  /// The MethodChannel that will the communication between Flutter and native Android
  ///
  /// This local reference serves to register the plugin with the Flutter Engine and unregister it
  /// when the Flutter Engine is detached from the Activity
  private lateinit var channel : MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "flutter_media_downloader")
    channel.setMethodCallHandler(this)
  }

  */
/*override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
    if (call.method == "getPlatformVersion") {
      result.success("Android ${android.os.Build.VERSION.RELEASE}")
    } else {
      result.notImplemented()
    }
  }*//*

  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "showCustomNotification" -> {
        val title = call.argument<String>("title")
        val message = call.argument<String>("message")
        if (title != null && message != null) {
          showCustomNotification(title, message)
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
        }
      }
      // ... Other methods ...
      else -> {
        result.notImplemented()
      }
    }
  }
  private fun showCustomNotification(title: String, message: String) {
    val channelId = "flutter_media_downloader"
    val notificationId = 1

    val notificationManager =
      context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    // Create a notification channel for devices running Android 8.0 and above
    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        channelId,
        "Custom Notifications",
        NotificationManager.IMPORTANCE_DEFAULT
      )
      notificationManager.createNotificationChannel(channel)
    }

    // Build the notification
    val notificationBuilder = NotificationCompat.Builder(context, channelId)
      .setContentTitle(title)
      .setContentText(message)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setAutoCancel(true)

    // Show the notification
    notificationManager.notify(notificationId, notificationBuilder.build())
  }



}
*/

package com.flutter_media_downloader.flutter_media_downloader

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.os.Build
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

/** FlutterMediaDownloaderPlugin */
class FlutterMediaDownloaderPlugin : FlutterPlugin, MethodCallHandler {
  // Define a lateinit property for the FlutterPluginBinding.
  private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

  // Initialize the MethodChannel.
  private lateinit var channel: MethodChannel

  override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
    this.flutterPluginBinding = flutterPluginBinding
    channel = MethodChannel(flutterPluginBinding.binaryMessenger, "custom_notifications")
    channel.setMethodCallHandler(this)
  }

  // Implement the MethodCallHandler interface.
  override fun onMethodCall(call: MethodCall, result: Result) {
    when (call.method) {
      "showCustomNotification" -> {
        val title = call.argument<String>("title")
        val message = call.argument<String>("message")
        val initialProgress = call.argument<Int>("initialProgress")
        if (title != null && message != null) {
//          showCustomNotification(title, message)
          showCustomNotificationWithProgress(title,message,initialProgress)
          result.success(null)
        } else {
          result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
        }
      }
      // Handle other methods...
      else -> {
        result.notImplemented()
      }
    }
  }
///Without linear progress
  /*private fun showCustomNotification(title: String, message: String) {
    val channelId = "flutter_media_downloader"
    val notificationId = 1

    val notificationManager =
      flutterPluginBinding.applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        channelId,
        "Custom Notifications",
        NotificationManager.IMPORTANCE_DEFAULT
      )
      notificationManager.createNotificationChannel(channel)
    }

    val notificationBuilder = NotificationCompat.Builder(flutterPluginBinding.applicationContext, channelId)
      .setContentTitle(title)
      .setContentText(message)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setAutoCancel(true)

    notificationManager.notify(notificationId, notificationBuilder.build())
  }*/

  private fun showCustomNotificationWithProgress(
    title: String,
    message: String,
    initialProgress: Int?
  ) {
    val channelId = "flutter_media_downloader"
    val notificationId = 1

    val notificationManager =
      flutterPluginBinding.applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
      val channel = NotificationChannel(
        channelId,
        "Custom Notifications",
        NotificationManager.IMPORTANCE_DEFAULT
      )
      notificationManager.createNotificationChannel(channel)
    }

    val notificationBuilder = NotificationCompat.Builder(
      flutterPluginBinding.applicationContext,
      channelId
    )
      .setContentTitle(title)
      .setContentText(message)
      .setSmallIcon(android.R.drawable.ic_dialog_info)
      .setPriority(NotificationCompat.PRIORITY_HIGH)
      .setAutoCancel(true)

    val maxProgress = 100
    val indeterminate = initialProgress == null || initialProgress < 0

    if (initialProgress != null && initialProgress >= 0) {
      notificationBuilder.setProgress(maxProgress, initialProgress, indeterminate)
    }

    notificationManager.notify(notificationId, notificationBuilder.build())

    if (initialProgress != null && initialProgress >= 0) {
      Thread {
        var progress = initialProgress
        while (progress <= maxProgress) {
          Thread.sleep(1000)
          progress += 10
          notificationBuilder.setProgress(maxProgress, progress, indeterminate)
          notificationManager.notify(notificationId, notificationBuilder.build())
        }
        notificationBuilder.setProgress(0, 0, false)
        notificationManager.notify(notificationId, notificationBuilder.build())
      }.start()
    }
  }



  override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
    // Clean up resources if needed
  }
}

