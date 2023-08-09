
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class MediaDownload{

  static const MethodChannel _channel =
  MethodChannel('custom_notifications');

  Future<void> downloadPDF(String url,
      [String? location, String? fileName]) async {
    final String pdfUrl = url; // URL of the PDF file
    final HttpClient httpClient = HttpClient();


    try {
      final Uri uri = Uri.parse(pdfUrl);
      final HttpClientRequest request = await httpClient.getUrl(uri,);

      final HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.ok) {

        final Uint8List bytes = await consolidateHttpClientResponseBytes(response);
        _updateProgress();
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
          final File file = File('${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
          await file.writeAsBytes(bytes);
          showCustomNotification('Media',nameWithoutExtension,1);
          print('PDF Downloaded successfully. Path: ${file.path}');
        } else {

          ///Fetch file name without extension.
          int lastSlashIndex = url.lastIndexOf('/');
          String fileNameWithExtension = url.substring(lastSlashIndex + 1);
          int dotIndex = fileNameWithExtension.lastIndexOf('.');
          final fileExtension = url.toString().substring(url.toString().toLowerCase().length - 3);
          String nameWithoutExtension = fileName ?? fileNameWithExtension.substring(0, dotIndex);
          final File file = File('$location/$nameWithoutExtension.$fileExtension');

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

  double _progressValue = 0.0; // Initial progress value


  void _updateProgress() {
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


}
class CustomNotifications {



}
