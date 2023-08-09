#ifndef FLUTTER_PLUGIN_FLUTTER_MEDIA_DOWNLOADER_PLUGIN_H_
#define FLUTTER_PLUGIN_FLUTTER_MEDIA_DOWNLOADER_PLUGIN_H_

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>

#include <memory>

namespace flutter_media_downloader {

class FlutterMediaDownloaderPlugin : public flutter::Plugin {
 public:
  static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);

  FlutterMediaDownloaderPlugin();

  virtual ~FlutterMediaDownloaderPlugin();

  // Disallow copy and assign.
  FlutterMediaDownloaderPlugin(const FlutterMediaDownloaderPlugin&) = delete;
  FlutterMediaDownloaderPlugin& operator=(const FlutterMediaDownloaderPlugin&) = delete;

  // Called when a method is called on this plugin's channel from Dart.
  void HandleMethodCall(
      const flutter::MethodCall<flutter::EncodableValue> &method_call,
      std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
};

}  // namespace flutter_media_downloader

#endif  // FLUTTER_PLUGIN_FLUTTER_MEDIA_DOWNLOADER_PLUGIN_H_
