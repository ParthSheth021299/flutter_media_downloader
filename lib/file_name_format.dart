import 'dart:math';

import 'package:flutter/cupertino.dart';

class FileNameFormat {
  String fileNameExtension(String url) {
    try {
      int lastSlashIndex = url.lastIndexOf('/');

      // Extract the file name with extension
      String fileNameWithExtension = url.substring(lastSlashIndex + 1);

      // Decode the file name with extension
      fileNameWithExtension = Uri.decodeComponent(fileNameWithExtension);

      // Find the index of the last dot (before the file extension)
      int dotIndex = fileNameWithExtension.lastIndexOf('.');

      // Find the index of the first query parameter (?)
      int queryParamIndex = fileNameWithExtension.indexOf('?');

      // Extract the file extension
      String fileExtension;
      if (queryParamIndex != -1) {
        fileExtension =
            fileNameWithExtension.substring(dotIndex + 1, queryParamIndex);
      } else {
        fileExtension = fileNameWithExtension.substring(dotIndex + 1);
      }
      return fileExtension;
    } on Exception catch (e) {
      debugPrint('fileNameExtension: E: $e');
      return '';
    }
  }

  String fileNameWithOutExtension(String url) {
    try {
      int lastSlashIndex = url.lastIndexOf('/');

      // Extract the file name with extension
      String fileNameWithExtension = url.substring(lastSlashIndex + 1);

      // Decode the file name with extension
      fileNameWithExtension = Uri.decodeComponent(fileNameWithExtension);

      // Find the index of the last dot (before the file extension)
      int dotIndex = fileNameWithExtension.lastIndexOf('.');

      // Extract the file name without extension
      String nameWithoutExtension;
      if (dotIndex != -1) {
        nameWithoutExtension = fileNameWithExtension.substring(0, dotIndex);
      } else {
        // If there's no dot, use the whole filename
        nameWithoutExtension = fileNameWithExtension;
      }

      // Remove any prefix before the last slash
      int lastSlashInName = nameWithoutExtension.lastIndexOf('/');
      if (lastSlashInName != -1) {
        nameWithoutExtension =
            nameWithoutExtension.substring(lastSlashInName + 1);
      }

      debugPrint('fileNameWithOutExtension: $nameWithoutExtension');
      return nameWithoutExtension;
    } on Exception catch (e) {
      debugPrint('fileNameWithOutExtension:[ $url ]: E: $e');
      final randomNumber = Random().nextInt(1000);
      final now = DateTime.now();
      final generatedFileName =
          'file_${randomNumber}_${now.millisecondsSinceEpoch}';
      debugPrint(
          'fileNameWithOutExtension: E: generated file name: $generatedFileName');
      return generatedFileName;
    }
  }
}
