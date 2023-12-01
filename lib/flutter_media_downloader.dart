import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

class MediaDownload {
  static const MethodChannel _channel = MethodChannel('custom_notifications');

  Future<void> downloadMedia(BuildContext context, String url,
      [String? location, String? fileName]) async {
    await requestPermission();
    final String mediaUrl = url;
    final HttpClient httpClient = HttpClient();

    try {
      final Uri uri = Uri.parse(mediaUrl);
      final HttpClientRequest request = await httpClient.getUrl(uri);
      final HttpClientResponse response = await request.close();

      final pathSegments = uri.pathSegments;

      if (response.statusCode == HttpStatus.ok) {
        final Uint8List bytes =
        await consolidateHttpClientResponseBytes(response);

        final baseStorage = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();

        String? imageName;
        String? extension;

        for (final segment in pathSegments) {
          /// Split the found segment into filename and extension
          final parts = segment.split('.');
          if (parts.length >= 2) {
            imageName = parts[0];
            extension = parts[1];
            break;
          }
        }


        if (imageName == null || extension == null) {
          throw FormatException('Invalid file name or extension.');
        }

        ///Android Code
        ///
        /// Android platform logic is there
        /// How to file name is given location is fetch everything is mentioned.

        if (Platform.isAndroid) {
          final String filePath =
              '${baseStorage?.path}/${uri.pathSegments.last}';

          /// Save the file with the correct name and extension
          await saveFile(bytes, filePath, imageName, extension);

          /// Notify and open the media file
          await notifyAndOpenMediaFile(url, imageName, extension, filePath);
        } else {
          final String filePath =
              '${location ?? ''}/$imageName.$extension';

          /// Save the file with the correct name and extension
          await saveFile(bytes, filePath, imageName, extension);

          /// Notify and open the media file
          await notifyAndOpenMediaFile(url, imageName, extension, filePath);
        }
      } else {
        if (kDebugMode) {
          print('API Request failed with status ${response.statusCode}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error: $e');
      }
    } finally {
      httpClient.close();
    }
  }

  Future<void> saveFile(Uint8List bytes, String filePath, String imageName, String extension) async {
    final File file = File(filePath);
    await file.writeAsBytes(bytes);
    if (kDebugMode) {
      print('File saved successfully. Path: ${file.path}');
    }
  }

  Future<void> notifyAndOpenMediaFile(String url, String imageName, String extension, String filePath) async {
    try {
      await downloadFile(url, imageName, extension, filePath);
      await openMediaFile(filePath);
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error during file download or open: ${e.message}');
      }
    }
  }

  Future<void> downloadFile(String url, String title, String description, String filePath) async {
    try {
      await _channel.invokeMethod('downloadFile', {
        'url': url,
        'title': title,
        'description': description,
        'filePath': filePath
      });
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error downloading file: ${e.message}');
      }
    }
  }

  Future<void> openMediaFile(String filePath) async {
    const platform = MethodChannel('showCustomNotification');
    try {
      final result = await platform.invokeMethod('openMediaFile', {
        'filePath': filePath,
      });
      if (result) {
        if (kDebugMode) {
          print('Media file opened successfully');
        }
      } else {
        if (kDebugMode) {
          print('Failed to open media file');
        }
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('Error opening media file: ${e.message}');
      }
    }
  }

  Future<void> requestPermission() async {
    final PermissionStatus status = await Permission.storage.request();
    final PermissionStatus notificationStatus =
    await Permission.notification.request();
    if (status.isGranted && notificationStatus.isGranted) {
    } else {
    }
  }
}
