# Running ThirstTrApp

Data you create (rooms, plants, windows, heat sources, floorplan, watered
status, settings) is saved locally with Hive and persists across restarts on
every platform. Web has one catch — see below — which the run script handles.

## Web (Chrome)

One command from the project root:
```
./run-web.ps1
```
It serves the app on a fixed port (5353), opens it in your normal browser, and
starts the CORS proxy (so Mestergrønn search + images load). In VS Code, F5 →
"ThirstTrApp (web, persistent)" does the same.

Why this setup — two things must hold for web data to survive restarts:

1. **Fixed port.** The browser stores data in IndexedDB, scoped per origin
   *including the port*. A plain `flutter run -d chrome` picks a random port
   each launch and opens an empty database every time.
2. **Your own browser, not a Flutter-managed one.** `flutter run -d chrome`
   gives Chrome a throwaway profile that Flutter shuffles and deletes on
   start/stop — data written there gets lost even on the right port (verified
   empirically 2026-07-19). `-d web-server` + your real browser has neither
   problem: data survives stop-debug, killed terminals, `flutter clean`, all
   of it.

Trade-off: Dart breakpoints don't bind in web-server mode. For step-debugging
use the "ThirstTrApp (Chrome debug, data NOT persistent)" config — anything
you add in that session is throwaway.

Plantasjen search works without the proxy; Mestergrønn + images need it.

If the app runs on the wrong port anyway, it shows a red banner ("Data lagres
IKKE ...") at the top in debug builds — data added during such a session is
stranded on that random-port origin and won't be there next launch.

## Native (Windows desktop) — no proxy, no port needed

```
flutter run -d windows
```
Data persists to the real filesystem automatically. No CORS, so no proxy.

## Optional flags

- Real receipt OCR key: append
  `--dart-define=OCR_SPACE_KEY=your_key` (else the throttled demo key is used).
- Hosted web build proxy: `--dart-define=MG_CORS_PROXY=https://your-proxy/?url=`.

## Reminders don't fire on web

Scheduling OS notifications isn't supported in the browser, so reminders are
skipped on web (the in-app task list still works). Use a native build to test
notifications.
