#include "include/flutter_media_downloader/flutter_media_downloader_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_media_downloader_plugin.h"

void FlutterMediaDownloaderPluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_media_downloader::FlutterMediaDownloaderPlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
