/// Flutter Media Downloader - A cross-platform download manager for Flutter.
///
/// This library provides a clean, architecture-driven approach to downloading
/// files across all Flutter platforms (Android, iOS, Web, Windows, macOS, Linux).
///
/// ## Features
/// - Cross-platform support (Mobile, Web, Desktop)
/// - Concurrent download management with configurable limits
/// - Real-time progress tracking
/// - Pause and resume support with HTTP Range requests
/// - Automatic queue management
/// - Clean architecture with dependency inversion
///
/// ## Usage
///
/// ```dart
/// import 'package:flutter_media_downloader/flutter_media_downloader.dart';
///
/// // Create a download manager
/// final manager = DownloadManagerFactory.create(
///   maxConcurrentDownloads: 3,
/// );
///
/// // Listen to progress updates
/// manager.progressStream.listen((update) {
///   print('Progress: ${update.progress * 100}%');
///   print('Status: ${update.status}');
/// });
///
/// // Enqueue a download
/// final taskId = await manager.enqueue(
///   DownloadRequest(
///     url: 'https://example.com/file.pdf',
///     saveLocation: SaveLocation.downloads,
///   ),
/// );
///
/// // Pause a download
/// await manager.pause(taskId);
///
/// // Resume a paused download
/// await manager.resume(taskId);
///
/// // Cancel a download
/// await manager.cancel(taskId);
///
/// // Dispose when done
/// await manager.dispose();
/// ```
library;

// Core
export 'src/core/download_manager.dart';
export 'src/core/download_manager_factory.dart';

// Models
export 'src/models/download_request.dart';
export 'src/models/download_status.dart';
export 'src/models/download_task.dart';
export 'src/models/download_task_update.dart';
export 'src/models/save_location.dart';

// Platform (only export the abstract interface and factory)
export 'src/platform/platform_downloader.dart';
export 'src/platform/platform_downloader_factory.dart';
