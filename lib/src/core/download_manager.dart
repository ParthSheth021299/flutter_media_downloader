import 'dart:async';
import 'dart:collection';

import '../models/download_request.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';
import '../models/download_task_update.dart';
import '../platform/platform_downloader.dart';

/// Core download manager that orchestrates download tasks.
///
/// This class manages a queue of download tasks, enforces concurrency limits,
/// and broadcasts progress updates. It follows clean architecture principles
/// by depending on abstractions (PlatformDownloader) rather than concrete
/// implementations.
///
/// Example usage:
/// ```dart
/// final manager = DownloadManager(
///   platformDownloader: MyPlatformDownloader(),
///   maxConcurrentDownloads: 3,
/// );
///
/// // Listen to progress updates
/// manager.progressStream.listen((update) {
///   print('Task ${update.taskId}: ${update.progress * 100}%');
/// });
///
/// // Enqueue a download
/// final taskId = await manager.enqueue(
///   DownloadRequest(
///     url: 'https://example.com/file.pdf',
///     saveLocation: SaveLocation.downloads,
///   ),
/// );
/// ```
class DownloadManager {
  /// Platform-specific downloader implementation
  final PlatformDownloader _platformDownloader;

  /// Maximum number of concurrent downloads allowed
  final int maxConcurrentDownloads;

  /// Stream controller for broadcasting task updates
  final StreamController<DownloadTaskUpdate> _progressController =
      StreamController<DownloadTaskUpdate>.broadcast();

  /// Map of all tasks by their ID
  final Map<String, DownloadTask> _tasks = {};

  /// Queue of tasks waiting to be processed
  final Queue<String> _queuedTaskIds = Queue<String>();

  /// Set of currently active (downloading) task IDs
  final Set<String> _activeTaskIds = {};

  /// Counter for generating unique task IDs
  int _taskIdCounter = 0;

  /// Whether the manager has been disposed
  bool _isDisposed = false;

  /// Creates a download manager.
  ///
  /// [platformDownloader] is the platform-specific implementation.
  /// [maxConcurrentDownloads] limits how many downloads can run simultaneously.
  DownloadManager({
    required PlatformDownloader platformDownloader,
    this.maxConcurrentDownloads = 3,
  })  : assert(maxConcurrentDownloads > 0,
            'maxConcurrentDownloads must be greater than 0'),
        _platformDownloader = platformDownloader;

  /// Stream of download task updates.
  ///
  /// Emits [DownloadTaskUpdate] events whenever a task's state changes.
  /// This is a broadcast stream, so multiple listeners can subscribe.
  Stream<DownloadTaskUpdate> get progressStream => _progressController.stream;

  /// Returns an unmodifiable view of all tasks.
  Map<String, DownloadTask> get tasks => UnmodifiableMapView(_tasks);

  /// Returns the current number of active downloads.
  int get activeDownloadCount => _activeTaskIds.length;

  /// Returns the current number of queued downloads.
  int get queuedDownloadCount => _queuedTaskIds.length;

  /// Enqueues a new download request.
  ///
  /// Creates a new task, adds it to the queue, and attempts to start it
  /// if there's available capacity.
  ///
  /// Returns the unique task ID that can be used to track or cancel the download.
  ///
  /// Throws [StateError] if the manager has been disposed.
  Future<String> enqueue(DownloadRequest request) async {
    _checkNotDisposed();

    // Generate unique task ID
    final taskId = _generateTaskId();

    // Create task in queued state
    final task = DownloadTask(
      id: taskId,
      url: request.url,
      headers: request.headers,
      status: DownloadStatus.queued,
    );

    // Store task and add to queue
    _tasks[taskId] = task;
    _queuedTaskIds.add(taskId);

    // Emit queued event
    _emitUpdate(task);

    // Try to start the task if capacity available
    await _processQueue();

    return taskId;
  }

  /// Cancels a download task.
  ///
  /// If the task is currently downloading, it will be stopped.
  /// If the task is queued, it will be removed from the queue.
  ///
  /// [taskId] is the unique identifier of the task to cancel.
  ///
  /// Returns `true` if the task was canceled, `false` if the task
  /// doesn't exist or is already in a terminal state.
  ///
  /// Throws [StateError] if the manager has been disposed.
  Future<bool> cancel(String taskId) async {
    _checkNotDisposed();

    final task = _tasks[taskId];
    if (task == null) return false;

    // Can't cancel completed, failed, or already canceled tasks
    if (task.status == DownloadStatus.completed ||
        task.status == DownloadStatus.failed ||
        task.status == DownloadStatus.canceled) {
      return false;
    }

    // Remove from queue if queued
    if (task.status == DownloadStatus.queued) {
      _queuedTaskIds.remove(taskId);
    }

    // Remove from active set if downloading
    if (task.status == DownloadStatus.downloading) {
      _activeTaskIds.remove(taskId);
      // Notify platform to cancel
      await _platformDownloader.cancelDownload(taskId);
    }

    // Update task status
    final canceledTask = task.copyWith(status: DownloadStatus.canceled);
    _tasks[taskId] = canceledTask;

    // Emit canceled event
    _emitUpdate(canceledTask);

    // Process queue to start next task
    await _processQueue();

    return true;
  }

