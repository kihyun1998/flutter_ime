#ifndef FLUTTER_PLUGIN_IME_MESSAGE_FILTER_H_
#define FLUTTER_PLUGIN_IME_MESSAGE_FILTER_H_

#include <windows.h>

namespace flutter_ime {

// Returns true if [message] should be swallowed while the IME is disabled: any
// IME composition/notify/context/char message, or a WM_CHAR carrying a Korean
// character (Hangul syllables or Jamo). All other messages pass through.
//
// This is the pure classification behind InputSourceManager::ShouldBlockMessage;
// it does not itself consult the "IME disabled" flag.
bool ShouldBlockImeMessage(UINT message, WPARAM wparam);

}  // namespace flutter_ime

#endif  // FLUTTER_PLUGIN_IME_MESSAGE_FILTER_H_
