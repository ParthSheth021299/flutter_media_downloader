import 'package:flutter/material.dart';
import 'package:flutter_media_downloader/flutter_media_downloader.dart';

/// Phase 3 Example: Pause and Resume Support
///
/// This example demonstrates:
/// - Pausing active downloads
/// - Resuming paused downloads
/// - HTTP Range request handling
/// - Server capability detection
void main() {
  runApp(const Phase3ExampleApp());
}

class Phase3ExampleApp extends StatelessWidget {
  const Phase3ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Phase 3: Pause & Resume',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const DownloadScreen(),
    );
  }
}

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  late DownloadManager _downloadManager;
  final Map<String, DownloadTaskUpdate> _downloads = {};

  @override
  void initState() {
    super.initState();
    _initializeDownloadManager();
  }

  void _initializeDownloadManager() {
    _downloadManager = DownloadManagerFactory.create(
      maxConcurrentDownloads: 3,
    );

    // Listen to progress updates
    _downloadManager.progressStream.listen((update) {
      setState(() {
        _downloads[update.taskId] = update;
      });
    });
  }

  @override
  void dispose() {
    _downloadManager.dispose();
    super.dispose();
  }

  Future<void> _startDownload(String url) async {
    try {
      final taskId = await _downloadManager.enqueue(
        DownloadRequest(
          url: url,
          saveLocation: SaveLocation.downloads,
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Download started: $taskId')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to start download: $e')),
        );
      }
    }
  }

  Future<void> _pauseDownload(String taskId) async {
    final success = await _downloadManager.pause(taskId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Download paused' : 'Failed to pause'),
        ),
      );
    }
  }

  Future<void> _resumeDownload(String taskId) async {
    final success = await _downloadManager.resume(taskId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Download resuming' : 'Failed to resume'),
        ),
      );
    }
  }

  Future<void> _cancelDownload(String taskId) async {
    final success = await _downloadManager.cancel(taskId);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Download canceled' : 'Failed to cancel'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Phase 3: Pause & Resume'),
        elevation: 2,
      ),
      body: Column(
        children: [
          _buildTestUrlsSection(),
          const Divider(),
          Expanded(
            child: _buildDownloadsList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTestUrlsSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Test Downloads',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: () => _startDownload(
              'https://speed.hetzner.de/100MB.bin',
            ),
            child: const Text('Download 100MB File'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _startDownload(
              'https://speed.hetzner.de/1GB.bin',
            ),
            child: const Text('Download 1GB File'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => _startDownload(
              'https://file-examples.com/storage/fe783a66e5d88649c1b85e8/2017/10/file_example_JPG_1MB.jpg',
            ),
            child: const Text('Download Image (1MB)'),
          ),
        ],
      ),
    );
  }

  Widget _buildDownloadsList() {
    if (_downloads.isEmpty) {
      return const Center(
        child: Text('No downloads yet'),
      );
    }

    return ListView.builder(
      itemCount: _downloads.length,
      itemBuilder: (context, index) {
        final taskId = _downloads.keys.elementAt(index);
        final download = _downloads[taskId]!;
        return _buildDownloadItem(taskId, download);
      },
    );
  }

  Widget _buildDownloadItem(String taskId, DownloadTaskUpdate download) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Task: ${taskId.substring(0, 20)}...',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                _buildStatusChip(download.status),
              ],
            ),
            const SizedBox(height: 12),
            LinearProgressIndicator(
              value: download.progress,
              backgroundColor: Colors.grey[200],
              minHeight: 8,
            ),
            const SizedBox(height: 8),
            Text(
              '${(download.progress * 100).toStringAsFixed(1)}% - '
              '${_formatBytes(download.receivedBytes)} / '
              '${_formatBytes(download.totalBytes)}',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (download.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${download.errorMessage}',
                style: const TextStyle(color: Colors.red),
              ),
            ],
            if (download.filePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Saved: ${download.filePath}',
                style: TextStyle(color: Colors.grey[600], fontSize: 12),
              ),
            ],
            const SizedBox(height: 12),
            _buildActionButtons(taskId, download.status),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip(DownloadStatus status) {
    Color color;
    IconData icon;

    switch (status) {
      case DownloadStatus.queued:
        color = Colors.orange;
        icon = Icons.schedule;
        break;
      case DownloadStatus.downloading:
        color = Colors.blue;
        icon = Icons.download;
        break;
      case DownloadStatus.paused:
        color = Colors.amber;
        icon = Icons.pause;
        break;
      case DownloadStatus.resuming:
        color = Colors.lightBlue;
        icon = Icons.play_arrow;
        break;
      case DownloadStatus.completed:
        color = Colors.green;
        icon = Icons.check_circle;
        break;
      case DownloadStatus.failed:
        color = Colors.red;
        icon = Icons.error;
        break;
      case DownloadStatus.canceled:
        color = Colors.grey;
        icon = Icons.cancel;
        break;
    }

    return Chip(
      avatar: Icon(icon, size: 16, color: Colors.white),
      label: Text(
        status.name.toUpperCase(),
        style: const TextStyle(color: Colors.white, fontSize: 12),
      ),
      backgroundColor: color,
      padding: EdgeInsets.zero,
    );
  }

  Widget _buildActionButtons(String taskId, DownloadStatus status) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (status == DownloadStatus.downloading ||
            status == DownloadStatus.resuming)
          TextButton.icon(
            onPressed: () => _pauseDownload(taskId),
            icon: const Icon(Icons.pause),
            label: const Text('Pause'),
          ),
        if (status == DownloadStatus.paused)
          TextButton.icon(
            onPressed: () => _resumeDownload(taskId),
            icon: const Icon(Icons.play_arrow),
            label: const Text('Resume'),
          ),
        if (status != DownloadStatus.completed &&
            status != DownloadStatus.failed &&
            status != DownloadStatus.canceled)
          TextButton.icon(
            onPressed: () => _cancelDownload(taskId),
            icon: const Icon(Icons.cancel),
            label: const Text('Cancel'),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
          ),
      ],
    );
  }

  String _formatBytes(int bytes) {
    if (bytes < 0) return 'Unknown';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
