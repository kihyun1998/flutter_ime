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

// Static 멤버 초기화
FlutterImePlugin* FlutterImePlugin::instance_ = nullptr;
WNDPROC FlutterImePlugin::original_wndproc_ = nullptr;
bool FlutterImePlugin::ime_disabled_ = false;

// static
void FlutterImePlugin::RegisterWithRegistrar(
    flutter::PluginRegistrarWindows *registrar) {
  auto channel =
      std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_ime",
          &flutter::StandardMethodCodec::GetInstance());

  auto plugin = std::make_unique<FlutterImePlugin>(registrar);

  channel->SetMethodCallHandler(
      [plugin_pointer = plugin.get()](const auto &call, auto result) {
        plugin_pointer->HandleMethodCall(call, std::move(result));
      });

  // EventChannel 설정
  plugin->event_channel_ =
      std::make_unique<flutter::EventChannel<flutter::EncodableValue>>(
          registrar->messenger(), "flutter_ime/input_source_changed",
          &flutter::StandardMethodCodec::GetInstance());

  auto event_handler = std::make_unique<
      flutter::StreamHandlerFunctions<flutter::EncodableValue>>(
      [plugin_pointer = plugin.get()](
          const flutter::EncodableValue* arguments,
          std::unique_ptr<flutter::EventSink<flutter::EncodableValue>>&& events)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->event_sink_ = std::move(events);
        return nullptr;
      },
      [plugin_pointer = plugin.get()](const flutter::EncodableValue* arguments)
          -> std::unique_ptr<flutter::StreamHandlerError<flutter::EncodableValue>> {
        plugin_pointer->event_sink_ = nullptr;
        return nullptr;
      });

  plugin->event_channel_->SetStreamHandler(std::move(event_handler));

  registrar->AddPlugin(std::move(plugin));
}

FlutterImePlugin::FlutterImePlugin(flutter::PluginRegistrarWindows *registrar)
    : registrar_(registrar) {
  instance_ = this;
  flutter_hwnd_ = GetFlutterViewHwnd();
  // WndProc 후킹 설정 (입력 소스 변경 감지용)
  SetupWndProcHook();
}

FlutterImePlugin::~FlutterImePlugin() {
  RemoveWndProcHook();
  instance_ = nullptr;
}

HWND FlutterImePlugin::GetFlutterViewHwnd() {
  if (registrar_ && registrar_->GetView()) {
    return registrar_->GetView()->GetNativeWindow();
  }
  return GetForegroundWindow();
}

// WndProc 후킹 - IME 메시지 차단 및 입력 소스 변경 감지
LRESULT CALLBACK FlutterImePlugin::WndProcHook(HWND hwnd, UINT message, WPARAM wparam, LPARAM lparam) {
  // 입력 소스 변경 감지
  // WM_INPUTLANGCHANGE: 키보드 레이아웃 변경 (예: 영어 → 한국어 키보드)
  // WM_IME_NOTIFY + IMN_SETCONVERSIONMODE: IME 내 한/영 전환
  if (message == WM_INPUTLANGCHANGE) {
    if (instance_) {
      bool is_english = instance_->IsEnglishKeyboard();
      instance_->SendInputSourceChangedEvent(is_english);
    }
  } else if (message == WM_IME_NOTIFY && wparam == IMN_SETCONVERSIONMODE) {
    if (instance_) {
      bool is_english = instance_->IsEnglishKeyboard();
      instance_->SendInputSourceChangedEvent(is_english);
    }
  }

  if (ime_disabled_) {
    switch (message) {
      case WM_IME_STARTCOMPOSITION:
      case WM_IME_COMPOSITION:
      case WM_IME_ENDCOMPOSITION:
      case WM_IME_NOTIFY:
      case WM_IME_SETCONTEXT:
      case WM_IME_CHAR:
        // IME 메시지 차단
        return 0;
      case WM_CHAR:
        // 한글 범위 문자 차단 (가-힣: 0xAC00-0xD7A3, ㄱ-ㅎ: 0x3131-0x314E, ㅏ-ㅣ: 0x314F-0x3163)
        if ((wparam >= 0xAC00 && wparam <= 0xD7A3) ||
            (wparam >= 0x3131 && wparam <= 0x3163)) {
          return 0;
        }
        break;
    }
  }

  if (original_wndproc_) {
    return CallWindowProc(original_wndproc_, hwnd, message, wparam, lparam);
  }
  return DefWindowProc(hwnd, message, wparam, lparam);
}

// 입력 소스 변경 이벤트 전송
void FlutterImePlugin::SendInputSourceChangedEvent(bool is_english) {
  if (event_sink_) {
    event_sink_->Success(flutter::EncodableValue(is_english));
  }
}

void FlutterImePlugin::SetupWndProcHook() {
  if (original_wndproc_ || !flutter_hwnd_) return;

  original_wndproc_ = reinterpret_cast<WNDPROC>(
      SetWindowLongPtr(flutter_hwnd_, GWLP_WNDPROC,
                       reinterpret_cast<LONG_PTR>(WndProcHook)));
}

void FlutterImePlugin::RemoveWndProcHook() {
  if (original_wndproc_ && flutter_hwnd_) {
    SetWindowLongPtr(flutter_hwnd_, GWLP_WNDPROC,
                     reinterpret_cast<LONG_PTR>(original_wndproc_));
    original_wndproc_ = nullptr;
  }
  ime_disabled_ = false;
}

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
  } else if(method_call.method_name().compare("disableIME")==0){
    bool success = DisableIME();
    if(success){
      result->Success();
    }else{
      result->Error("IME_ERROR","Failed to disable IME");
    }
  } else if(method_call.method_name().compare("enableIME")==0){
    bool success = EnableIME();
    if(success){
      result->Success();
    }else{
      result->Error("IME_ERROR","Failed to enable IME");
    }
  } else {
    result->NotImplemented();
  }
}


/// Set IME Enlgish
bool FlutterImePlugin::SetEnglishKeyboard(){
  // get hwnd - Flutter 뷰의 HWND 사용
  HWND hwnd = GetFlutterViewHwnd();
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
  HWND hwnd = GetFlutterViewHwnd();
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

  // IME_CMODE_NATIVE(0x0001)가 설정되어 있으면 한글 모드
  // 설정되어 있지 않으면 영어 모드
  return (conversion & IME_CMODE_NATIVE) == 0;
}

/// Disable IME - WndProc 후킹으로 IME 메시지 차단
bool FlutterImePlugin::DisableIME(){
  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return false;

  // WndProc 후킹 설정
  SetupWndProcHook();
  ime_disabled_ = true;

  // IME 컨텍스트도 분리
  ImmAssociateContextEx(hwnd, nullptr, 0);

  return true;
}

/// Enable IME - WndProc 후킹 해제 및 IME 복원
bool FlutterImePlugin::EnableIME(){
  HWND hwnd = GetFlutterViewHwnd();
  if(!hwnd) return false;

  // IME 메시지 차단 해제
  ime_disabled_ = false;

  // IME 컨텍스트 복원
  ImmAssociateContextEx(hwnd, nullptr, IACE_DEFAULT);

  return true;
}

}  // namespace flutter_ime
