# Phase 2 Implementation: Cross-Platform Foreground Download Support

## Overview

Phase 2 adds platform-specific download implementations to the Phase 1 core architecture. This enables actual file downloading across all Flutter platforms (Android, iOS, Web, Windows, macOS, Linux) while maintaining the clean architecture principles established in Phase 1.

## What Was Implemented

### 1. Platform-Specific Downloaders

#### IODownloader (`lib/src/platform/io_downloader.dart`)
- **Platforms**: Android, iOS, Windows, macOS, Linux
- **Technology**: `dart:io` HttpClient
- **Features**:
  - Chunked streaming for memory efficiency
  - Real-time progress reporting
  - Proper error handling
  - Cancellation support
  - Automatic filename extraction from URL or Content-Disposition header
  - Platform-specific directory selection (mobile vs desktop)

#### WebDownloader (`lib/src/platform/web_downloader.dart`)
- **Platform**: Web
- **Technology**: `dart:html` HttpRequest
- **Features**:
  - Progress events tracking
  - Blob-based file handling
  - Automatic browser download trigger using AnchorElement
  - Cancellation support via request.abort()
  - Filename extraction from headers or URL

### 2. Conditional Import System

#### Platform Selection (`lib/src/platform/platform_downloader_factory.dart`)
- Uses Dart's conditional imports to select the correct implementation:
  - `dart.library.html` → WebDownloader
  - `dart.library.io` → IODownloader
- Provides a clean factory API for creating platform-specific downloaders

#### Stub Implementation (`lib/src/platform/platform_downloader_stub.dart`)
- Fallback that throws UnsupportedError
- Should never be reached in practice

### 3. Factory Pattern

#### DownloadManagerFactory (`lib/src/core/download_manager_factory.dart`)
- Simplifies creation of fully configured DownloadManager instances
- Handles circular dependency between DownloadManager and PlatformDownloader
- Uses lazy initialization pattern to defer platform downloader creation

### 4. Main Library Export (`lib/flutter_media_downloader.dart`)
- Single import point for all public APIs
- Exports core, models, and platform interfaces
- Comprehensive documentation with usage examples

## Architecture Decisions

### 1. Circular Dependency Resolution
**Problem**: DownloadManager needs PlatformDownloader in constructor, but PlatformDownloader needs DownloadManager to report updates.

**Solution**: Lazy initialization wrapper (`_LazyPlatformDownloader`) that defers actual platform downloader creation until first use.

### 2. Progress Reporting
All platform implementations call `downloadManager.updateTask()` to report:
- Progress updates (receivedBytes, totalBytes)
- Status changes (downloading, completed, failed, canceled)
- File paths on completion
- Error messages on failure

### 3. Chunked Streaming
Both IO and Web implementations use streaming to handle large files efficiently:
- **IO**: `await for (final chunk in response)` with incremental file writing
- **Web**: Progress events with final Blob conversion

### 4. Cancellation
- **IO**: Custom `_DownloadCancellation` token checked between chunks
- **Web**: `HttpRequest.abort()` method
- Both clean up partial files on cancellation

### 5. Filename Extraction
Priority order for determining filename:
1. Content-Disposition header (RFC 6266)
2. URL path basename
3. Generated timestamp-based name

## File Structure

```
lib/
├── flutter_media_downloader.dart          # Main library export
├── src/
│   ├── core/
│   │   ├── download_manager.dart          # Phase 1 (unchanged)
│   │   └── download_manager_factory.dart  # Phase 2 (new)
│   ├── models/                            # Phase 1 (unchanged)
│   │   ├── download_request.dart
│   │   ├── download_status.dart
│   │   ├── download_task.dart
│   │   ├── download_task_update.dart
│   │   └── save_location.dart
│   └── platform/
│       ├── platform_downloader.dart       # Phase 1 (unchanged)
│       ├── io_downloader.dart             # Phase 2 (new)
│       ├── web_downloader.dart            # Phase 2 (new)
│       ├── platform_downloader_factory.dart  # Phase 2 (new)
│       └── platform_downloader_stub.dart  # Phase 2 (new)
```

