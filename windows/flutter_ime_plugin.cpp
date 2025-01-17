#include "flutter_ime_plugin.h"

// This must be included before many other Windows headers.
#include <windows.h>
#include <imm.h>

// IMM32 라이브러리 링크
#pragma comment(lib, "imm32.lib")

#include <VersionHelpers.h>

#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>

#include <memory>
#include <sstream>

namespace flutter_ime {

// static
void FlutterImePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_ime",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterImePlugin>();

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  registrar->AddPlugin(std::move(plugin));
}

FlutterImePlugin::FlutterImePlugin() {}

FlutterImePlugin::~FlutterImePlugin() {}

void FlutterImePlugin::HandleMethodCall(
    const flutter::MethodCall<flutter::EncodableValue> &method_call,
    std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
  if (method_call.method_name().compare("setEnglishKeyboard")==0){
    bool success = SetEnglishKeyboard();
    if(success){
      result->Success();
    }else{
      result->Error("IME_ERROR","Failed to set English keyboard");
    }
  } else if(method_call.method_name().compare("isEnglishKeyboard")==0){
    result->Success(flutter::EncodableValue(IsEnglishKeyboard()));
  } else {
    result->NotImplemented();
  }
}


/// Set IME Enlgish
bool FlutterImePlugin::SetEnglishKeyboard(){
  // get hwnd
  HWND hwnd = GetForegroundWindow();
  if(!hwnd) return false;

  // get ime context
  HIMC imc = ImmGetContext(hwnd);
  if(!imc) return false;

  // set ime mode > english
  bool success = ImmSetConversionStatus(imc,IME_CMODE_ALPHANUMERIC, IME_SMODE_NONE);

  // free ime context
  ImmReleaseContext(hwnd,imc);
  return success;
}

// check is ime english
bool FlutterImePlugin::IsEnglishKeyboard(){
  HWND hwnd = GetForegroundWindow();
  if(!hwnd) return false;

  HIMC imc = ImmGetContext(hwnd);
  if(!imc) return false;

  DWORD conversion = 0;
  DWORD sentence = 0;

  // get ime status
  if(!ImmGetConversionStatus(imc,&conversion,&sentence)){
    ImmReleaseContext(hwnd,imc);
    return false;
  }

  // free ime
  ImmReleaseContext(hwnd,imc);

  /// if IME_CMODE_ALPHANUMERIC > is english
  return (conversion & IME_CMODE_ALPHANUMERIC) != 0;
}


}  // namespace flutter_ime
