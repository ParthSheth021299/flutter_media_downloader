# flutter_media_downloader

This plugin helps user to download medias for example pdf files, image files etc. 
A plugin for creating and managing download tasks. Supports iOS and Android.

This plugin is using native methods for push notifications for both platforms (Android & iOS).
This is easy to use plugin.

## Working Demo
![DEMO](demo.gif)

## Android integration

You just need to add permissions in your manifest file for the push notification. And other permission for read external storage.
```xml
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.POST_NOTIFICATIONS" />
```

### Open downloaded file from notification

To make tapping on notification open the downloaded file on Android, add the
following code to `AndroidManifest.xml`:

```xml
<provider
    android:name="androidx.core.content.FileProvider"
    android:authorities="${applicationId}.provider"
    android:exported="false"
    android:grantUriPermissions="true">
    <meta-data
        android:name="android.support.FILE_PROVIDER_PATHS"
        android:resource="@xml/provider_paths" />
</provider>
```

**Notes**

- By default location is provided you can also change it as per your need. Apart from this you can also provide filename if you want to change.
- Here in this plugin for iOS device when media file is downloaded then it is open and from there you can store wherever you wan to store.
- Here for push notifications in both the devices native methods are used. 
- For the permission handling you don't need manage it externally all the things are setup you just need to use it.

## Usage

### Import and full example of using this plugin

```dart
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
          child: ElevatedButton(onPressed: () async {
            _flutterMediaDownloaderPlugin.downloadPDF(context,'https://urban-care-documents.s3.ap-south-1.amazonaws.com/dev/health-records/prescription/M02JW8-F6ACD014AD4B/788/2678/M02JW8-F6ACD014AD4B-2537882678.pdf?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Date=20230914T090042Z&X-Amz-SignedHeaders=host&X-Amz-Expires=3600&X-Amz-Credential=AKIAUTC332YGVB3H5MUA%2F20230914%2Fap-south-1%2Fs3%2Faws4_request&X-Amz-Signature=cb1ab4e4cc217f5e79a81c51f6a75fdaa8b7f2f507c2c481bbd0fa0b15086312');
          }, child: const Text('Media Download')),
        ),
      ),
    );
  }
}

```
## Support the Project

If you find this plugin helpful, consider supporting its development:

- [Buy Me a Coffee](https://www.buymeacoffee.com/parthsheth)

Your support is greatly appreciated!

## Bugs/Requests

Feel free to open an issue if you encounter any problems or think that the
plugin is missing some feature.

![Email](img.gif) parthsheth100@gmail.com