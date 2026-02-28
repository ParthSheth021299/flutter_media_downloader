import 'download_status.dart';

/// Represents a download task with its current state.
///
/// This is the core model that tracks the progress and status of a download.
class DownloadTask {
  /// Unique identifier for this download task
  final String id;

  /// The URL being downloaded
  final String url;

  /// Optional HTTP headers for the request
  final Map<String, String>? headers;

  /// Current status of the download
  final DownloadStatus status;

  /// Number of bytes received so far
  final int receivedBytes;

  /// Total number of bytes to download (-1 if unknown)
  final int totalBytes;

  /// Path where the file will be/is saved (null until determined)
  final String? filePath;

  /// Optional error message if status is failed
  final String? errorMessage;

  /// Creates a download task.
  const DownloadTask({
    required this.id,
    required this.url,
    this.headers,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.filePath,
    this.errorMessage,
  });

  /// Calculates the download progress as a value between 0.0 and 1.0.
  ///
  /// Returns 0.0 if totalBytes is unknown or invalid.
  /// Returns 1.0 if download is completed.
  double get progress {
    if (status == DownloadStatus.completed) return 1.0;
    if (totalBytes <= 0) return 0.0;
    return (receivedBytes / totalBytes).clamp(0.0, 1.0);
  }

  /// Creates a copy of this task with updated fields.
  DownloadTask copyWith({
    String? id,
    String? url,
    Map<String, String>? headers,
    DownloadStatus? status,
    int? receivedBytes,
    int? totalBytes,
    String? filePath,
    String? errorMessage,
  }) {
    return DownloadTask(
      id: id ?? this.id,
      url: url ?? this.url,
      headers: headers ?? this.headers,
      status: status ?? this.status,
      receivedBytes: receivedBytes ?? this.receivedBytes,
      totalBytes: totalBytes ?? this.totalBytes,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  String toString() {
    return 'DownloadTask(id: $id, url: $url, status: $status, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'receivedBytes: $receivedBytes, totalBytes: $totalBytes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DownloadTask &&
        other.id == id &&
        other.url == url &&
        other.status == status &&
        other.receivedBytes == receivedBytes &&
        other.totalBytes == totalBytes &&
        other.filePath == filePath;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      url,
      status,
      receivedBytes,
      totalBytes,
      filePath,
    );
  }
}
