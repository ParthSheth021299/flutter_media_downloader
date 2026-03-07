# Phase 3 Quick Reference Guide

## New API Methods

### Pause a Download
```dart
Future<bool> pause(String taskId)
```

**Returns**: `true` if paused successfully, `false` otherwise

**When to use**: When user wants to temporarily stop a download

**Requirements**:
- Task must be in `downloading` or `resuming` state
- Returns `false` for queued, paused, completed, failed, or canceled tasks

**Example**:
```dart
final success = await downloadManager.pause(taskId);
if (success) {
  print('Download paused');
} else {
  print('Cannot pause this download');
}
```

---

### Resume a Download
```dart
Future<bool> resume(String taskId)
```

**Returns**: `true` if resume initiated, `false` otherwise

**When to use**: When user wants to continue a paused download

**Requirements**:
- Task must be in `paused` state
- Returns `false` for non-paused tasks

**Behavior**:
- If capacity available → Starts immediately
- If at max concurrent → Queues for later
- Validates server supports resume
- Falls back to restart if server doesn't support Range

**Example**:
```dart
final success = await downloadManager.resume(taskId);
if (success) {
  print('Download resuming');
} else {
  print('Cannot resume this download');
}
```

---

## New Status Values

### DownloadStatus.paused
Download has been paused by user and can be resumed.

**Characteristics**:
- Partial file kept on disk
- `receivedBytes` preserved
- Not counted toward active downloads
- Can transition to `resuming` or `canceled`

---

### DownloadStatus.resuming
Download is transitioning from paused to active state.

**Characteristics**:
- HTTP Range request being sent
- Validating server response
- Will transition to `downloading` or `failed`
- Counted toward active downloads

---

## New Task Property

### supportsResume
```dart
final bool supportsResume;
```

**Purpose**: Indicates if server supports HTTP Range requests

**Set by**: Platform downloader after first response

**Based on**: `Accept-Ranges` HTTP header

**Usage**:
```dart
final task = downloadManager.getTask(taskId);
if (task?.supportsResume == true) {
  print('This download can be resumed');
} else {
  print('Server does not support resume');
}
```

---

## Status Transitions

### Valid Flows

```
downloading → paused → resuming → downloading → completed
                ↓                      ↓
              canceled              failed
```

### Transition Table

| From | To | Trigger |
|------|-----|---------|
| downloading | paused | `pause()` called |
| paused | resuming | `resume()` called |
| resuming | downloading | Resume successful |
| resuming | failed | Resume failed |
| downloading | canceled | `cancel()` called |
| paused | canceled | `cancel()` called |
| resuming | canceled | `cancel()` called |

---

## HTTP Range Requests

### Request Format
```http
GET /file.zip HTTP/1.1
Range: bytes=1048576-
```

### Response Codes

| Code | Meaning | Action |
|------|---------|--------|
| 206 | Partial Content | Resume successful, append data |
| 200 | OK | Server doesn't support range, restart |
| 416 | Range Not Satisfiable | Invalid range, fail with error |

### Response Headers
```http
HTTP/1.1 206 Partial Content
Accept-Ranges: bytes
Content-Range: bytes 1048576-10485760/10485760
```

---

## Error Scenarios

### Server Doesn't Support Resume
```dart
// Automatic behavior: Restart from beginning
// User sees: Download restarts at 0%
```

### File Size Changed
```dart
// Automatic behavior: Restart from beginning
// Reason: File on server was modified
```

### Partial File Missing
```dart
// Error: "Cannot resume: partial file does not exist"
// User action: Start new download
```

### Network Error During Resume
```dart
// Status: failed
// Error message: "Resume failed: <error details>"
// User action: Try resume again or restart
```

---

## Platform Differences

### Android/iOS/Desktop
✅ Full pause/resume support  
✅ Byte-level precision  
✅ RandomAccessFile for append  
✅ Keeps partial files  

### Web
⚠️ Limited support  
⚠️ Cannot truly append files  
⚠️ Browser handles downloads  
✅ Clear error messages  

---

## Code Examples

### Basic Pause/Resume
```dart
// Start download
final taskId = await manager.enqueue(request);

// Wait a bit
await Future.delayed(Duration(seconds: 5));

// Pause
await manager.pause(taskId);
print('Paused at ${task.receivedBytes} bytes');

// Wait a bit
await Future.delayed(Duration(seconds: 2));

// Resume
await manager.resume(taskId);
print('Resuming from ${task.receivedBytes} bytes');
```

