import 'download_status.dart';

/// Represents an update event for a download task.
///
/// This model is emitted through the progress stream to notify listeners
/// of changes to a download task's state.
class DownloadTaskUpdate {
  /// The ID of the task being updated
  final String taskId;

  /// The new status of the task
  final DownloadStatus status;

  /// Number of bytes received so far
  final int receivedBytes;

  /// Total number of bytes to download (-1 if unknown)
  final int totalBytes;

  /// Optional error message if status is failed
  final String? errorMessage;

  /// Optional file path when download completes
  final String? filePath;

  /// Creates a download task update.
  const DownloadTaskUpdate({
    required this.taskId,
    required this.status,
    this.receivedBytes = 0,
    this.totalBytes = -1,
    this.errorMessage,
    this.filePath,
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

  @override
  String toString() {
    return 'DownloadTaskUpdate(taskId: $taskId, status: $status, '
        'progress: ${(progress * 100).toStringAsFixed(1)}%, '
        'receivedBytes: $receivedBytes, totalBytes: $totalBytes)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DownloadTaskUpdate &&
        other.taskId == taskId &&
        other.status == status &&
        other.receivedBytes == receivedBytes &&
        other.totalBytes == totalBytes &&
        other.errorMessage == errorMessage &&
        other.filePath == filePath;
  }

  @override
  int get hashCode {
    return Object.hash(
      taskId,
      status,
      receivedBytes,
      totalBytes,
      errorMessage,
      filePath,
    );
  }
}
