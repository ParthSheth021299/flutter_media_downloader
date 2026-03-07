# Phase 3 Implementation: Pause and Resume Support

## Overview

Phase 3 adds true pause and resume functionality using HTTP Range requests. Downloads can be paused at any point and resumed from the exact byte position, without re-downloading already received data.

## Features Implemented

### 1. New Download Statuses

Added two new statuses to `DownloadStatus` enum:

- **`paused`**: Download has been paused and can be resumed
- **`resuming`**: Download is transitioning from paused to downloading state

Status flow:
```
queued → downloading → paused → resuming → downloading → completed
                    ↓
                  failed/canceled
```

### 2. Enhanced DownloadTask Model

Added `supportsResume` field to track server capability:

```dart
final bool supportsResume;
```

This field is set based on the `Accept-Ranges` HTTP header from the server.

### 3. DownloadManager API Extensions

#### pause(taskId)

Pauses an active download:

```dart
Future<bool> pause(String taskId) async
```

- Only works on `downloading` or `resuming` tasks
- Stops network stream safely
- Keeps partially downloaded file
- Records `receivedBytes` for resume
- Returns `true` if successful, `false` otherwise

#### resume(taskId)

Resumes a paused download:

```dart
Future<bool> resume(String taskId) async
```

- Only works on `paused` tasks
- Respects concurrency limits (queues if necessary)
- Validates server support for Range requests
- Returns `true` if successful, `false` otherwise

### 4. PlatformDownloader Interface Updates

Extended the interface with two new methods:

```dart
Future<void> pauseDownload(String taskId);
Future<void> resumeDownload(DownloadTask task);
```

### 5. IO Platform Implementation (Android, iOS, Desktop)

#### Pause Behavior

- Sets pause flag in cancellation token
- Breaks out of download loop gracefully
- Closes file handle (RandomAccessFile)
- Keeps partial file on disk
- Preserves `receivedBytes` count

#### Resume Behavior

1. **Validation**:
   - Checks if partial file exists
   - Validates `supportsResume` flag
   - Verifies file path is set

2. **HTTP Range Request**:
   ```
   Range: bytes=<receivedBytes>-
   ```

3. **Response Handling**:
   - **206 Partial Content**: Resume successful, append to file
   - **200 OK**: Server doesn't support range, restart from beginning
   - **416 Range Not Satisfiable**: File complete or invalid range

4. **Content-Range Validation**:
   - Parses `Content-Range` header
   - Validates start byte matches `receivedBytes`
   - Checks if total file size changed
   - Restarts download if file size mismatch

5. **File Handling**:
   - Opens file in `FileMode.append` mode
   - Uses `RandomAccessFile` for precise byte control
   - Appends chunks without loading full file into memory
   - Flushes and closes properly

#### Error Handling

- Server doesn't support resume → Restart from beginning
- File size changed → Restart from beginning
- Partial file missing → Throw error
- Network error during resume → Report failure

### 6. Web Platform Implementation

#### Limitations

Web platform has inherent limitations for pause/resume:

- Cannot truly pause an ongoing `XMLHttpRequest`
- Cannot append to previously downloaded blobs
- Browser handles file downloads independently

#### Implementation Strategy

1. **Pause**: Aborts the request, keeps metadata
2. **Resume**: 
   - Checks `supportsResume` flag
   - Sends Range request if supported
   - Downloads remaining portion
   - Browser triggers separate download

#### Error Handling

- Server doesn't support Range → Fail with clear error message
- Range not satisfiable → Fail with error
- Network error → Report failure

### 7. Status Transitions

Valid transitions:

```
downloading → paused       (user pauses)
paused → resuming          (user resumes)
resuming → downloading     (resume successful)
resuming → failed          (resume failed)
downloading → canceled     (user cancels)
paused → canceled          (user cancels paused task)
```

Invalid transitions are prevented by the API.

## Usage Example

```dart
// Initialize manager
final manager = DownloadManagerFactory.create(
  maxConcurrentDownloads: 3,
);

// Start download
final taskId = await manager.enqueue(
  DownloadRequest(
    url: 'https://example.com/large-file.zip',
    saveLocation: SaveLocation.downloads,
  ),
);

// Listen to progress
manager.progressStream.listen((update) {
  print('${update.taskId}: ${update.status} - ${update.progress * 100}%');
  
  if (update.status == DownloadStatus.downloading) {
    // Check if server supports resume
    final task = manager.getTask(update.taskId);
    if (task?.supportsResume == true) {
      print('Resume is supported for this download');
    }
  }
});

// Pause download
await manager.pause(taskId);

// Resume download
await manager.resume(taskId);

// Cancel download
await manager.cancel(taskId);
```

## Technical Details

### HTTP Range Requests

#### Request Header
```
Range: bytes=<start>-<end>
Range: bytes=<start>-        (open-ended, to end of file)
```

