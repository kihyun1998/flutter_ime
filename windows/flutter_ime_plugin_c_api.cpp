#include "include/flutter_ime/flutter_ime_plugin_c_api.h"

#include <flutter/plugin_registrar_windows.h>

#include "flutter_ime_plugin.h"

void FlutterImePluginCApiRegisterWithRegistrar(
    FlutterDesktopPluginRegistrarRef registrar) {
  flutter_ime::FlutterImePlugin::RegisterWithRegistrar(
      flutter::PluginRegistrarManager::GetInstance()
          ->GetRegistrar<flutter::PluginRegistrarWindows>(registrar));
}
