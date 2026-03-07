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
///
/// Supports pause and resume using HTTP Range requests.
class IODownloader implements PlatformDownloader {
  /// Reference to the download manager for reporting updates
  final DownloadManager _downloadManager;

  /// HTTP client for making requests
  final HttpClient _httpClient;

  /// Map of active download cancellation tokens
  final Map<String, _DownloadCancellation> _activeCancellations = {};

  /// Map of active download file handles for pause/resume
  final Map<String, RandomAccessFile> _activeFiles = {};

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

      // Check if server supports resume (Accept-Ranges header)
      final acceptRanges = response.headers.value('accept-ranges');
      final supportsResume = acceptRanges != null && acceptRanges != 'none';

      // Determine save path
      final savePath = await _determineSavePath(task, response);

      // Create file
      final file = File(savePath);
      await file.parent.create(recursive: true);

      // Check if canceled before downloading
      if (cancellation.isCanceled) {
        return;
      }

      // Open file for writing
      final raf = await file.open(mode: FileMode.write);
      _activeFiles[task.id] = raf;

      // Download with progress tracking
      int receivedBytes = 0;

      try {
        await for (final chunk in response) {
          if (cancellation.isCanceled) {
            break;
          }

          if (cancellation.isPaused) {
            // Save current position and break
            break;
          }

          await raf.writeFrom(chunk);
          receivedBytes += chunk.length;

          // Report progress
          await _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.downloading,
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            filePath: savePath,
            supportsResume: supportsResume,
          );
        }

        await raf.flush();
        await raf.close();
        _activeFiles.remove(task.id);

        // Check if canceled or paused after download
        if (cancellation.isCanceled) {
          await file.delete();
          return;
        }

        if (cancellation.isPaused) {
          // Keep the file for resume
          return;
        }

