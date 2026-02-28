import '../models/download_task.dart';
import '../platform/platform_downloader.dart';
import '../platform/platform_downloader_factory.dart';
import 'download_manager.dart';

/// Factory for creating [DownloadManager] instances with platform-specific downloaders.
///
/// This factory simplifies the creation of a fully configured download manager
/// by automatically selecting and instantiating the appropriate platform downloader.
///
/// Example usage:
/// ```dart
/// final manager = DownloadManagerFactory.create(
///   maxConcurrentDownloads: 3,
/// );
/// ```
class DownloadManagerFactory {
  /// Creates a [DownloadManager] with a platform-specific downloader.
  ///
  /// [maxConcurrentDownloads] limits how many downloads can run simultaneously.
  /// Defaults to 3.
  ///
  /// Returns a fully configured [DownloadManager] ready to use.
  static DownloadManager create({
    int maxConcurrentDownloads = 3,
  }) {
    // Create manager with a lazy downloader wrapper
    // The actual platform downloader is created on first use
    DownloadManager? managerRef;

    final manager = DownloadManager(
      platformDownloader: _LazyPlatformDownloader(() {
        final ref = managerRef;
        if (ref == null) {
          throw StateError('Manager not initialized');
        }
        return PlatformDownloaderFactory.create(ref);
      }),
      maxConcurrentDownloads: maxConcurrentDownloads,
    );

    managerRef = manager;
    return manager;
  }
}

/// Internal lazy wrapper for platform downloader initialization.
///
/// This wrapper delays the creation of the actual platform downloader
/// until it's first used, allowing us to pass the DownloadManager
/// reference to the platform downloader constructor.
class _LazyPlatformDownloader implements PlatformDownloader {
  final PlatformDownloader Function() _factory;
  PlatformDownloader? _instance;

  _LazyPlatformDownloader(this._factory);

  PlatformDownloader get _downloader {
    return _instance ??= _factory();
  }

  @override
  Future<void> startDownload(DownloadTask task) {
    return _downloader.startDownload(task);
  }

  @override
  Future<void> cancelDownload(String taskId) {
    return _downloader.cancelDownload(taskId);
  }

  @override
  Future<void> dispose() async {
    final instance = _instance;
    if (instance != null) {
      await instance.dispose();
    }
  }
}