## Usage Example

```dart
import 'package:flutter_media_downloader/flutter_media_downloader.dart';

// Create a download manager (automatically selects platform implementation)
final manager = DownloadManagerFactory.create(
  maxConcurrentDownloads: 3,
);

// Listen to progress updates
manager.progressStream.listen((update) {
  print('Task ${update.taskId}: ${(update.progress * 100).toStringAsFixed(1)}%');
  
  if (update.status == DownloadStatus.completed) {
    print('Downloaded to: ${update.filePath}');
  } else if (update.status == DownloadStatus.failed) {
    print('Error: ${update.errorMessage}');
  }
});

// Enqueue downloads
final taskId1 = await manager.enqueue(
  DownloadRequest(
    url: 'https://example.com/file1.pdf',
    saveLocation: SaveLocation.downloads,
  ),
);

final taskId2 = await manager.enqueue(
  DownloadRequest(
    url: 'https://example.com/file2.pdf',
    saveLocation: SaveLocation.downloads,
    headers: {'Authorization': 'Bearer token'},
  ),
);

// Cancel a download
await manager.cancel(taskId1);

// Get task status
final task = manager.getTask(taskId2);
print('Progress: ${task?.progress}');

// Dispose when done
await manager.dispose();
```

## Testing

Basic unit tests are provided in `test/download_manager_test.dart`:
- Factory creation
- Download request validation
- Status enum verification

## Dependencies Added

- `path: ^1.9.0` - For path manipulation in IODownloader

## Known Limitations (By Design)

1. **No Pause/Resume**: Not implemented in Phase 2
2. **No Background Downloading**: Foreground only
3. **No Persistence**: Tasks lost on app restart
4. **Simplified SaveLocation**: Currently uses default directories
5. **No Custom Headers in Web**: Some browsers restrict header modification
6. **dart:html Deprecation**: Web implementation uses deprecated dart:html (migration to package:web is a future enhancement)

## Concurrency Behavior

The Phase 1 queue management works seamlessly with Phase 2 implementations:
- Maximum `maxConcurrentDownloads` tasks run simultaneously
- Additional tasks wait in queue
- When a task completes/fails/cancels, the next queued task starts automatically
- Platform implementations are unaware of queue management

## Error Handling

All platform implementations handle:
- Network errors (connection failures, timeouts)
- HTTP errors (4xx, 5xx status codes)
- File system errors (permission denied, disk full)
- Cancellation during download
- Invalid URLs

Errors are reported via `DownloadTaskUpdate` with:
- `status: DownloadStatus.failed`
- `errorMessage: <description>`

## Performance Characteristics

### Memory Usage
- **IO**: Streams chunks (default 8KB), minimal memory footprint
- **Web**: Entire file in memory as Blob (browser limitation)

### Progress Reporting
- **IO**: Updates on every chunk (frequent, real-time)
- **Web**: Updates on progress events (browser-controlled frequency)

### File Size Limits
- **IO**: No practical limit (streaming)
- **Web**: Limited by browser memory

## Next Steps (Future Phases)

Phase 2 provides the foundation for:
- **Phase 3**: Pause/Resume support
- **Phase 4**: Background downloading
- **Phase 5**: Persistence layer
- **Phase 6**: Advanced features (retry, bandwidth throttling, etc.)

## Compliance

- ✅ No modifications to Phase 1 architecture
- ✅ No pause/resume implementation
- ✅ No background downloading
- ✅ No persistence
- ✅ No UI code
- ✅ No example app modifications
- ✅ Platform logic only
- ✅ Connected to DownloadManager
- ✅ Production-grade code
- ✅ Null safety
- ✅ Documentation comments
- ✅ Clean and scalable
