import 'dart:async';
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;

import '../core/download_manager.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';
import 'platform_downloader.dart';

/// Factory function for conditional imports.
PlatformDownloader createPlatformDownloader(DownloadManager downloadManager) {
  return WebDownloader(downloadManager);
}

/// Web platform downloader using dart:html.
///
/// This implementation uses [html.HttpRequest] with progress events
/// to download files in the browser. Files are converted to Blobs
/// and triggered for download using anchor elements.
///
/// Note: Pause/resume support is limited on web platform due to browser
/// constraints. Resume is only supported if the browser allows partial
/// content fetching.
class WebDownloader implements PlatformDownloader {
  /// Reference to the download manager for reporting updates
  final DownloadManager _downloadManager;

  /// Map of active HTTP requests for cancellation
  final Map<String, html.HttpRequest> _activeRequests = {};

  /// Map of partially downloaded blobs for pause/resume
  final Map<String, List<html.Blob>> _partialBlobs = {};

  /// Map of task metadata for resume
  final Map<String, _WebDownloadMetadata> _taskMetadata = {};

  /// Creates a web-based downloader.
  ///
  /// [downloadManager] is used to report progress updates.
  WebDownloader(this._downloadManager);

  @override
  Future<void> startDownload(DownloadTask task) async {
    final completer = Completer<void>();

    try {
      // Create HTTP request
      final request = html.HttpRequest();
      _activeRequests[task.id] = request;

      // Configure request
      request.open('GET', task.url);
      request.responseType = 'blob';

      // Add custom headers
      if (task.headers != null) {
        task.headers!.forEach((key, value) {
          request.setRequestHeader(key, value);
        });
      }

      // Track progress
      request.onProgress.listen((event) {
        if (event.lengthComputable) {
          _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.downloading,
            receivedBytes: event.loaded ?? 0,
            totalBytes: event.total ?? -1,
          );
        }
      });

      // Handle completion
      request.onLoad.listen((event) async {
        _activeRequests.remove(task.id);

        if (request.status == 200 || request.status == 206) {
          try {
            // Get blob response
            final blob = request.response as html.Blob?;
            if (blob == null) {
              throw Exception('Response is not a Blob');
            }

            // Check if server supports resume
            final acceptRanges = request.getResponseHeader('Accept-Ranges');
            final supportsResume =
                acceptRanges != null && acceptRanges != 'none';

            // Extract filename
            final fileName = _extractFileName(task.url, request);

            // Store metadata for potential resume
            _taskMetadata[task.id] = _WebDownloadMetadata(
              fileName: fileName,
              totalBytes: blob.size,
              supportsResume: supportsResume,
            );

            // Trigger download
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute('download', fileName)
              ..style.display = 'none';

            html.document.body?.append(anchor);
            anchor.click();
            anchor.remove();

            html.Url.revokeObjectUrl(url);

            // Report completion
            await _downloadManager.updateTask(
              taskId: task.id,
              status: DownloadStatus.completed,
              receivedBytes: blob.size,
              totalBytes: blob.size,
              filePath: fileName,
              supportsResume: supportsResume,
            );

            completer.complete();
          } catch (e) {
            await _downloadManager.updateTask(
              taskId: task.id,
              status: DownloadStatus.failed,
              errorMessage: 'Failed to process download: $e',
            );
            completer.completeError(e);
          }
        } else {
          final error = 'HTTP ${request.status}: ${request.statusText}';
          await _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.failed,
            errorMessage: error,
          );
          completer.completeError(Exception(error));
        }
      });

      // Handle errors
      request.onError.listen((event) async {
        _activeRequests.remove(task.id);

        await _downloadManager.updateTask(
          taskId: task.id,
          status: DownloadStatus.failed,
          errorMessage: 'Network error occurred',
        );

        completer.completeError(Exception('Network error'));
      });

      // Handle abort
      request.onAbort.listen((event) async {
        _activeRequests.remove(task.id);

        await _downloadManager.updateTask(
          taskId: task.id,
          status: DownloadStatus.canceled,
        );

        completer.complete();
      });

      // Send request
      request.send();

