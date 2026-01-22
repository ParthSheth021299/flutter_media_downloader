package com.flutter_media_downloader.flutter_media_downloader

import android.app.DownloadManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.PendingIntent.FLAG_IMMUTABLE
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import androidx.core.app.NotificationCompat
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.io.File
import androidx.core.content.FileProvider

/** FlutterMediaDownloaderPlugin */
class FlutterMediaDownloaderPlugin : FlutterPlugin, MethodCallHandler {
    // Define a lateinit property for the FlutterPluginBinding.
    private lateinit var flutterPluginBinding: FlutterPlugin.FlutterPluginBinding

    // Initialize the MethodChannel.
    private lateinit var channel: MethodChannel
    private var context: Context? = null
    private var downloadManager: DownloadManager? = null
    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        this.flutterPluginBinding = flutterPluginBinding
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "custom_notifications")
        channel.setMethodCallHandler(this)
        downloadManager = context?.getSystemService(Context.DOWNLOAD_SERVICE) as? DownloadManager
    }

    // Implement the MethodCallHandler interface.
    override fun onMethodCall(call: MethodCall, result: Result) {

        when (call.method) {
            "showCustomNotification" -> {
                val title = call.argument<String>("title")
                val message = call.argument<String>("message")
                val initialProgress = call.argument<Int>("initialProgress")

                if (title != null && message != null) {
                    showCustomNotificationWithProgress(title, message, initialProgress)
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
                }
            }
            "openFile" -> {

                val filePath = call.arguments as String
                val context = flutterPluginBinding.applicationContext
                openFile(context,filePath) { success ->
                    if (success) {
                        result.success(true)
                    } else {
                        result.error("FILE_OPEN_ERROR", "Unable to open the file.", null)
                    }
                }
            }
            "downloadFile" -> {
                val url = call.argument<String>("url")
                val title = call.argument<String>("title")
                val description = call.argument<String>("description")
                val context = flutterPluginBinding.applicationContext
                val filePath = call.argument<String>("filePath")
                if (url != null && title != null && description != null) {
                    downloadFile(url, title, description,context,filePath)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
                }
            }
            "cancelDownload" -> {
                val downloadId = call.argument<Long>("downloadId")
                if (downloadId != null) {
                    cancelDownload(downloadId)
                    result.success(true)
                } else {
                    result.error("INVALID_ARGUMENTS", "Invalid arguments", null)
                }
            }
            else -> {
                result.notImplemented()
            }

        }
    }

    private fun showCustomNotificationWithProgress(
        title: String,
        message: String,
        initialProgress: Int?,

    ) {
        val cancelIntent = PendingIntent.getBroadcast(
            context,
            0,
            Intent("CANCEL_DOWNLOAD"),
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        val channelId = "flutter_media_downloader"
        val notificationId = 1

        val notificationManager = flutterPluginBinding.applicationContext.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

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
            .addAction(
                android.R.drawable.ic_menu_close_clear_cancel,
                "Cancel",
                cancelIntent
            )
        // Set the PendingIntent

        val maxProgress = 100
        val indeterminate = initialProgress == null || initialProgress < 0
        notificationManager.notify(notificationId, notificationBuilder.build())


        if (initialProgress != null && initialProgress >= 0) {
            notificationBuilder.setProgress(maxProgress, initialProgress, indeterminate)
        }

        notificationManager.notify(notificationId, notificationBuilder.build())
        context!!.registerReceiver(object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                if (intent?.action == "CANCEL_DOWNLOAD") {
                    // Handle the Cancel button click here
                    // Call the cancelDownload method with the appropriate downloadId
                    val downloadId = intent.getLongExtra("downloadId", -1)
                    if (downloadId.toInt() != -1) {
                        cancelDownload(downloadId)
                    }
                }
            }
        }, IntentFilter("CANCEL_DOWNLOAD"))

        if (initialProgress != null && initialProgress >= 0) {
            Thread {
                var progress = initialProgress
                while (progress <= maxProgress) {
                    Thread.sleep(100)
                    progress += 10
                    notificationBuilder.setProgress(maxProgress, progress, indeterminate)
                    notificationManager.notify(notificationId, notificationBuilder.build())
                }
                notificationBuilder.setProgress(0, 0, false)
                notificationManager.notify(notificationId, notificationBuilder.build())
            }.start()
//
        }

    }

    private fun cancelDownload(downloadId: Long) {
        // Cancel the download using DownloadManager
        downloadManager?.remove(downloadId)
    }


    private fun openFile(context: Context,filePath: String?, result: (Boolean) -> Unit) {

        val file = File(filePath)
        if (file.exists()) {
            val intent = Intent(Intent.ACTION_VIEW)
            val fileUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.provider",
                file
            )

            intent.setDataAndType(fileUri, getMimeType(file))
            intent.flags = Intent.FLAG_GRANT_READ_URI_PERMISSION or Intent.FLAG_ACTIVITY_NEW_TASK

            try {
                context.startActivity(intent)
                result(true) // Notify Flutter about success
            } catch (e: Exception) {
                e.printStackTrace()
                result(false) // Notify Flutter about failure
            }
        } else {
            result(false) // Notify Flutter about failure
        }
    }

    private fun downloadFile(url: String, title: String, description: String,context: Context,filePath: String?) {
        val request = DownloadManager.Request(Uri.parse(url))
            .setTitle(title)
            .setDescription(description)
            .setNotificationVisibility(DownloadManager.Request.VISIBILITY_VISIBLE)
            .setDestinationInExternalPublicDir("Download", title)

        val downloadManager = context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager
        val downloadId = downloadManager.enqueue(request)

        if (filePath != null) {
            showDownloadNotification(downloadId, title, description,filePath,context)
        }
    }


    private fun showDownloadNotification(downloadId: Long, title: String, description: String, filePath: String, context: Context) {
        val channelId = "file_downloader"
        val notificationId = 1

        val notificationManager =
            context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager

        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                channelId,
                "File Downloader",
                NotificationManager.IMPORTANCE_DEFAULT
            )
            notificationManager.createNotificationChannel(channel)
        }

        val notificationIntent = Intent(Intent.ACTION_VIEW).apply {
            val file = File(filePath)
            val fileUri = FileProvider.getUriForFile(
                context,
                "${context.packageName}.provider",
                file
            )
            setDataAndType(fileUri, getMimeType(file))
            flags = Intent.FLAG_GRANT_READ_URI_PERMISSION
        }
        val pendingIntent = PendingIntent.getActivity(
            context,
            0,
            notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        val notificationBuilder = NotificationCompat.Builder(context, channelId)
            .setContentTitle(title)
            .setContentText(description)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)

        val query = DownloadManager.Query().setFilterById(downloadId)

        val handler = Handler(Looper.getMainLooper())
        var isDownloadComplete = false // Flag to track download completion

        val updateNotificationRunnable = object : Runnable {
            override fun run() {
                val cursor = (context.getSystemService(Context.DOWNLOAD_SERVICE) as DownloadManager).query(query)
                if (cursor.moveToFirst()) {
                    val status = cursor.getInt(cursor.getColumnIndex(DownloadManager.COLUMN_STATUS))
                    if (status == DownloadManager.STATUS_SUCCESSFUL) {
                        isDownloadComplete = true // Set the flag to true
                        notificationBuilder.setContentText("Downloaded")
                        notificationBuilder.setProgress(0, 0, false)
                    } else if (status == DownloadManager.STATUS_RUNNING || status == DownloadManager.STATUS_PENDING) {
                        val bytesDownloaded = cursor.getLong(cursor.getColumnIndex(DownloadManager.COLUMN_BYTES_DOWNLOADED_SO_FAR))
                        val bytesTotal = cursor.getLong(cursor.getColumnIndex(DownloadManager.COLUMN_TOTAL_SIZE_BYTES))
                        val progress = (bytesDownloaded * 100 / bytesTotal).toInt()
                        notificationBuilder.setProgress(100, progress, false)
                    }
                }
                cursor.close()

                notificationManager.notify(notificationId, notificationBuilder.build())

                // Repeat the update every second if download is still ongoing
                if (!isDownloadComplete) {
                    handler.postDelayed(this, 1000)
                }
            }
        }

        // Initial call to start the update loop
        handler.post(updateNotificationRunnable)
    }









    private fun getMimeType(file: File): String? {
        val extension = file.extension
        return when (extension.lowercase()) {
            "pdf" -> "application/pdf"
            "jpg", "jpeg", "png" -> "image/*"
            "mp4" -> "video/*"
            // Add more cases for other file types as needed
            else -> "*/*"
        }
    }

    override fun onDetachedFromEngine(binding: FlutterPlugin.FlutterPluginBinding) {
        // Clean up resources if needed
    }
}

