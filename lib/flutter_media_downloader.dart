import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_media_downloader/file_name_format.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Media Downloader Class
///
/// Over here downloadMedia is there which helps user to download the media.
/// Basically code is divided in to two parts for the android platform and for iOS platform

class MediaDownload {
  static const MethodChannel _channel = MethodChannel('custom_notifications');

  Future<void> downloadMedia(BuildContext context, String url,
      [String? location, String? fileName]) async {
    await requestPermission();
    final String pdfUrl = url;
    final HttpClient httpClient = HttpClient();

    try {
      final Uri uri = Uri.parse(pdfUrl);
      final HttpClientRequest request = await httpClient.getUrl(
        uri,
      );

      final HttpClientResponse response = await request.close();

      if (response.statusCode == HttpStatus.ok) {
        final Uint8List bytes =
        await consolidateHttpClientResponseBytes(response);
        final baseStorage = Platform.isAndroid
            ? await getExternalStorageDirectory()
            : await getApplicationDocumentsDirectory();

        ///Android Code
        ///
        /// Android platform logic is there
        /// How to file name is given location is fetch everything is mentioned.

        if (Platform.isAndroid) {
          if (location == null || location == '') {
            String fileExtension = FileNameFormat().fileNameExtension(url);
            String nameWithoutExtension =
            FileNameFormat().fileNameWithOutExtension(url);

            debugPrint('Android fileExtension $fileExtension');
            debugPrint('Android nameWithoutExtension $nameWithoutExtension');
            debugPrint(
                'Android  ${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
            final File file = File(
                '${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
            await file.writeAsBytes(bytes);
            await downloadFile(
                url,
                fileName ?? nameWithoutExtension,
                '$nameWithoutExtension.$fileExtension',
                '${baseStorage?.path}/$nameWithoutExtension.$fileExtension');
            if (kDebugMode) {
              print('PDF Downloaded successfully. Path: ${file.path}');
            }
          } else {
            String fileExtension = FileNameFormat().fileNameExtension(url);
            String nameWithoutExtension =
            FileNameFormat().fileNameWithOutExtension(url);
            final File file =
            File('$location/$nameWithoutExtension.$fileExtension');
            await file.writeAsBytes(bytes);
            await downloadFile(
                url,
                fileName ?? nameWithoutExtension,
                nameWithoutExtension,
                '$location/$nameWithoutExtension.$fileExtension');
            if (kDebugMode) {
              print('PDF Downloaded successfully. Path: ${file.path}');
            }
          }
        }

        ///iOS Code
        ///
        /// iOS platform logic is there
        /// How to file name is given location is fetch everything is mentioned.

        else if (Platform.isIOS) {
          if (location == null || location == '') {
            Directory documents = await getApplicationDocumentsDirectory();
            String fileExtension = FileNameFormat().fileNameExtension(url);
            String nameWithoutExtension =
            FileNameFormat().fileNameWithOutExtension(url);
            final File file = File(
                '${documents.path}/${fileName ?? nameWithoutExtension}.$fileExtension');
            await file.writeAsBytes(bytes);
            // await showCustomNotification(fileName ?? nameWithoutExtension,
            //     fileName ?? nameWithoutExtension);
            await openMediaFile(file.path);
            if (kDebugMode) {
              print('PDF Downloaded successfully. Path: ${file.path}');
            }
          } else {
            String fileExtension = FileNameFormat().fileNameExtension(url);
            String nameWithoutExtension =
            FileNameFormat().fileNameWithOutExtension(url);
            final File file =
            File('$location/$nameWithoutExtension.$fileExtension');
            await file.writeAsBytes(bytes);
            // await showCustomNotification(
            //     fileName ?? nameWithoutExtension, nameWithoutExtension);
            await openMediaFile(file.path);
            if (kDebugMode) {
              print('PDF Downloaded successfully. Path: ${file.path}');
            }
          }
        } else {
          debugPrint('Platform Windows');
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

  ///downloadFile(Android code)
  ///
  ///This method invokes the notification method from the native side.

  Future<void> downloadFile(
      String url, String title, String description, String filePath) async {
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

  ///openMediaFile(Android code)
  ///
  /// This method helps to open file from notification when user clicks on the notification

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
    // final PermissionStatus notificationStatus =
    // await Permission.notification.request();
    if (status.isGranted 
    // && notificationStatus.isGranted
    ) {
    } else if (status.isPermanentlyDenied 
    // || notificationStatus.isPermanentlyDenied
        ) {
      await openAppSettings();
    }
  }

  ///showCustomNotification(iOS Code)
  ///
  ///This method helps to show notification in the iOS device. It will directly open the file when it is downloaded successfully.
  Future<void> showCustomNotification(
      String titleMessage, String bodyMessage) async {
    const platform = MethodChannel('showCustomNotification');
    try {
      await platform.invokeMethod('showCustomNotification',
          {'title': titleMessage, 'body': bodyMessage});
    } catch (e) {
      if (kDebugMode) {
        print("Error invoking native method: $e");
      }
    }
  }
}