### Listen to Status Changes
```dart
manager.progressStream.listen((update) {
  switch (update.status) {
    case DownloadStatus.downloading:
      print('Downloading: ${update.progress * 100}%');
      break;
    case DownloadStatus.paused:
      print('Paused at ${update.receivedBytes} bytes');
      break;
    case DownloadStatus.resuming:
      print('Resuming from ${update.receivedBytes} bytes');
      break;
    case DownloadStatus.completed:
      print('Completed: ${update.filePath}');
      break;
    case DownloadStatus.failed:
      print('Failed: ${update.errorMessage}');
      break;
  }
});
```

### Check Resume Support
```dart
manager.progressStream.listen((update) {
  if (update.status == DownloadStatus.downloading) {
    final task = manager.getTask(update.taskId);
    if (task?.supportsResume == true) {
      // Show pause button in UI
      showPauseButton();
    } else {
      // Hide pause button (server doesn't support resume)
      hidePauseButton();
    }
  }
});
```

### Handle Pause/Resume Errors
```dart
Future<void> pauseDownload(String taskId) async {
  final success = await manager.pause(taskId);
  if (!success) {
    final task = manager.getTask(taskId);
    if (task?.status == DownloadStatus.paused) {
      showMessage('Download is already paused');
    } else if (task?.status == DownloadStatus.completed) {
      showMessage('Download is already completed');
    } else {
      showMessage('Cannot pause this download');
    }
  }
}

Future<void> resumeDownload(String taskId) async {
  final success = await manager.resume(taskId);
  if (!success) {
    final task = manager.getTask(taskId);
    if (task?.status != DownloadStatus.paused) {
      showMessage('Download is not paused');
    } else {
      showMessage('Failed to resume download');
    }
  }
}
```

### Multiple Pause/Resume Cycles
```dart
// This is perfectly valid
await manager.pause(taskId);
await manager.resume(taskId);
await manager.pause(taskId);
await manager.resume(taskId);
// Each cycle preserves exact byte position
```

---

## Best Practices

### 1. Check Status Before Operations
```dart
final task = manager.getTask(taskId);
if (task?.status == DownloadStatus.downloading) {
  await manager.pause(taskId);
}
```

### 2. Handle Resume Failures
```dart
final success = await manager.resume(taskId);
if (!success) {
  // Offer to restart download
  await manager.cancel(taskId);
  await manager.enqueue(originalRequest);
}
```

### 3. Show Resume Capability in UI
```dart
if (task.supportsResume) {
  // Show pause/resume buttons
} else {
  // Only show cancel button
}
```

### 4. Respect Concurrency Limits
```dart
// Resume will queue if at capacity
// No need to check manually
await manager.resume(taskId);
```

### 5. Clean Up on Dispose
```dart
// Manager handles cleanup automatically
await manager.dispose();
// All paused downloads are cleaned up
```

---

## Testing Tips

### Test with Large Files
```dart
// Use files > 100MB to see pause/resume in action
'https://speed.hetzner.de/100MB.bin'
'https://speed.hetzner.de/1GB.bin'
```

### Test Server Support
```dart
// Most CDNs support Range requests
// Test with and without support
```

### Test Multiple Cycles
```dart
// Pause and resume multiple times
// Verify byte count accuracy
```

### Test Concurrency
```dart
// Start max downloads
// Pause one
// Resume (should queue)
// Verify starts when slot opens
```

---

## Common Issues

### Issue: Resume doesn't work
**Check**: Does server support Range requests?  
**Solution**: Check `task.supportsResume` flag

### Issue: Download restarts from beginning
**Reason**: Server doesn't support Range or file changed  
**Expected**: This is correct behavior

### Issue: Pause button doesn't work
**Check**: Is download in correct state?  
**Solution**: Only pause `downloading` or `resuming` tasks

### Issue: Resume fails immediately
**Check**: Does partial file exist?  
**Solution**: File may have been deleted, restart download

---

## Performance Notes

- **Memory**: O(chunk_size) - constant, ~8KB typical
- **Disk**: Sequential writes, append mode for resume
- **Network**: Single connection, no overhead
- **CPU**: Minimal, chunk processing only

---

## Limitations

1. No persistence across app restarts (by design)
2. Web platform cannot truly append (browser limitation)
3. Single connection per download (no multi-part yet)
4. No automatic retry (future enhancement)

---

## Migration from Phase 2

**Zero breaking changes!**

All Phase 2 code works as-is:
```dart
// Phase 2 code (still works)
await manager.enqueue(request);
await manager.cancel(taskId);
```

New Phase 3 features are additive:
```dart
// Phase 3 additions
await manager.pause(taskId);
await manager.resume(taskId);
```
