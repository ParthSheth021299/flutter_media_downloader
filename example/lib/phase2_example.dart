// ignore_for_file: avoid_print

import 'package:flutter_media_downloader/flutter_media_downloader.dart';

/// Example demonstrating Phase 2 cross-platform download functionality.
///
/// This example shows how to:
/// - Create a download manager with platform-specific implementation
/// - Enqueue multiple downloads
/// - Listen to progress updates
/// - Cancel downloads
/// - Handle completion and errors
///
/// Note: This is a standalone example file, not integrated into the example app.
/// To use this in a real app, call these functions from your UI code.
void main() async {
  await runDownloadExample();
}

Future<void> runDownloadExample() async {
  print('=== Flutter Media Downloader - Phase 2 Example ===\n');

  // Create download manager with platform-specific implementation
  // The factory automatically selects:
  // - IODownloader for Android, iOS, Windows, macOS, Linux
  // - WebDownloader for Web
  final manager = DownloadManagerFactory.create(
    maxConcurrentDownloads: 2, // Allow 2 simultaneous downloads
  );

  print('✓ Download manager created');
  print('  Max concurrent downloads: ${manager.maxConcurrentDownloads}\n');

  // Listen to progress updates
  final subscription = manager.progressStream.listen((update) {
    final progress = (update.progress * 100).toStringAsFixed(1);

    switch (update.status) {
      case DownloadStatus.queued:
        print('[${update.taskId}] Queued');
        break;

      case DownloadStatus.downloading:
        print('[${update.taskId}] Downloading: $progress% '
            '(${update.receivedBytes}/${update.totalBytes} bytes)');
        break;

      case DownloadStatus.completed:
        print('[${update.taskId}] ✓ Completed');
        print('  File saved to: ${update.filePath}\n');
        break;

      case DownloadStatus.failed:
        print('[${update.taskId}] ✗ Failed');
        print('  Error: ${update.errorMessage}\n');
        break;

      case DownloadStatus.canceled:
        print('[${update.taskId}] ⊗ Canceled\n');
        break;
    }
  });

  try {
    // Example 1: Download a PDF file
    print('Enqueueing download 1...');
    final task1 = await manager.enqueue(
      DownloadRequest(
        url:
            'https://www.w3.org/WAI/ER/tests/xhtml/testfiles/resources/pdf/dummy.pdf',
        saveLocation: SaveLocation.downloads,
        fileName: 'example1.pdf',
      ),
    );
    print('  Task ID: $task1\n');

    // Example 2: Download with custom headers
    print('Enqueueing download 2...');
    final task2 = await manager.enqueue(
      DownloadRequest(
        url: 'https://httpbin.org/image/png',
        saveLocation: SaveLocation.downloads,
        fileName: 'example2.png',
        headers: {
          'User-Agent': 'FlutterMediaDownloader/2.0',
        },
      ),
    );
    print('  Task ID: $task2\n');

    // Example 3: Download that will be canceled
    print('Enqueueing download 3 (will be canceled)...');
    final task3 = await manager.enqueue(
      DownloadRequest(
        url: 'https://httpbin.org/delay/10', // Slow endpoint
        saveLocation: SaveLocation.downloads,
      ),
    );
    print('  Task ID: $task3\n');

    // Wait a bit then cancel task 3
    await Future.delayed(Duration(seconds: 2));
    print('Canceling download 3...');
    final canceled = await manager.cancel(task3);
    print('  Canceled: $canceled\n');

    // Check queue status
    print('Queue status:');
    print('  Active downloads: ${manager.activeDownloadCount}');
    print('  Queued downloads: ${manager.queuedDownloadCount}\n');

    // Wait for remaining downloads to complete
    print('Waiting for downloads to complete...\n');
    await Future.delayed(Duration(seconds: 10));

    // Get final task status
    final finalTask1 = manager.getTask(task1);
    final finalTask2 = manager.getTask(task2);

    print('Final status:');
    print('  Task 1: ${finalTask1?.status} (${finalTask1?.progress})');
    print('  Task 2: ${finalTask2?.status} (${finalTask2?.progress})');
  } finally {
    // Clean up
    await subscription.cancel();
    await manager.dispose();
    print('\n✓ Download manager disposed');
  }
}

/// Example showing error handling
Future<void> runErrorHandlingExample() async {
  final manager = DownloadManagerFactory.create();

  manager.progressStream.listen((update) {
    if (update.status == DownloadStatus.failed) {
      print('Download failed: ${update.errorMessage}');
      // Handle error (show notification, retry, etc.)
    }
  });

  // This will fail with 404
  await manager.enqueue(
    DownloadRequest(
      url: 'https://httpbin.org/status/404',
      saveLocation: SaveLocation.downloads,
    ),
  );

  await Future.delayed(Duration(seconds: 5));
  await manager.dispose();
}

/// Example showing concurrent download management
Future<void> runConcurrencyExample() async {
  final manager = DownloadManagerFactory.create(
    maxConcurrentDownloads: 2, // Only 2 at a time
  );

  // Enqueue 5 downloads - only 2 will run simultaneously
  final tasks = <String>[];
  for (int i = 1; i <= 5; i++) {
    final taskId = await manager.enqueue(
      DownloadRequest(
        url: 'https://httpbin.org/delay/$i',
        saveLocation: SaveLocation.downloads,
        fileName: 'file$i.txt',
      ),
    );
    tasks.add(taskId);
    print('Enqueued task $i: $taskId');
  }

  print('\nActive: ${manager.activeDownloadCount}'); // Will be 2
  print('Queued: ${manager.queuedDownloadCount}'); // Will be 3

  await Future.delayed(Duration(seconds: 30));
  await manager.dispose();
}
