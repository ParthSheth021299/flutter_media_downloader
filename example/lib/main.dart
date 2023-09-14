import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_media_downloader/flutter_media_downloader.dart';

void main() {
  runApp(const MyApp());
  WidgetsFlutterBinding.ensureInitialized();
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final _flutterMediaDownloaderPlugin = MediaDownload();

  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Plugin example app'),
        ),
        body: Center(
          child: ElevatedButton(
              onPressed: () async {
                _flutterMediaDownloaderPlugin.downloadMedia(
                    context, 'https://urban-care-documents.s3.ap-south-1.amazonaws.com/dev/health-records/prescription/M02JW8-F6ACD014AD4B/788/2678/M02JW8-F6ACD014AD4B-2537882678.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20230914T090042Z&X-Amz-SignedHeaders=host&X-Amz-Expires=3600&X-Amz-Credential=AKIAUTC332YGVB3H5MUA%2F20230914%2Fap-south-1%2Fs3%2Faws4_request&X-Amz-Signature=cb1ab4e4cc217f5e79a81c51f6a75fdaa8b7f2f507c2c481bbd0fa0b15086312');
              },
              child: const Text('Media Download')),
        ),
      ),
    );
  }
}
