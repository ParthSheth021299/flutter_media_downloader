/// Core download manager library.
///
/// This library provides the clean architecture foundation for a
/// production-grade download manager. It includes:
///
/// - Models for download tasks, requests, and updates
/// - Abstract platform interface for dependency injection
/// - Core download manager with queue and concurrency management
///
/// This is Phase 1 - core engine only. No UI, no platform implementations,
/// no background downloading, no pause/resume, no persistence.

// Models
export 'models/download_request.dart';
export 'models/download_status.dart';
export 'models/download_task.dart';
export 'models/download_task_update.dart';
export 'models/save_location.dart';

// Platform interface
export 'platform/platform_downloader.dart';

// Core engine
export 'core/download_manager.dart';
