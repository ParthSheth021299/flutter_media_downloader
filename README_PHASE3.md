# Flutter Media Downloader

A production-grade, cross-platform download manager for Flutter with pause/resume support, concurrent downloads, and clean architecture.

[![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS%20%7C%20Web%20%7C%20Windows%20%7C%20macOS%20%7C%20Linux-blue.svg)](https://flutter.dev)

## Features

✅ **Cross-Platform Support** - Android, iOS, Web, Windows, macOS, Linux  
✅ **Pause and Resume** - True pause/resume using HTTP Range requests  
✅ **Concurrent Downloads** - Multiple downloads with configurable limits  
✅ **Real-Time Progress** - Broadcast stream for progress updates  
✅ **Queue Management** - Automatic queue processing  
✅ **Memory Efficient** - Chunked streaming, no full file loading  
✅ **Clean Architecture** - Dependency inversion, testable code  
✅ **Null Safety** - Full null safety support  

## Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  flutter_media_downloader: ^3.0.0
```

## Quick Start

```dart
import 'package:flutter_media_downloader/flutter_media_downloader.dart';

// Create download manager
final manager = DownloadManagerFactory.create(
  maxConcurrentDownloads: 3,
);

// Listen to progress
manager.progressStream.listen((update) {
  print('${update.taskId}: ${update.status} - ${update.progress * 100}%');
});

// Start download
final taskId = await manager.enqueue(
  DownloadRequest(
    url: 'https://example.com/file.pdf',
    saveLocation: SaveLocation.downloads,
  ),
);

// Pause download
await manager.pause(taskId);

// Resume download
await manager.resume(taskId);

// Cancel download
await manager.cancel(taskId);

// Clean up
await manager.dispose();
```

## Core Concepts

### Download Manager

The central orchestrator for all download operations:

```dart
final manager = DownloadManagerFactory.create(
  maxConcurrentDownloads: 3, // Max concurrent downloads
);
```

### Download Request

Describes what to download:

```dart
final request = DownloadRequest(
  url: 'https://example.com/file.pdf',
  saveLocation: SaveLocation.downloads,
  fileName: 'my-file.pdf', // Optional
  headers: {'Authorization': 'Bearer token'}, // Optional
);
```

### Download Status

Track download lifecycle:

- `queued` - Waiting to start
- `downloading` - Actively downloading
- `paused` - Paused by user
- `resuming` - Resuming from pause
- `completed` - Successfully completed
- `failed` - Failed with error
- `canceled` - Canceled by user

### Progress Updates

Real-time updates via broadcast stream:

```dart
manager.progressStream.listen((update) {
  print('Task: ${update.taskId}');
  print('Status: ${update.status}');
  print('Progress: ${update.progress * 100}%');
  print('Received: ${update.receivedBytes}');
  print('Total: ${update.totalBytes}');
  
  if (update.status == DownloadStatus.completed) {
    print('File saved to: ${update.filePath}');
  }
  
  if (update.status == DownloadStatus.failed) {
    print('Error: ${update.errorMessage}');
  }
});
```

## Pause and Resume

### Basic Usage

```dart
// Pause an active download
final paused = await manager.pause(taskId);
if (paused) {
  print('Download paused');
}

// Resume a paused download
final resumed = await manager.resume(taskId);
if (resumed) {
  print('Download resuming');
}
```

### Check Resume Support

```dart
final task = manager.getTask(taskId);
if (task?.supportsResume == true) {
  // Server supports resume - show pause button
} else {
  // Server doesn't support resume - hide pause button
}
```

### How It Works

1. **Pause**: Stops network stream, keeps partial file, records byte position
2. **Resume**: Sends HTTP Range header, validates response, appends to file
3. **Validation**: Checks Content-Range, detects file changes, handles errors
4. **Fallback**: Restarts from beginning if server doesn't support Range

## Advanced Usage

### Multiple Downloads

```dart
final taskIds = <String>[];

for (final url in urls) {
  final taskId = await manager.enqueue(
    DownloadRequest(url: url, saveLocation: SaveLocation.downloads),
  );
  taskIds.add(taskId);
}

// Manager automatically handles queue and concurrency
```

### Custom Headers

```dart
await manager.enqueue(
  DownloadRequest(
    url: 'https://api.example.com/file',
    saveLocation: SaveLocation.downloads,
    headers: {
      'Authorization': 'Bearer your-token',
      'X-Custom-Header': 'value',
    },
  ),
);
```

### Save Locations

```dart
// Downloads folder
SaveLocation.downloads

// Documents folder
SaveLocation.documents

// Temporary folder
SaveLocation.temporary

// Custom path
SaveLocation.custom
// (requires customPath parameter)
```

### Error Handling

```dart
manager.progressStream.listen((update) {
  if (update.status == DownloadStatus.failed) {
    switch (update.errorMessage) {
      case String msg when msg.contains('Resume failed'):
        // Handle resume failure
        await manager.cancel(update.taskId);
        await manager.enqueue(originalRequest);
        break;
      case String msg when msg.contains('Network error'):
        // Handle network error
        showRetryDialog();
        break;
      default:
        // Handle other errors
        showErrorDialog(update.errorMessage);
    }
  }
});
```

### Get Task Information

```dart
final task = manager.getTask(taskId);
if (task != null) {
  print('Status: ${task.status}');
  print('Progress: ${task.progress}');
  print('Received: ${task.receivedBytes}');
  print('Total: ${task.totalBytes}');
  print('Supports Resume: ${task.supportsResume}');
}

// Get all tasks
final allTasks = manager.tasks;
print('Total tasks: ${allTasks.length}');
```

### Queue Information

```dart
print('Active downloads: ${manager.activeDownloadCount}');
print('Queued downloads: ${manager.queuedDownloadCount}');
```

## Platform Support

| Platform | Pause/Resume | Notes |
|----------|--------------|-------|
| Android | ✅ Full | RandomAccessFile, byte-level precision |
| iOS | ✅ Full | RandomAccessFile, byte-level precision |
| Windows | ✅ Full | RandomAccessFile, byte-level precision |
| macOS | ✅ Full | RandomAccessFile, byte-level precision |
| Linux | ✅ Full | RandomAccessFile, byte-level precision |
| Web | ⚠️ Limited | Browser constraints, clear error messages |

## Examples

### Basic Download

```dart
final manager = DownloadManagerFactory.create();

final taskId = await manager.enqueue(
  DownloadRequest(
    url: 'https://speed.hetzner.de/100MB.bin',
    saveLocation: SaveLocation.downloads,
  ),
);

manager.progressStream.listen((update) {
  if (update.taskId == taskId) {
    print('Progress: ${(update.progress * 100).toStringAsFixed(1)}%');
  }
});
```

### Pause/Resume Example

```dart
// Start download
final taskId = await manager.enqueue(request);

// Wait 5 seconds
await Future.delayed(Duration(seconds: 5));

// Pause
await manager.pause(taskId);
print('Paused');

// Wait 2 seconds
await Future.delayed(Duration(seconds: 2));

// Resume
await manager.resume(taskId);
print('Resumed');
```

### UI Integration

```dart
class DownloadButton extends StatefulWidget {
  final String taskId;
  final DownloadManager manager;
  
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DownloadTaskUpdate>(
      stream: manager.progressStream,
      builder: (context, snapshot) {
        final task = manager.getTask(taskId);
        if (task == null) return SizedBox();
        
        switch (task.status) {
          case DownloadStatus.downloading:
          case DownloadStatus.resuming:
            return IconButton(
              icon: Icon(Icons.pause),
              onPressed: () => manager.pause(taskId),
            );
          case DownloadStatus.paused:
            return IconButton(
              icon: Icon(Icons.play_arrow),
              onPressed: () => manager.resume(taskId),
            );
          default:
            return SizedBox();
        }
      },
    );
  }
}
```

See `example/lib/phase3_example.dart` for a complete working example.

## Architecture

The plugin follows clean architecture principles:

```
┌─────────────────────────────────────┐
│         DownloadManager             │  ← Core business logic
│  (Queue, Concurrency, State)        │
└─────────────────┬───────────────────┘
                  │
                  ↓
