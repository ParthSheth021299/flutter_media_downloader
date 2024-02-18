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
                    context,
                    'https://www.kasandbox.org/programming-images/avatars/spunky-sam-green.png',
                    null,
                    "test",
                    "png");
              },
              child: const Text('Media Download')),
        ),
      ),
    );
  }
}
