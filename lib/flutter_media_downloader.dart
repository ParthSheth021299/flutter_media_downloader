
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
  static const MethodChannel _channeliOS = MethodChannel('showCustomNotification');

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
        final baseStorage = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();
        ///Android
        if (Platform.isAndroid) {
          if (location == null || location == '') {
            int lastSlashIndex = url.lastIndexOf('/');
            String fileNameWithExtension = url.substring(lastSlashIndex + 1);

            int dotIndex = fileNameWithExtension.lastIndexOf('.');
            final fileExtension = url
                .toString()
                .substring(url.toString().toLowerCase().length - 3);
            String nameWithoutExtension =
                fileName ?? fileNameWithExtension.substring(0, dotIndex);
            final File file = File(
                '${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
            await file.writeAsBytes(bytes);
            await downloadFile(url, 'File Download', nameWithoutExtension,
                '${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
            print('PDF Downloaded successfully. Path: ${file.path}');
          }
          else {
            ///Fetch file name without extension.
            int lastSlashIndex = url.lastIndexOf('/');
            String fileNameWithExtension = url.substring(lastSlashIndex + 1);
            int dotIndex = fileNameWithExtension.lastIndexOf('.');
            final fileExtension = url
                .toString()
                .substring(url.toString().toLowerCase().length - 3);
            String nameWithoutExtension =
                fileName ?? fileNameWithExtension.substring(0, dotIndex);
            final File file =
            File('$location/$nameWithoutExtension.$fileExtension');
            await file.writeAsBytes(bytes);
            await downloadFile(url, 'File Download', nameWithoutExtension,
                '$location/$nameWithoutExtension.$fileExtension');
            print('PDF Downloaded successfully. Path: ${file.path}');
          }
        }
        ///iOS
        else {
          if (location == null || location == '') {
            Directory documents = await getApplicationDocumentsDirectory();
            print('BASE PATH ${documents.path}');

            int lastSlashIndex = url.lastIndexOf('/');
            String fileNameWithExtension = url.substring(lastSlashIndex + 1);
            int dotIndex = fileNameWithExtension.lastIndexOf('.');
            final fileExtension = url.toString().substring(url.toString().toLowerCase().length - 3);
            String nameWithoutExtension = fileName ?? fileNameWithExtension.substring(0, dotIndex);
            final File file = File('${documents.path}/$nameWithoutExtension.$fileExtension');
            await file.writeAsBytes(bytes);
            await showCustomNotification('File Download', nameWithoutExtension);
            await openMediaFile(file.path);
            print('PDF Downloaded successfully. Path: ${file.path}');
          } else {
            // showCustomNotificationiOS();
          }
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


  Future<void> downloadFile(String url, String title, String description,String filePath) async {
    try {
      await _channel.invokeMethod('downloadFile', {
        'url': url,
        'title': title,
        'description': description,
        'filePath': filePath
      });
    } on PlatformException catch (e) {
      print('Error downloading file: ${e.message}');
    }
  }


  Future<void> requestPermission() async {
    final PermissionStatus status = await Permission.storage.request();
    if (status.isGranted) {
      // Permission granted, you can now access media files
    } else {
      // Permission denied, handle accordingly
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

  Future<void> showCustomNotification(String titleMessage,String bodyMessage) async {
    const platform = MethodChannel('showCustomNotification');
    try {
      await platform.invokeMethod('showCustomNotification', {'title': titleMessage,'body': bodyMessage});
    } catch (e) {
      print("Error invoking native method: $e");
    }
  }
  Future<void> openMediaFile(String filePath) async {
    const platform = MethodChannel('showCustomNotification');
    try {
      final result = await platform.invokeMethod('openMediaFile', {
        'filePath': filePath,
      });
      if (result) {
        print('Media file opened successfully');
      } else {
        print('Failed to open media file');
      }
    } on PlatformException catch (e) {
      print('Error opening media file: ${e.message}');
    }
  }

}