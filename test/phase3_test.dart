import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_media_downloader/flutter_media_downloader.dart';

void main() {
  group('Phase 3: Pause and Resume', () {
    test('DownloadStatus includes paused and resuming', () {
      expect(DownloadStatus.values.contains(DownloadStatus.paused), true);
      expect(DownloadStatus.values.contains(DownloadStatus.resuming), true);
    });

    test('DownloadTask includes supportsResume field', () {
      final task = DownloadTask(
        id: 'test',
        url: 'https://example.com/file.pdf',
        status: DownloadStatus.downloading,
        supportsResume: true,
      );

      expect(task.supportsResume, true);
    });

    test('DownloadTask copyWith preserves supportsResume', () {
      final task = DownloadTask(
        id: 'test',
        url: 'https://example.com/file.pdf',
        status: DownloadStatus.downloading,
        supportsResume: true,
      );

      final copied = task.copyWith(status: DownloadStatus.paused);

      expect(copied.supportsResume, true);
      expect(copied.status, DownloadStatus.paused);
    });

    test('DownloadTask copyWith can update supportsResume', () {
      final task = DownloadTask(
        id: 'test',
        url: 'https://example.com/file.pdf',
        status: DownloadStatus.downloading,
        supportsResume: false,
      );

      final copied = task.copyWith(supportsResume: true);

      expect(copied.supportsResume, true);
    });

    test('DownloadStatus enum has correct values', () {
      expect(DownloadStatus.values.length, 7);
      expect(DownloadStatus.values, [
        DownloadStatus.queued,
        DownloadStatus.downloading,
        DownloadStatus.paused,
        DownloadStatus.resuming,
        DownloadStatus.completed,
        DownloadStatus.failed,
        DownloadStatus.canceled,
      ]);
    });

    test('DownloadTask defaults supportsResume to false', () {
      final task = DownloadTask(
        id: 'test',
        url: 'https://example.com/file.pdf',
        status: DownloadStatus.downloading,
      );

      expect(task.supportsResume, false);
    });
  });

  group('Phase 3: Status Transitions', () {
    test('Status names are correct', () {
      expect(DownloadStatus.paused.name, 'paused');
      expect(DownloadStatus.resuming.name, 'resuming');
    });

    test('All statuses are unique', () {
      final statuses = DownloadStatus.values.toSet();
      expect(statuses.length, DownloadStatus.values.length);
    });
  });
}