  /// Gets a task by its ID.
  ///
  /// Returns `null` if no task with the given ID exists.
  DownloadTask? getTask(String taskId) {
    return _tasks[taskId];
  }

  /// Updates a task's state (called by platform implementation).
  ///
  /// This method should be called by the platform downloader to report
  /// progress, completion, or failure.
  ///
  /// [taskId] is the ID of the task being updated.
  /// [status] is the new status.
  /// [receivedBytes] is the number of bytes downloaded so far.
  /// [totalBytes] is the total file size (-1 if unknown).
  /// [filePath] is the final file path (for completed downloads).
  /// [errorMessage] is the error description (for failed downloads).
  Future<void> updateTask({
    required String taskId,
    required DownloadStatus status,
    int receivedBytes = 0,
    int totalBytes = -1,
    String? filePath,
    String? errorMessage,
  }) async {
    _checkNotDisposed();

    final task = _tasks[taskId];
    if (task == null) return;

    // Update task
    final updatedTask = task.copyWith(
      status: status,
      receivedBytes: receivedBytes,
      totalBytes: totalBytes,
      filePath: filePath,
      errorMessage: errorMessage,
    );
    _tasks[taskId] = updatedTask;

    // Remove from active set if terminal state
    if (status == DownloadStatus.completed ||
        status == DownloadStatus.failed ||
        status == DownloadStatus.canceled) {
      _activeTaskIds.remove(taskId);
      // Process queue to start next task
      await _processQueue();
    }

    // Emit update
    _emitUpdate(updatedTask);
  }

  /// Processes the queue and starts downloads up to the concurrency limit.
  Future<void> _processQueue() async {
    while (_activeTaskIds.length < maxConcurrentDownloads &&
        _queuedTaskIds.isNotEmpty) {
      final taskId = _queuedTaskIds.removeFirst();
      final task = _tasks[taskId];

      if (task == null || task.status != DownloadStatus.queued) {
        continue;
      }

      // Mark as downloading
      _activeTaskIds.add(taskId);
      final downloadingTask = task.copyWith(status: DownloadStatus.downloading);
      _tasks[taskId] = downloadingTask;

      // Emit downloading event
      _emitUpdate(downloadingTask);

      // Start platform download
      try {
        await _platformDownloader.startDownload(downloadingTask);
      } catch (e) {
        // Handle start failure
        await updateTask(
          taskId: taskId,
          status: DownloadStatus.failed,
          errorMessage: 'Failed to start download: $e',
        );
      }
    }
  }

  /// Emits a task update to the progress stream.
  void _emitUpdate(DownloadTask task) {
    if (_isDisposed) return;

    _progressController.add(
      DownloadTaskUpdate(
        taskId: task.id,
        status: task.status,
        receivedBytes: task.receivedBytes,
        totalBytes: task.totalBytes,
        errorMessage: task.errorMessage,
        filePath: task.filePath,
      ),
    );
  }

  /// Generates a unique task ID.
  String _generateTaskId() {
    return 'task_${DateTime.now().millisecondsSinceEpoch}_${_taskIdCounter++}';
  }

  /// Checks if the manager has been disposed and throws if so.
  void _checkNotDisposed() {
    if (_isDisposed) {
      throw StateError('DownloadManager has been disposed');
    }
  }

  /// Disposes of the download manager and releases resources.
  ///
  /// Cancels all active downloads, clears the queue, and closes the
  /// progress stream. After calling dispose, the manager cannot be used.
  Future<void> dispose() async {
    if (_isDisposed) return;

    _isDisposed = true;

    // Cancel all active downloads
    final activeTaskIds = List<String>.from(_activeTaskIds);
    for (final taskId in activeTaskIds) {
      await _platformDownloader.cancelDownload(taskId);
    }

    // Clear state
    _tasks.clear();
    _queuedTaskIds.clear();
    _activeTaskIds.clear();

    // Close stream
    await _progressController.close();

    // Dispose platform downloader
    await _platformDownloader.dispose();
  }
}
