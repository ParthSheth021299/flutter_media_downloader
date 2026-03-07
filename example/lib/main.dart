import 'package:flutter/material.dart';
import 'package:flutter_media_downloader/flutter_media_downloader.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
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

  Future<void> _startDownload() async {
    try {
      final taskId = await _downloadManager.enqueue(
        DownloadRequest(
          url:
              'https://www.kasandbox.org/programming-images/avatars/spunky-sam-green.png',
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Media Downloader',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Flutter Media Downloader'),
          elevation: 2,
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ElevatedButton(
                    onPressed: _startDownload,
                    child: const Text('Download Image'),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Active downloads: ${_downloadManager.activeDownloadCount}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  Text(
                    'Queued downloads: ${_downloadManager.queuedDownloadCount}',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            const Divider(),
            Expanded(
              child: _downloads.isEmpty
                  ? const Center(
                      child: Text(
                          'No downloads yet. Tap the button above to start.'),
                    )
                  : ListView.builder(
                      itemCount: _downloads.length,
                      itemBuilder: (context, index) {
                        final taskId = _downloads.keys.elementAt(index);
                        final download = _downloads[taskId]!;
                        return _buildDownloadItem(taskId, download);
                      },
                    ),
            ),
          ],
        ),
      ),
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
            Text(
              'Task: ${taskId.substring(0, 20)}...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Status: ${download.status.name}'),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: download.progress,
              backgroundColor: Colors.grey[200],
            ),
            const SizedBox(height: 4),
            Text(
              '${(download.progress * 100).toStringAsFixed(1)}%',
              style: TextStyle(color: Colors.grey[600]),
            ),
            if (download.filePath != null) ...[
              const SizedBox(height: 8),
              Text(
                'Saved: ${download.filePath}',
                style: TextStyle(color: Colors.green[700], fontSize: 12),
              ),
            ],
            if (download.errorMessage != null) ...[
              const SizedBox(height: 8),
              Text(
                'Error: ${download.errorMessage}',
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
