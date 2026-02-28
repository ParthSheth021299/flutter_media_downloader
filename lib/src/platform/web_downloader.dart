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
class WebDownloader implements PlatformDownloader {
  /// Reference to the download manager for reporting updates
  final DownloadManager _downloadManager;

  /// Map of active HTTP requests for cancellation
  final Map<String, html.HttpRequest> _activeRequests = {};

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

            // Extract filename
            final fileName = _extractFileName(task.url, request);

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
  }

  @override
  Future<void> dispose() async {
    // Abort all active requests
    for (final request in _activeRequests.values) {
      request.abort();
    }
    _activeRequests.clear();
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
