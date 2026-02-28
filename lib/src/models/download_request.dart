import 'save_location.dart';

/// Represents a request to download a file.
///
/// This is the input model used to enqueue a new download task.
class DownloadRequest {
  /// The URL of the file to download
  final String url;

  /// Optional HTTP headers to include in the download request
  final Map<String, String>? headers;

  /// Where the downloaded file should be saved
  final SaveLocation saveLocation;

  /// Custom file path (required when saveLocation is SaveLocation.custom)
  final String? customPath;

  /// Optional filename for the downloaded file
  /// If not provided, will be extracted from the URL or Content-Disposition header
  final String? fileName;

  /// Creates a download request.
  ///
  /// [url] must be a valid HTTP/HTTPS URL.
  /// [customPath] is required when [saveLocation] is [SaveLocation.custom].
  const DownloadRequest({
    required this.url,
    this.headers,
    required this.saveLocation,
    this.customPath,
    this.fileName,
  }) : assert(
          saveLocation != SaveLocation.custom || customPath != null,
          'customPath is required when saveLocation is SaveLocation.custom',
        );

  @override
  String toString() {
    return 'DownloadRequest(url: $url, saveLocation: $saveLocation, '
        'fileName: $fileName, customPath: $customPath)';
  }
}
