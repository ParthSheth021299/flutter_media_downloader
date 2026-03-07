import '../models/download_task.dart';

/// Abstract interface for platform-specific download implementations.
///
/// This interface defines the contract that platform implementations
/// (Android, iOS, Web, etc.) must fulfill. It follows the dependency
/// inversion principle, allowing the core engine to remain platform-agnostic.
abstract class PlatformDownloader {
  /// Starts downloading the specified task.
  ///
  /// The platform implementation should:
  /// - Initiate the HTTP request with the task's URL and headers
  /// - Report progress updates back to the engine
  /// - Handle network errors and report failures
  ///
  /// Returns a [Future] that completes when the download starts successfully.
  /// Throws an exception if the download cannot be started.
  Future<void> startDownload(DownloadTask task);

  /// Cancels an ongoing download.
  ///
  /// The platform implementation should:
  /// - Stop the HTTP request
  /// - Clean up any temporary files
  /// - Report the cancellation back to the engine
  ///
  /// [taskId] is the unique identifier of the task to cancel.
  ///
  /// Returns a [Future] that completes when the cancellation is processed.
  /// Should not throw if the task doesn't exist or is already completed.
  Future<void> cancelDownload(String taskId);

  /// Pauses an ongoing download.
  ///
  /// The platform implementation should:
  /// - Stop the HTTP request gracefully
  /// - Keep the partially downloaded file
  /// - Record the number of bytes received
  /// - Report the pause back to the engine
  ///
  /// [taskId] is the unique identifier of the task to pause.
  ///
  /// Returns a [Future] that completes when the pause is processed.
  /// Should not throw if the task doesn't exist or cannot be paused.
  Future<void> pauseDownload(String taskId);

  /// Resumes a paused download.
  ///
  /// The platform implementation should:
  /// - Check if the server supports HTTP Range requests
  /// - Send Range header with the byte offset
  /// - Expect 206 Partial Content response
  /// - Append to the existing file
  /// - Report progress back to the engine
  ///
  /// [task] is the download task to resume.
  ///
  /// Returns a [Future] that completes when the resume starts successfully.
  /// Throws an exception if resume is not supported or fails.
  Future<void> resumeDownload(DownloadTask task);

  /// Disposes of platform-specific resources.
  ///
  /// Called when the download manager is being disposed.
  /// Platform implementations should clean up any resources,
  /// close connections, and cancel pending operations.
  Future<void> dispose();
}
