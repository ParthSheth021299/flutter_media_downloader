# Migration Guide: Phase 2 → Phase 3

## Overview

Phase 3 adds pause and resume functionality with **zero breaking changes**. All existing Phase 2 code continues to work without modification.

## What's New in Phase 3

### New API Methods
- `DownloadManager.pause(taskId)` - Pause an active download
- `DownloadManager.resume(taskId)` - Resume a paused download

### New Status Values
- `DownloadStatus.paused` - Download is paused
- `DownloadStatus.resuming` - Download is resuming

### New Task Property
- `DownloadTask.supportsResume` - Indicates server support for resume

## Migration Steps

### Step 1: Update Dependency

Update your `pubspec.yaml`:

```yaml
dependencies:
  flutter_media_downloader: ^3.0.0  # Phase 3
```

Run:
```bash
flutter pub get
```

### Step 2: No Code Changes Required!

Your existing Phase 2 code works as-is:

```dart
// This Phase 2 code still works perfectly
final manager = DownloadManagerFactory.create();

final taskId = await manager.enqueue(
  DownloadRequest(
    url: 'https://example.com/file.pdf',
    saveLocation: SaveLocation.downloads,
  ),
);

await manager.cancel(taskId);
```

### Step 3: Handle New Statuses (Optional)

If you have switch statements on `DownloadStatus`, add the new cases:

**Before (Phase 2):**
```dart
switch (update.status) {
  case DownloadStatus.queued:
    // Handle queued
    break;
  case DownloadStatus.downloading:
    // Handle downloading
    break;
  case DownloadStatus.completed:
    // Handle completed
    break;
  case DownloadStatus.failed:
    // Handle failed
    break;
  case DownloadStatus.canceled:
    // Handle canceled
    break;
}
```

**After (Phase 3):**
```dart
switch (update.status) {
  case DownloadStatus.queued:
    // Handle queued
    break;
  case DownloadStatus.downloading:
    // Handle downloading
    break;
  case DownloadStatus.paused:           // NEW
    // Handle paused
    break;
  case DownloadStatus.resuming:         // NEW
    // Handle resuming
    break;
  case DownloadStatus.completed:
    // Handle completed
    break;
  case DownloadStatus.failed:
    // Handle failed
    break;
  case DownloadStatus.canceled:
    // Handle canceled
    break;
}
```

### Step 4: Add Pause/Resume UI (Optional)

Add pause and resume buttons to your UI:

```dart
Widget buildDownloadControls(String taskId, DownloadStatus status) {
  switch (status) {
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
}
```

## Common Migration Scenarios

### Scenario 1: Basic Download App

**Phase 2 Code:**
```dart
class DownloadApp extends StatefulWidget {
  @override
  State<DownloadApp> createState() => _DownloadAppState();
}

class _DownloadAppState extends State<DownloadApp> {
  late DownloadManager manager;
  
  @override
  void initState() {
    super.initState();
    manager = DownloadManagerFactory.create();
    
    manager.progressStream.listen((update) {
      setState(() {
        // Update UI
      });
    });
  }
  
  Future<void> startDownload(String url) async {
    await manager.enqueue(
      DownloadRequest(url: url, saveLocation: SaveLocation.downloads),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    // Build UI
  }
}
```

**Phase 3 Enhancement (Optional):**
```dart
class _DownloadAppState extends State<DownloadApp> {
  late DownloadManager manager;
  
  @override
  void initState() {
    super.initState();
    manager = DownloadManagerFactory.create();
    
    manager.progressStream.listen((update) {
      setState(() {
        // Update UI
      });
    });
  }
  
  Future<void> startDownload(String url) async {
    await manager.enqueue(
      DownloadRequest(url: url, saveLocation: SaveLocation.downloads),
    );
  }
  
  // NEW: Add pause functionality
  Future<void> pauseDownload(String taskId) async {
    await manager.pause(taskId);
  }
  
  // NEW: Add resume functionality
  Future<void> resumeDownload(String taskId) async {
    await manager.resume(taskId);
  }
  
  @override
  Widget build(BuildContext context) {
    // Build UI with pause/resume buttons
  }
}
```

### Scenario 2: Progress Listener

**Phase 2 Code:**
```dart
manager.progressStream.listen((update) {
  print('Status: ${update.status}');
  print('Progress: ${update.progress * 100}%');
});
```

**Phase 3 Enhancement (Optional):**
```dart
manager.progressStream.listen((update) {
  print('Status: ${update.status}');
  print('Progress: ${update.progress * 100}%');
  
  // NEW: Check if resume is supported
  if (update.status == DownloadStatus.downloading) {
    final task = manager.getTask(update.taskId);
    if (task?.supportsResume == true) {
      print('Resume is supported for this download');
    }
  }
  
  // NEW: Handle pause status
  if (update.status == DownloadStatus.paused) {
    print('Download paused at ${update.receivedBytes} bytes');
  }
});
```

### Scenario 3: Error Handling

**Phase 2 Code:**
```dart
manager.progressStream.listen((update) {
  if (update.status == DownloadStatus.failed) {
    showError(update.errorMessage);
  }
});
```

