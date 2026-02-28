import '../core/download_manager.dart';
import 'platform_downloader.dart';

/// Stub implementation that throws an error.
///
/// This file should never be imported directly. It serves as a fallback
/// for the conditional import system and will throw an error if somehow
/// reached at runtime.
PlatformDownloader createPlatformDownloader(DownloadManager downloadManager) {
  throw UnsupportedError(
    'Platform downloader is not supported on this platform. '
    'Supported platforms: Web (dart:html), Mobile/Desktop (dart:io)',
  );
}
