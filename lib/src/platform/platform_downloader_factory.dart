import '../core/download_manager.dart';
import 'platform_downloader.dart';
import 'platform_downloader_stub.dart'
    if (dart.library.html) 'web_downloader.dart'
    if (dart.library.io) 'io_downloader.dart';

/// Factory for creating platform-specific downloader instances.
///
/// This factory uses conditional imports to select the appropriate
/// implementation based on the target platform:
/// - Web: [WebDownloader] using dart:html
/// - Mobile/Desktop: [IODownloader] using dart:io
class PlatformDownloaderFactory {
  /// Creates a platform-specific downloader instance.
  ///
  /// [downloadManager] is the manager that will receive progress updates.
  ///
  /// Returns:
  /// - [WebDownloader] on web platforms
  /// - [IODownloader] on mobile and desktop platforms
  static PlatformDownloader create(DownloadManager downloadManager) {
    return createPlatformDownloader(downloadManager);
  }
}
