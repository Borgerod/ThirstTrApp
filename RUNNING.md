# Running ThirstTrApp

Data you create (rooms, plants, windows, heat sources, floorplan, watered
status, settings) is saved locally with Hive and persists across restarts on
every platform. Web has one catch — see below — which the run script handles.

## Web (Chrome)

One command from the project root:
```
./run-web.ps1
```
It pins the web port (so saved data persists) and starts the CORS proxy (so
Mestergrønn search + images load). In VS Code, F5 →
"ThirstTrApp (Chrome, fixed port)" does the same.

Why the fixed port: the browser stores data in IndexedDB, scoped per origin
*including the port*. A plain `flutter run -d chrome` picks a random port each
launch and opens an empty database every time. `run-web.ps1` always uses
`--web-port=5353`, so it's the same database every run.

Plantasjen search works without the proxy; Mestergrønn + images need it.

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
