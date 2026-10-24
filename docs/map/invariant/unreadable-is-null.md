# Unreadable is null, not false

## The fact
Each platform's input-source reader for the stream, `readEnglishStateOrNull`, returns `null` — never `false` — whenever the English state cannot be read, and only the one-shot `isEnglishKeyboard` collapses that `null` to `false`.

## Why it is cross-cutting
`ChangeStream` treats `null` as "ask again" and anything else as a value to compare. The two readers are separate code in separate backends (`WindowsIme.readEnglishStateOrNull` reads an IMM32 context; `MacosIme.readEnglishStateOrNull` copies a TIS input source); they do not call each other or any shared reader. Each has to make the same choice on its own. A reader that answered `false` for "unreadable" would feed the stream a real value.

## Territories it holds in
- [English classification](../territory/english-classification.md) — both readers, and the `isEnglishKeyboard` wrappers that collapse to `false`.
- [Change streams](../territory/change-streams.md) — `ChangeStream._reread` skipping `null` and keeping the baseline.
- [Backend dispatch](../territory/backend-dispatch.md) — the stream is wired to the `…OrNull` readers, not to `isEnglishKeyboard`.
- [IME disable](../territory/ime-disable.md) — a detached context is the main unreadable state on Windows.

## What a violation looks like
`onInputSourceChanged` emits `false` on every `disableIME()` and `true` on every `enableIME()` on Windows, or `false` then `true` around a momentary gap on macOS — switches the user never made. Under the README's "force English" recipe, each phantom `false` triggers a `setEnglishKeyboard`.

## Discovery history
- Windows: commit `045e819` (2026-07-22), "stop disable/enable faking events" — the split was introduced there (`WindowsIme.readEnglishStateOrNull` doc).
- macOS: the same split, "for the same reason" (`MacosIme.readEnglishStateOrNull` doc), introduced with the pushed input-source stream in commit `d48cd08` (2026-07-22).

## Where it will recur
Any new reader handed to a `ChangeStream` or `ValuePoller`: if it can fail to read, it must return `null` for that, and keep any `false`-collapsing wrapper for one-shot queries only.
