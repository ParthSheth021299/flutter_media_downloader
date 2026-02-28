import 'dart:async';
import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../core/download_manager.dart';
import '../models/download_status.dart';
import '../models/download_task.dart';
import 'platform_downloader.dart';

/// Factory function for conditional imports.
PlatformDownloader createPlatformDownloader(DownloadManager downloadManager) {
  return IODownloader(downloadManager);
}

/// Desktop/Mobile platform downloader using dart:io.
///
/// This implementation uses [HttpClient] to download files with
/// chunked streaming for memory efficiency. Supports Android, iOS,
/// Windows, macOS, and Linux platforms.
class IODownloader implements PlatformDownloader {
  /// Reference to the download manager for reporting updates
  final DownloadManager _downloadManager;

  /// HTTP client for making requests
  final HttpClient _httpClient;

  /// Map of active download cancellation tokens
  final Map<String, _DownloadCancellation> _activeCancellations = {};

  /// Creates an IO-based downloader.
  ///
  /// [downloadManager] is used to report progress updates.
  IODownloader(this._downloadManager) : _httpClient = HttpClient();

  @override
  Future<void> startDownload(DownloadTask task) async {
    final cancellation = _DownloadCancellation();
    _activeCancellations[task.id] = cancellation;

    try {
      // Parse URL
      final uri = Uri.parse(task.url);

      // Create HTTP request
      final request = await _httpClient.getUrl(uri);

      // Add custom headers
      if (task.headers != null) {
        task.headers!.forEach((key, value) {
          request.headers.add(key, value);
        });
      }

      // Check if canceled before sending
      if (cancellation.isCanceled) {
        request.abort();
        return;
      }

      // Send request
      final response = await request.close();

      // Check status code
      if (response.statusCode != 200 && response.statusCode != 206) {
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      // Get content length
      final totalBytes = response.contentLength;

      // Determine save path
      final savePath = await _determineSavePath(task, response);

      // Create file
      final file = File(savePath);
      await file.parent.create(recursive: true);

      // Check if canceled before downloading
      if (cancellation.isCanceled) {
        return;
      }

      // Download with progress tracking
      final sink = file.openWrite();
      int receivedBytes = 0;

      try {
        await for (final chunk in response) {
          if (cancellation.isCanceled) {
            await sink.close();
            await file.delete();
            return;
          }

          sink.add(chunk);
          receivedBytes += chunk.length;

          // Report progress
          await _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.downloading,
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
          );
        }

        await sink.flush();
        await sink.close();

        // Check if canceled after download
        if (cancellation.isCanceled) {
          await file.delete();
          return;
        }

        // Report completion
        await _downloadManager.updateTask(
          taskId: task.id,
          status: DownloadStatus.completed,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          filePath: savePath,
        );
      } catch (e) {
        await sink.close();
        // Clean up partial file
        if (await file.exists()) {
          await file.delete();
        }
        rethrow;
      }
    } catch (e) {
      // Report failure
      await _downloadManager.updateTask(
        taskId: task.id,
        status: DownloadStatus.failed,
        errorMessage: e.toString(),
      );
    } finally {
      _activeCancellations.remove(task.id);
    }
  }

  @override
  Future<void> cancelDownload(String taskId) async {
    final cancellation = _activeCancellations[taskId];
    if (cancellation != null) {
      cancellation.cancel();
    }
  }

  @override
  Future<void> dispose() async {
    // Cancel all active downloads
    for (final cancellation in _activeCancellations.values) {
      cancellation.cancel();
    }
    _activeCancellations.clear();

    // Close HTTP client
    _httpClient.close(force: true);
  }

  /// Determines the save path for the downloaded file.
  Future<String> _determineSavePath(
    DownloadTask task,
    HttpClientResponse response,
  ) async {
    // Extract filename from URL or Content-Disposition header
    String? fileName;

    // Try Content-Disposition header first
    final contentDisposition = response.headers.value('content-disposition');
    if (contentDisposition != null) {
      final match = RegExp(r'filename[^;=\n]*=((["\x27]).*?\2|[^;\n]*)')
          .firstMatch(contentDisposition);
      if (match != null) {
        fileName = match.group(1)?.replaceAll(RegExp(r'["\x27]'), '').trim();
      }
    }

    // Fallback to URL
    fileName ??= path.basename(Uri.parse(task.url).path);

    // Ensure filename is not empty
    if (fileName.isEmpty) {
      fileName = 'download_${DateTime.now().millisecondsSinceEpoch}';
    }

    // Get base directory
    // Default to downloads directory for now
    // In Phase 3+, this would use SaveLocation from DownloadRequest
    Directory directory;

    if (Platform.isAndroid || Platform.isIOS) {
      // Mobile: use app documents directory
      directory = await getApplicationDocumentsDirectory();
    } else {
      // Desktop: use downloads directory
      directory = await getDownloadsDirectory() ??
          await getApplicationDocumentsDirectory();
    }

    return path.join(directory.path, fileName);
  }
}

/// Internal class to handle download cancellation.
class _DownloadCancellation {
  bool _isCanceled = false;

  bool get isCanceled => _isCanceled;

  void cancel() {
    _isCanceled = true;
  }
}
