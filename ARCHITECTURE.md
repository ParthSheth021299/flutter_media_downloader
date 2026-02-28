# Flutter Media Downloader - Architecture

## System Architecture Diagram

```
┌─────────────────────────────────────────────────────────────────┐
│                         Application Layer                        │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │         DownloadManagerFactory.create()                   │  │
│  │         (Single entry point for users)                    │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                          Core Layer (Phase 1)                    │
│                                                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │                   DownloadManager                         │  │
│  │  • Queue management                                       │  │
│  │  • Concurrency control (maxConcurrentDownloads)          │  │
│  │  • Progress stream broadcasting                           │  │
│  │  • Task lifecycle management                              │  │
│  └──────────────────────────────────────────────────────────┘  │
│                              │                                   │
│                              │ depends on                        │
│                              ▼                                   │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │          PlatformDownloader (Interface)                   │  │
│  │  • startDownload(task)                                    │  │
│  │  • cancelDownload(taskId)                                 │  │
│  │  • dispose()                                              │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ implements
                              │
        ┌─────────────────────┼─────────────────────┐
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│ IODownloader │    │WebDownloader │    │    Stub      │
│  (Phase 2)   │    │  (Phase 2)   │    │  (Phase 2)   │
└──────────────┘    └──────────────┘    └──────────────┘
        │                     │                     │
        │                     │                     │
        ▼                     ▼                     ▼
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  dart:io     │    │  dart:html   │    │Unsupported   │
│              │    │              │    │   Error      │
│ HttpClient   │    │ HttpRequest  │    │              │
│              │    │              │    │              │
│ • Android    │    │ • Web        │    │              │
│ • iOS        │    │              │    │              │
│ • Windows    │    │              │    │              │
│ • macOS      │    │              │    │              │
│ • Linux      │    │              │    │              │
└──────────────┘    └──────────────┘    └──────────────┘
```

## Conditional Import Flow

```
User imports: flutter_media_downloader.dart
                        │
                        ▼
            PlatformDownloaderFactory.create()
                        │
                        ▼
        ┌───────────────┴───────────────┐
        │                               │
        ▼                               ▼
  dart.library.io?              dart.library.html?
        │                               │
        ▼                               ▼
   IODownloader                   WebDownloader
   (Mobile/Desktop)                   (Web)
```

## Data Flow

```
1. User enqueues download
   DownloadRequest → DownloadManager.enqueue()
                              │
                              ▼
2. Manager creates task
   DownloadTask (status: queued)
                              │
                              ▼
3. Manager processes queue
   Checks: activeCount < maxConcurrent?
                              │
                              ▼
4. Manager starts download
   PlatformDownloader.startDownload(task)
                              │
                              ▼
5. Platform downloads file
   • Opens HTTP connection
   • Streams chunks
   • Reports progress ──────────┐
                                │
                                ▼
6. Manager receives updates
   DownloadManager.updateTask()
                              │
                              ▼
7. Manager broadcasts updates
   progressStream.add(DownloadTaskUpdate)
                              │
                              ▼
8. User receives updates
   progressStream.listen((update) { ... })
```

## Class Relationships

```
┌─────────────────────────────────────────────────────────────┐
│                         Models                               │
│                                                               │
│  DownloadRequest  ──uses──▶  SaveLocation (enum)            │
│                                                               │
│  DownloadTask     ──uses──▶  DownloadStatus (enum)          │
│                                                               │
│  DownloadTaskUpdate ──uses──▶ DownloadStatus (enum)         │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ used by
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                      Core Components                         │
│                                                               │
│  DownloadManager                                             │
│    │                                                          │
│    ├─ has ──▶ PlatformDownloader (interface)                │
│    ├─ manages ──▶ Map<String, DownloadTask>                 │
│    ├─ manages ──▶ Queue<String> (queued task IDs)           │
│    ├─ manages ──▶ Set<String> (active task IDs)             │
│    └─ broadcasts ──▶ Stream<DownloadTaskUpdate>             │
│                                                               │
│  DownloadManagerFactory                                      │
│    └─ creates ──▶ DownloadManager                           │
│         └─ with ──▶ _LazyPlatformDownloader                 │
│              └─ wraps ──▶ PlatformDownloader                │
└─────────────────────────────────────────────────────────────┘
                              │
                              │ implemented by
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                  Platform Implementations                    │
│                                                               │
│  IODownloader                                                │
│    ├─ has ──▶ HttpClient                                    │
│    ├─ has ──▶ Map<String, _DownloadCancellation>           │
│    └─ calls ──▶ DownloadManager.updateTask()               │
│                                                               │
│  WebDownloader                                               │
│    ├─ has ──▶ Map<String, html.HttpRequest>                │
│    └─ calls ──▶ DownloadManager.updateTask()               │
└─────────────────────────────────────────────────────────────┘
```

