#include "ime_message_filter.h"

namespace flutter_ime {

bool ShouldBlockImeMessage(UINT message, WPARAM wparam) {
  switch (message) {
    case WM_IME_STARTCOMPOSITION:
    case WM_IME_COMPOSITION:
    case WM_IME_ENDCOMPOSITION:
    case WM_IME_NOTIFY:
    case WM_IME_SETCONTEXT:
    case WM_IME_CHAR:
      return true;
    case WM_CHAR:
      // Korean characters: Hangul syllables 0xAC00-0xD7A3, Jamo 0x3131-0x3163.
      return (wparam >= 0xAC00 && wparam <= 0xD7A3) ||
             (wparam >= 0x3131 && wparam <= 0x3163);
    default:
      return false;
  }
}

}  // namespace flutter_ime