┌─────────────────────────────────────┐
│      PlatformDownloader             │  ← Abstract interface
│         (Interface)                 │
└─────────────────┬───────────────────┘
                  │
        ┌─────────┴─────────┐
        ↓                   ↓
┌───────────────┐   ┌───────────────┐
│ IODownloader  │   │ WebDownloader │  ← Platform implementations
│ (dart:io)     │   │ (dart:html)   │
└───────────────┘   └───────────────┘
```

## Performance

- **Memory**: O(chunk_size) - constant ~8KB
- **Disk I/O**: Sequential writes, append mode for resume
- **Network**: Single connection per download
- **CPU**: Minimal overhead for chunk processing

## Limitations

- No persistence across app restarts (by design)
- Web platform cannot truly append files (browser limitation)
- Single connection per download (no multi-part yet)
- No automatic retry (future enhancement)

## Testing

Test with servers that support HTTP Range requests:

```dart
// Good test URLs
'https://speed.hetzner.de/100MB.bin'
'https://speed.hetzner.de/1GB.bin'
'https://github.com/[user]/[repo]/releases/download/[tag]/[file]'
```

## Documentation

- **PHASE3_IMPLEMENTATION.md** - Detailed technical guide
- **PHASE3_QUICK_REFERENCE.md** - Quick reference
- **PHASE3_SUMMARY.md** - High-level overview
- **ARCHITECTURE.md** - Architecture documentation

## Migration

### From Phase 2

No breaking changes! All Phase 2 code works as-is:

```dart
// Phase 2 code (still works)
await manager.enqueue(request);
await manager.cancel(taskId);
```

Phase 3 adds new functionality:

```dart
// Phase 3 additions
await manager.pause(taskId);
await manager.resume(taskId);
```

## Contributing

Contributions are welcome! Please read the contributing guidelines first.

## License

This project is licensed under the MIT License - see the LICENSE file for details.

## Support

- 📧 Email: parthsheth100@gmail.com
- ☕ [Buy Me a Coffee](https://www.buymeacoffee.com/parthsheth)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
