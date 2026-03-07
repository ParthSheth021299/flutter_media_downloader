/// Represents the current status of a download task.
///
/// The download lifecycle follows this flow:
/// queued -> downloading -> completed/failed/canceled
/// downloading -> paused -> resuming -> downloading
enum DownloadStatus {
  /// Task is waiting in the queue to be processed
  queued,

  /// Task is actively downloading
  downloading,

  /// Task has been paused and can be resumed
  paused,

  /// Task is resuming from a paused state
  resuming,

  /// Task has completed successfully
  completed,

  /// Task has failed due to an error
  failed,

  /// Task was canceled by the user
  canceled,
}
