
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaDownload {

  static const MethodChannel _channel =
  MethodChannel('custom_notifications');

  Future<void> downloadPDF(BuildContext context,String url,
      [String? location, String? fileName]) async {
    await requestPermission();
    final String pdfUrl = url; // URL of the PDF file
    final HttpClient httpClient = HttpClient();


    try {
      final Uri uri = Uri.parse(pdfUrl);
      final HttpClientRequest request = await httpClient.getUrl(uri,);

      final HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final Uint8List bytes = await consolidateHttpClientResponseBytes(
            response);
        if (location == null || location == '') {
          final baseStorage = Platform.isAndroid
              ? await getExternalStorageDirectory()
              : await getApplicationDocumentsDirectory();


          int lastSlashIndex = url.lastIndexOf('/');
          String fileNameWithExtension = url.substring(lastSlashIndex + 1);

          int dotIndex = fileNameWithExtension.lastIndexOf('.');
          final fileExtension = url.toString().substring(url
              .toString()
              .toLowerCase()
              .length - 3);
          String nameWithoutExtension = fileName ??
              fileNameWithExtension.substring(0, dotIndex);
          final File file = File(
              '${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
          await file.writeAsBytes(bytes);
          await openFile(context,
              '${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
          await showCustomNotification('Media', nameWithoutExtension, 1,);
          print('PDF Downloaded successfully. Path: ${file.path}');
        } else {

          ///Fetch file name without extension.
          int lastSlashIndex = url.lastIndexOf('/');
          String fileNameWithExtension = url.substring(lastSlashIndex + 1);
          int dotIndex = fileNameWithExtension.lastIndexOf('.');
          final fileExtension = url.toString().substring(url
              .toString()
              .toLowerCase()
              .length - 3);
          String nameWithoutExtension = fileName ??
              fileNameWithExtension.substring(0, dotIndex);
          final File file = File(
              '$location/$nameWithoutExtension.$fileExtension');
          await file.writeAsBytes(bytes);


          print('PDF Downloaded successfully. Path: ${file.path}');
        }
      }
      else {
        // API call failed
        print('API Request failed with status ${response.statusCode}');
        // Handle the error response here
      }
    } catch (e) {
      // Error occurred during the API call
      print('Error: $e');
      // Handle the error here
    } finally {
      httpClient.close(); // Close the HttpClient when done
    }
  }


  /* void _updateProgress() {
    // Simulate a task with progress updates
    Future<void>.delayed(const Duration(milliseconds: 10), () {

        if (_progressValue < 1.0) {
          _progressValue += 0.1;
          print('PROGRESS $_progressValue');
          if (_progressValue > 1.0) {
            _progressValue = 1.0; // Cap the progress value at 100%
          }
          _updateProgress();
        }
      });
  }*/
  Future<void> requestPermission() async {
    final PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      // Permission granted, you can now access media files
    } else {
      // Permission denied, handle accordingly
    }
  }

  Future<void> showCustomNotification(String title, String message,int initialProgress) async {
    print('NotiifcationClickes');
    try {
      await _channel.invokeMethod('showCustomNotification', {
        'title': title,
        'message': message,
        'initialProgress': initialProgress
      });
    } catch (e) {
      print('Error showing custom notification: $e');
    }
  }
  Future<void> openFile(BuildContext context,String filePath) async {
    try {
      final bool success = await _channel.invokeMethod('openFile', filePath);
      if (success) {
        print('File opened successfully');
      } else {
        print('Failed to open file');
      }
    } on PlatformException catch (e) {
      print('Error opening file: ${e.message}');
    }
  }
}