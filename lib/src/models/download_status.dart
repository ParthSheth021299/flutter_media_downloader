/// Represents the current status of a download task.
///
/// The download lifecycle follows this flow:
/// queued -> downloading -> completed/failed/canceled
enum DownloadStatus {
  /// Task is waiting in the queue to be processed
  queued,

  /// Task is actively downloading
  downloading,

  /// Task has completed successfully
  completed,

  /// Task has failed due to an error
  failed,

  /// Task was canceled by the user
  canceled,
}