## Concurrency Model

```
Queue: [Task1, Task2, Task3, Task4, Task5]
                    │
                    ▼
        maxConcurrentDownloads = 2
                    │
        ┌───────────┴───────────┐
        ▼                       ▼
    Task1 (active)          Task2 (active)
        │                       │
        │ completes             │
        ▼                       │
    Task3 starts                │
        (from queue)            │
                                │ completes
                                ▼
                            Task4 starts
                                (from queue)
```

## Error Handling Flow

```
Platform Implementation
        │
        ├─ Network Error ──────────┐
        ├─ HTTP Error ─────────────┤
        ├─ File System Error ──────┤
        └─ Cancellation ───────────┤
                                   │
                                   ▼
            DownloadManager.updateTask(
                status: DownloadStatus.failed,
                errorMessage: "..."
            )
                                   │
                                   ▼
            progressStream.add(
                DownloadTaskUpdate(
                    status: failed,
                    errorMessage: "..."
                )
            )
                                   │
                                   ▼
            User's error handler
```

## Lifecycle States

```
┌─────────┐
│ Created │ (DownloadRequest)
└────┬────┘
     │ enqueue()
     ▼
┌─────────┐
│ Queued  │ (waiting for capacity)
└────┬────┘
     │ processQueue()
     ▼
┌─────────────┐
│ Downloading │ (actively downloading)
└──────┬──────┘
       │
   ┌───┴────┬──────────┬──────────┐
   ▼        ▼          ▼          ▼
┌──────┐ ┌──────┐ ┌────────┐ ┌──────────┐
│Compl-│ │Failed│ │Canceled│ │ (error)  │
│eted  │ │      │ │        │ │          │
└──────┘ └──────┘ └────────┘ └──────────┘
(terminal states - no further transitions)
```

## Memory Management

### IODownloader (Streaming)
```
HTTP Response
     │
     ▼
┌─────────┐
│ Chunk 1 │ ──▶ Write to file ──▶ Release memory
├─────────┤
│ Chunk 2 │ ──▶ Write to file ──▶ Release memory
├─────────┤
│ Chunk 3 │ ──▶ Write to file ──▶ Release memory
└─────────┘

Memory usage: ~8KB (chunk size)
```

### WebDownloader (Blob)
```
HTTP Response
     │
     ▼
┌──────────────┐
│ Full Blob    │ ──▶ Trigger download ──▶ Release memory
│ (in memory)  │
└──────────────┘

Memory usage: Full file size
```

## Thread Safety

```
DownloadManager (Main Isolate)
        │
        ├─ Queue operations (synchronized)
        ├─ Task map updates (synchronized)
        └─ Stream broadcasts (synchronized)
                │
                ▼
Platform Implementations
        │
        ├─ IODownloader: async/await (single-threaded)
        └─ WebDownloader: event-driven (single-threaded)

Note: All operations are async but single-threaded.
No explicit locking needed due to Dart's event loop.
```

## Design Patterns Used

1. **Factory Pattern**: `DownloadManagerFactory`, `PlatformDownloaderFactory`
2. **Strategy Pattern**: `PlatformDownloader` interface with multiple implementations
3. **Observer Pattern**: `progressStream` for broadcasting updates
4. **Dependency Injection**: `DownloadManager` depends on `PlatformDownloader` interface
5. **Lazy Initialization**: `_LazyPlatformDownloader` wrapper
6. **Queue Pattern**: Task queue with concurrency control

## Key Architectural Principles

1. **Dependency Inversion**: Core depends on abstractions, not implementations
2. **Single Responsibility**: Each class has one clear purpose
3. **Open/Closed**: Open for extension (new platforms), closed for modification
4. **Interface Segregation**: Clean, minimal interfaces
5. **Separation of Concerns**: Core logic separate from platform logic
6. **Testability**: Easy to mock and test each component
