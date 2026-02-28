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

  /// Disposes of platform-specific resources.
  ///
  /// Called when the download manager is being disposed.
  /// Platform implementations should clean up any resources,
  /// close connections, and cancel pending operations.
  Future<void> dispose();
}