**Phase 3 Enhancement (Optional):**
```dart
manager.progressStream.listen((update) {
  if (update.status == DownloadStatus.failed) {
    // NEW: Check if it's a resume failure
    if (update.errorMessage?.contains('Resume failed') == true) {
      // Offer to restart download
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Resume Failed'),
          content: Text('Would you like to restart the download?'),
          actions: [
            TextButton(
              onPressed: () async {
                await manager.cancel(update.taskId);
                await manager.enqueue(originalRequest);
              },
              child: Text('Restart'),
            ),
          ],
        ),
      );
    } else {
      showError(update.errorMessage);
    }
  }
});
```

## API Compatibility Matrix

| API | Phase 2 | Phase 3 | Notes |
|-----|---------|---------|-------|
| `enqueue()` | ✅ | ✅ | No changes |
| `cancel()` | ✅ | ✅ | Now handles paused/resuming |
| `getTask()` | ✅ | ✅ | Returns task with supportsResume |
| `progressStream` | ✅ | ✅ | Emits new statuses |
| `dispose()` | ✅ | ✅ | No changes |
| `pause()` | ❌ | ✅ | NEW |
| `resume()` | ❌ | ✅ | NEW |

## Model Changes

### DownloadTask

**Phase 2:**
```dart
class DownloadTask {
  final String id;
  final String url;
  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String? filePath;
  final String? errorMessage;
}
```

**Phase 3:**
```dart
class DownloadTask {
  final String id;
  final String url;
  final DownloadStatus status;
  final int receivedBytes;
  final int totalBytes;
  final String? filePath;
  final String? errorMessage;
  final bool supportsResume;  // NEW - defaults to false
}
```

### DownloadStatus

**Phase 2:**
```dart
enum DownloadStatus {
  queued,
  downloading,
  completed,
  failed,
  canceled,
}
```

**Phase 3:**
```dart
enum DownloadStatus {
  queued,
  downloading,
  paused,      // NEW
  resuming,    // NEW
  completed,
  failed,
  canceled,
}
```

## Testing Your Migration

### 1. Verify Existing Functionality

Run your existing tests:
```bash
flutter test
```

All Phase 2 tests should pass without modification.

### 2. Test New Functionality

Add tests for pause/resume:
```dart
test('pause and resume download', () async {
  final manager = DownloadManagerFactory.create();
  
  final taskId = await manager.enqueue(
    DownloadRequest(
      url: 'https://example.com/file.pdf',
      saveLocation: SaveLocation.downloads,
    ),
  );
  
  // Wait for download to start
  await Future.delayed(Duration(seconds: 1));
  
  // Pause
  final paused = await manager.pause(taskId);
  expect(paused, true);
  
  // Resume
  final resumed = await manager.resume(taskId);
  expect(resumed, true);
});
```

### 3. Manual Testing

Test with real downloads:
```dart
// Use a large file to see pause/resume in action
final taskId = await manager.enqueue(
  DownloadRequest(
    url: 'https://speed.hetzner.de/100MB.bin',
    saveLocation: SaveLocation.downloads,
  ),
);

// Pause after 5 seconds
await Future.delayed(Duration(seconds: 5));
await manager.pause(taskId);

// Resume after 2 seconds
await Future.delayed(Duration(seconds: 2));
await manager.resume(taskId);
```

## Troubleshooting

### Issue: Switch statement not exhaustive

**Error:**
```
The type 'DownloadStatus' is not exhaustively matched by the switch cases
```

**Solution:**
Add cases for `paused` and `resuming`:
```dart
case DownloadStatus.paused:
  // Handle paused
  break;
case DownloadStatus.resuming:
  // Handle resuming
  break;
```

### Issue: Resume doesn't work

**Check:**
1. Is the server supporting Range requests?
2. Check `task.supportsResume` flag

**Solution:**
```dart
final task = manager.getTask(taskId);
if (task?.supportsResume == true) {
  // Resume is supported
  await manager.resume(taskId);
} else {
  // Resume not supported, restart download
  await manager.cancel(taskId);
  await manager.enqueue(originalRequest);
}
```

### Issue: Pause button doesn't work

**Check:**
Is the download in the correct state?

**Solution:**
```dart
Future<void> pauseDownload(String taskId) async {
  final task = manager.getTask(taskId);
  if (task?.status == DownloadStatus.downloading ||
      task?.status == DownloadStatus.resuming) {
    await manager.pause(taskId);
  } else {
    print('Cannot pause: download is ${task?.status}');
  }
}
```

## Best Practices

### 1. Check Status Before Operations

```dart
// Good
final task = manager.getTask(taskId);
if (task?.status == DownloadStatus.downloading) {
  await manager.pause(taskId);
}

// Bad
await manager.pause(taskId); // May fail if not downloading
```

### 2. Handle Resume Failures

```dart
final success = await manager.resume(taskId);
if (!success) {
  // Offer alternative actions
  showDialog(...);
}
```

### 3. Show Resume Capability

```dart
if (task.supportsResume) {
  // Show pause/resume buttons
} else {
  // Only show cancel button
}
```

## Summary

✅ **Zero breaking changes** - All Phase 2 code works  
✅ **Optional enhancements** - Add pause/resume when ready  
✅ **Backward compatible** - Gradual migration possible  
✅ **Well tested** - All existing tests pass  

You can migrate at your own pace:
1. Update dependency
2. Test existing functionality
3. Add new features when ready

## Need Help?

- Check `PHASE3_QUICK_REFERENCE.md` for API details
- See `example/lib/phase3_example.dart` for complete example
- Read `PHASE3_IMPLEMENTATION.md` for technical details

Happy coding! 🚀