#### Response Status Codes

- **206 Partial Content**: Server supports range and is sending partial content
- **200 OK**: Server doesn't support range, sending full content
- **416 Range Not Satisfiable**: Requested range is invalid

#### Response Headers

```
Accept-Ranges: bytes         (server supports range requests)
Accept-Ranges: none          (server doesn't support range)
Content-Range: bytes <start>-<end>/<total>
```

### File Handling

#### RandomAccessFile vs IOSink

- **IOSink** (Phase 2): Sequential write-only, good for streaming
- **RandomAccessFile** (Phase 3): Random access, supports append mode

Phase 3 uses `RandomAccessFile` for:
- Precise byte position control
- Append mode for resume
- Flush control
- Better error handling

#### Memory Efficiency

- Chunks are written immediately, not buffered
- No full file loading into memory
- Streaming continues from last byte position
- File handle closed properly on pause/cancel

### Concurrency Handling

Paused tasks respect concurrency limits:

1. User calls `resume(taskId)`
2. If capacity available → Start immediately
3. If at max capacity → Add to queue
4. When slot opens → Process from queue

### Error Recovery

#### Scenario: Server Doesn't Support Resume

```dart
if (!task.supportsResume || response.statusCode == 200) {
  // Delete partial file
  await file.delete();
  // Restart from beginning
  await startDownload(task.copyWith(receivedBytes: 0));
}
```

#### Scenario: File Size Changed

```dart
if (task.totalBytes > 0 && totalBytes != task.totalBytes) {
  // File changed on server, restart
  await file.delete();
  await startDownload(task.copyWith(receivedBytes: 0));
}
```

#### Scenario: Partial File Missing

```dart
if (!await file.exists()) {
  throw Exception('Cannot resume: partial file does not exist');
}
```

## Testing Recommendations

### Test Servers

Use servers that support Range requests:

- **Hetzner Speed Test**: `https://speed.hetzner.de/100MB.bin`
- **GitHub Releases**: Most release assets support Range
- **CDNs**: Cloudflare, CloudFront typically support Range

### Test Scenarios

1. **Basic Pause/Resume**:
   - Start download
   - Pause at 50%
   - Resume
   - Verify completion

2. **Multiple Pause/Resume Cycles**:
   - Pause and resume multiple times
   - Verify byte count accuracy

3. **Server Without Range Support**:
   - Test with server that doesn't support Range
   - Verify graceful fallback (restart)

4. **Network Interruption**:
   - Simulate network failure during download
   - Resume after network restored

5. **Concurrency Limits**:
   - Start max concurrent downloads
   - Pause one
   - Resume (should queue)
   - Verify starts when slot available

6. **File Size Change**:
   - Mock server that changes file size
   - Verify restart behavior

## Platform-Specific Notes

### Android/iOS

- Full pause/resume support
- Uses `RandomAccessFile` for precise control
- Partial files stored in app documents directory
- No background download (as per requirements)

### Desktop (Windows/macOS/Linux)

- Full pause/resume support
- Uses `RandomAccessFile` for precise control
- Partial files stored in downloads directory
- Same implementation as mobile

### Web

- Limited pause/resume support
- Cannot truly append to previous download
- Relies on browser download manager
- Clear error messages when not supported

## Constraints Maintained

✅ No background downloading  
✅ No persistent storage across app restarts  
✅ Public API compatibility maintained  
✅ Clean architecture preserved  
✅ No UI code  
✅ Memory efficient (no full file loading)  
✅ Proper error handling  
✅ Null safety throughout  

## Future Enhancements (Not in Phase 3)

- Persistent storage for resume across app restarts
- Background download support
- Multi-part/chunked parallel downloads
- Automatic retry on network failure
- Download speed limiting
- ETag validation for resume safety

## API Summary

### New Methods

```dart
// DownloadManager
Future<bool> pause(String taskId);
Future<bool> resume(String taskId);

// PlatformDownloader
Future<void> pauseDownload(String taskId);
Future<void> resumeDownload(DownloadTask task);
```

### New Status Values

```dart
enum DownloadStatus {
  // ... existing values
  paused,
  resuming,
}
```

### Enhanced Model

```dart
class DownloadTask {
  // ... existing fields
  final bool supportsResume;
}
```

## Migration from Phase 2

No breaking changes. Existing code continues to work:

```dart
// Phase 2 code (still works)
final taskId = await manager.enqueue(request);
await manager.cancel(taskId);

// Phase 3 additions (new functionality)
await manager.pause(taskId);
await manager.resume(taskId);
```

## Conclusion

Phase 3 successfully implements production-grade pause and resume functionality using HTTP Range requests. The implementation is memory-efficient, handles edge cases gracefully, and maintains clean architecture principles. All platform implementations respect their constraints while providing the best possible user experience.
