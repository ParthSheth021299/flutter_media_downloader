import 'package:flutter/cupertino.dart';

class FileNameFormat {
  String fileNameExtension(String url) {
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
  }

  String fileNameWithOutExtension(String url) {
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

    // Extract the file name without extension
    String nameWithoutExtension = fileNameWithExtension.substring(0, dotIndex);

    // Remove any prefix before the last slash
    int lastSlashInName = nameWithoutExtension.lastIndexOf('/');
    if (lastSlashInName != -1) {
      nameWithoutExtension =
          nameWithoutExtension.substring(lastSlashInName + 1);
    }
    debugPrint('FUNCTION NAME ${nameWithoutExtension}');
    return nameWithoutExtension;
  }
}