        // Report completion
        await _downloadManager.updateTask(
          taskId: task.id,
          status: DownloadStatus.completed,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          filePath: savePath,
          supportsResume: supportsResume,
        );
      } catch (e) {
        await raf.close();
        _activeFiles.remove(task.id);
        // Clean up partial file on error
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

    // Close file handle if open
    final raf = _activeFiles[taskId];
    if (raf != null) {
      await raf.close();
      _activeFiles.remove(taskId);
    }
  }

  @override
  Future<void> pauseDownload(String taskId) async {
    final cancellation = _activeCancellations[taskId];
    if (cancellation != null) {
      cancellation.pause();
    }

    // Close file handle if open (will be reopened on resume)
    final raf = _activeFiles[taskId];
    if (raf != null) {
      await raf.close();
      _activeFiles.remove(taskId);
    }
  }

  @override
  Future<void> resumeDownload(DownloadTask task) async {
    // Validate that we can resume
    if (task.filePath == null || task.filePath!.isEmpty) {
      throw Exception('Cannot resume: file path is not set');
    }

    final file = File(task.filePath!);
    if (!await file.exists()) {
      throw Exception('Cannot resume: partial file does not exist');
    }

    // Check if server supports resume
    if (!task.supportsResume) {
      // Server doesn't support resume, restart from beginning
      await file.delete();
      await startDownload(task.copyWith(
        receivedBytes: 0,
        status: DownloadStatus.downloading,
      ));
      return;
    }

    final cancellation = _DownloadCancellation();
    _activeCancellations[task.id] = cancellation;

    try {
      // Parse URL
      final uri = Uri.parse(task.url);

      // Create HTTP request with Range header
      final request = await _httpClient.getUrl(uri);

      // Add custom headers
      if (task.headers != null) {
        task.headers!.forEach((key, value) {
          request.headers.add(key, value);
        });
      }

      // Add Range header to resume from last byte
      request.headers.add('Range', 'bytes=${task.receivedBytes}-');

      // Check if canceled before sending
      if (cancellation.isCanceled) {
        request.abort();
        return;
      }

      // Send request
      final response = await request.close();

      // Validate response
      if (response.statusCode == 416) {
        // Range not satisfiable - file is already complete or invalid
        throw Exception(
            'Resume failed: Range not satisfiable (file may be complete)');
      }

      if (response.statusCode == 200) {
        // Server doesn't support range, restart from beginning
        await file.delete();
        await startDownload(task.copyWith(
          receivedBytes: 0,
          status: DownloadStatus.downloading,
        ));
        return;
      }

      if (response.statusCode != 206) {
        throw HttpException(
          'HTTP ${response.statusCode}: ${response.reasonPhrase}',
        );
      }

      // Validate content range
      final contentRange = response.headers.value('content-range');
      if (contentRange != null) {
        // Parse content-range: bytes start-end/total
        final rangeMatch =
            RegExp(r'bytes (\d+)-(\d+)/(\d+)').firstMatch(contentRange);
        if (rangeMatch != null) {
          final startByte = int.parse(rangeMatch.group(1)!);
          final totalBytes = int.parse(rangeMatch.group(3)!);

          // Validate that server is sending from correct position
          if (startByte != task.receivedBytes) {
            throw Exception(
                'Resume failed: Server returned incorrect byte range');
          }

          // Validate total size hasn't changed
          if (task.totalBytes > 0 && totalBytes != task.totalBytes) {
            // File size changed, restart download
            await file.delete();
            await startDownload(task.copyWith(
              receivedBytes: 0,
              status: DownloadStatus.downloading,
            ));
            return;
          }
        }
      }

      // Get total bytes (may be different from content-length for partial content)
      int totalBytes = task.totalBytes;
      if (contentRange != null) {
        final rangeMatch =
            RegExp(r'bytes \d+-\d+/(\d+)').firstMatch(contentRange);
        if (rangeMatch != null) {
          totalBytes = int.parse(rangeMatch.group(1)!);
        }
      }

      // Check if canceled before downloading
      if (cancellation.isCanceled) {
        return;
      }

      // Open file for appending
      final raf = await file.open(mode: FileMode.append);
      _activeFiles[task.id] = raf;

      // Resume download with progress tracking
      int receivedBytes = task.receivedBytes;

      try {
        await for (final chunk in response) {
          if (cancellation.isCanceled) {
            break;
          }

          if (cancellation.isPaused) {
            // Save current position and break
            break;
          }

          await raf.writeFrom(chunk);
          receivedBytes += chunk.length;

          // Report progress
          await _downloadManager.updateTask(
            taskId: task.id,
            status: DownloadStatus.downloading,
            receivedBytes: receivedBytes,
            totalBytes: totalBytes,
            filePath: task.filePath,
            supportsResume: true,
          );
        }

        await raf.flush();
        await raf.close();
        _activeFiles.remove(task.id);

        // Check if canceled or paused after download
        if (cancellation.isCanceled) {
          await file.delete();
          return;
        }

        if (cancellation.isPaused) {
          // Keep the file for resume
          return;
        }

        // Report completion
        await _downloadManager.updateTask(
          taskId: task.id,
          status: DownloadStatus.completed,
          receivedBytes: receivedBytes,
          totalBytes: totalBytes,
          filePath: task.filePath,
          supportsResume: true,
        );
      } catch (e) {
        await raf.close();
        _activeFiles.remove(task.id);
        rethrow;
      }
    } catch (e) {
      // Report failure
      await _downloadManager.updateTask(
        taskId: task.id,
        status: DownloadStatus.failed,
        errorMessage: 'Resume failed: $e',
      );
    } finally {
      _activeCancellations.remove(task.id);
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

/// Internal class to handle download cancellation and pause.
class _DownloadCancellation {
  bool _isCanceled = false;
  bool _isPaused = false;

  bool get isCanceled => _isCanceled;
  bool get isPaused => _isPaused;

  void cancel() {
    _isCanceled = true;
  }

  void pause() {
    _isPaused = true;
  }
}
