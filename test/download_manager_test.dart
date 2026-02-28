import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_media_downloader/flutter_media_downloader.dart';

void main() {
  group('DownloadManagerFactory', () {
    test('creates a download manager instance', () {
      final manager = DownloadManagerFactory.create(
        maxConcurrentDownloads: 2,
      );

      expect(manager, isNotNull);
      expect(manager.maxConcurrentDownloads, equals(2));
      expect(manager.activeDownloadCount, equals(0));
      expect(manager.queuedDownloadCount, equals(0));

      manager.dispose();
    });

    test('creates manager with default concurrency', () {
      final manager = DownloadManagerFactory.create();

      expect(manager.maxConcurrentDownloads, equals(3));

      manager.dispose();
    });
  });

  group('DownloadRequest', () {
    test('creates a valid download request', () {
      final request = DownloadRequest(
        url: 'https://example.com/file.pdf',
        saveLocation: SaveLocation.downloads,
      );

      expect(request.url, equals('https://example.com/file.pdf'));
      expect(request.saveLocation, equals(SaveLocation.downloads));
      expect(request.headers, isNull);
      expect(request.fileName, isNull);
    });

    test('creates request with custom path', () {
      final request = DownloadRequest(
        url: 'https://example.com/file.pdf',
        saveLocation: SaveLocation.custom,
        customPath: '/custom/path',
      );

      expect(request.customPath, equals('/custom/path'));
    });
  });

  group('DownloadStatus', () {
    test('has all expected statuses', () {
      expect(DownloadStatus.values, contains(DownloadStatus.queued));
      expect(DownloadStatus.values, contains(DownloadStatus.downloading));
      expect(DownloadStatus.values, contains(DownloadStatus.completed));
      expect(DownloadStatus.values, contains(DownloadStatus.failed));
      expect(DownloadStatus.values, contains(DownloadStatus.canceled));
    });
  });
}