      return completer.future;
    } catch (e) {
      _activeRequests.remove(task.id);

      await _downloadManager.updateTask(
        taskId: task.id,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );

      rethrow;
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    final request = _activeRequests[taskId];
    if (request != null) {
      request.abort();
      _activeRequests.remove(taskId);
    }

    // Clean up metadata
    _taskMetadata.remove(taskId);
    _partialBlobs.remove(taskId);
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    // On web, we can't truly pause an ongoing request
    // We abort it and rely on browser cache or restart
    final request = _activeRequests[taskId];
    if (request != null) {
      request.abort();
      _activeRequests.remove(taskId);
    }
    // Keep metadata for potential resume
  }

  @override
  Future<void> resumeDownload(DownloadTask task) async {
    // Check if server supports resume
    if (!task.supportsResume) {
      // Server doesn't support resume, fail with proper error
      await _downloadManager.updateTask(
        taskId: task.id,
        status: DownloadStatus.failed,
        errorMessage:
            'Resume not supported: Server does not support Range requests',
      );
      return;
    }

    // On web platform, true pause/resume is limited
    // We attempt to use Range requests if supported
    final completer = Completer<void>();

    try {
      // Create HTTP request with Range header
      final request = html.HttpRequest();
      _activeRequests[task.id] = request;

      // Configure request
      request.open('GET', task.url);
      request.responseType = 'blob';

      // Add custom headers
      if (task.headers != null) {
        task.headers!.forEach((key, value) {
          request.setRequestHeader(key, value);
        });
      }

      // Add Range header
      request.setRequestHeader('Range', 'bytes=${task.receivedBytes}-');

      // Track progress
      request.onProgress.listen((event) {
        if (event.lengthComputable) {
          final totalReceived = task.receivedBytes + (event.loaded ?? 0);
          _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.downloading,
            receivedBytes: totalReceived,
            totalBytes: task.totalBytes,
          );
        }
      });

      // Handle completion
      request.onLoad.listen((event) async {
        _activeRequests.remove(task.id);

        if (request.status == 206) {
          // Partial content - resume successful
          try {
            final blob = request.response as html.Blob?;
            if (blob == null) {
              throw Exception('Response is not a Blob');
            }

            // Get metadata
            final metadata = _taskMetadata[task.id];
            final fileName = metadata?.fileName ?? task.filePath ?? 'download';

            // Note: On web, we can't truly append to the previous download
            // The browser will handle the download separately
            // This is a limitation of the web platform
            final url = html.Url.createObjectUrlFromBlob(blob);
            final anchor = html.AnchorElement(href: url)
              ..setAttribute('download', fileName)
              ..style.display = 'none';

            html.document.body?.append(anchor);
            anchor.click();
            anchor.remove();

            html.Url.revokeObjectUrl(url);

            final totalReceived = task.receivedBytes + blob.size;

            await _downloadManager.updateTask(
              taskId: task.id,
              status: DownloadStatus.completed,
              receivedBytes: totalReceived,
              totalBytes: task.totalBytes,
              filePath: fileName,
              supportsResume: true,
            );

            completer.complete();
          } catch (e) {
            await _downloadManager.updateTask(
              taskId: task.id,
              status: DownloadStatus.failed,
              errorMessage: 'Failed to resume download: $e',
            );
            completer.completeError(e);
          }
        } else if (request.status == 200) {
          // Server doesn't support range, restart from beginning
          await _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.failed,
            errorMessage:
                'Resume not supported: Server returned full content instead of partial',
          );
          completer.completeError(Exception('Resume not supported'));
        } else if (request.status == 416) {
          // Range not satisfiable
          await _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.failed,
            errorMessage: 'Resume failed: Range not satisfiable',
          );
          completer.completeError(Exception('Range not satisfiable'));
        } else {
          final error = 'HTTP ${request.status}: ${request.statusText}';
          await _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.failed,
            errorMessage: 'Resume failed: $error',
          );
          completer.completeError(Exception(error));
        }
      });

      // Handle errors
      request.onError.listen((event) async {
        _activeRequests.remove(task.id);

        await _downloadManager.updateTask(
          taskId: task.id,
          status: DownloadStatus.failed,
          errorMessage: 'Network error during resume',
        );

        completer.completeError(Exception('Network error'));
      });

      // Handle abort
      request.onAbort.listen((event) async {
        _activeRequests.remove(task.id);

        await _downloadManager.updateTask(
          taskId: task.id,
          status: DownloadStatus.canceled,
        );

        completer.complete();
      });

      // Send request
      request.send();

      return completer.future;
    } catch (e) {
      _activeRequests.remove(task.id);

      await _downloadManager.updateTask(
        taskId: task.id,
        status: DownloadStatus.failed,
        errorMessage: 'Failed to resume: $e',
      );

      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    // Abort all active requests
    for (final request in _activeRequests.values) {
      request.abort();
    }
    _activeRequests.clear();
    _taskMetadata.clear();
    _partialBlobs.clear();
  }

  /// Extracts filename from URL or Content-Disposition header.
  String _extractFileName(String url, html.HttpRequest request) {
    // Try Content-Disposition header first
    final contentDisposition = request.getResponseHeader('Content-Disposition');
    if (contentDisposition != null) {
      final match = RegExp(r'filename[^;=\n]*=((["\x27]).*?\2|[^;\n]*)')
          .firstMatch(contentDisposition);
      if (match != null) {
        final fileName =
            match.group(1)?.replaceAll(RegExp(r'["\x27]'), '').trim();
        if (fileName != null && fileName.isNotEmpty) {
          return fileName;
        }
      }
    }

    // Fallback to URL
    final uri = Uri.parse(url);
    final pathSegments = uri.pathSegments;
    if (pathSegments.isNotEmpty) {
      final fileName = pathSegments.last;
      if (fileName.isNotEmpty) {
        return fileName;
      }
    }

    // Last resort: generate filename
    return 'download_${DateTime.now().millisecondsSinceEpoch}';
  }
}

/// Internal class to store download metadata for resume.
class _WebDownloadMetadata {
  final String fileName;
  final int totalBytes;
  final bool supportsResume;

  _WebDownloadMetadata({
    required this.fileName,
    required this.totalBytes,
    required this.supportsResume,
  });
}
