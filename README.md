# ThirstTrApp 🌱

A Flutter app for cataloguing your house plants and tracking their watering,
fertilizing and cleaning schedules — with reminders that adapt to each plant's
placement, light, nearby heat sources, drafts, season and local weather.

## Features (V1)

- **Plant portfolio** — flat list or grouped by room.
- **Rich plant info** — species (via Perenual), size/maturity/age, condition,
  price, receipt photo, pet/child hazards, light, room placement, links to
  windows & heat sources, draft/heat flags.
- **Adaptive care scheduler** — base watering interval (from species care data)
  adjusted by light, season, room temperature, heat sources, drafts and live
  weather (Open-Meteo). Tap any plan to see the "why" factor breakdown.
- **Reminders** — local notifications with **Fullført** (done) and **Utsett**
  (postpone) actions when the soil isn't dry yet.
- **Add plants 4 ways** — species search, barcode scan, receipt photo, by name.
- **Rooms & objects** — model rooms, windows (size/facing/open-frequency) and
  heat sources (type/spread/intensity/setting) to feed the scheduler.
- **Settings** — units (Norwegian/metric default), home location (drives
  weather), Perenual API key, notification time.

## APIs

- **Perenual Plant Open API** — species list/details, care guide, pest/disease,
  hardiness map. Needs a free key: add it under **Innstillinger → Perenual API**.
- **MET Norway / yr.no** (`api.met.no` Locationforecast 2.0) — weather. Free,
  no key; requires an identifying `User-Agent` header. Global, best in Nordics.
- **OpenStreetMap Nominatim** — geocoding (city → coordinates). Free, no key,
  same `User-Agent` requirement.

## Architecture

```
lib/
  core/        enums, json helpers, formatting
  models/      Plant, Room, WindowObject, HeatSource, Species, CareTask, AppSettings
  data/        Hive local store, repositories, Riverpod providers
  services/    perenual_api, weather_api, scheduler, notification_service
  features/    home, tasks, plant_detail (+ edit), add_plant, rooms, settings
```

- **State:** Riverpod 3 (`Notifier` controllers).
- **Storage:** Hive, JSON-map per entity (no codegen / build_runner).
- **Notifications:** flutter_local_notifications 22 (named-parameter API) + timezone.

## Running

> ⚠️ This machine has **no Android SDK** installed, so Android builds fail with
> "No Android SDK found". Install Android Studio (it sets up the SDK) or point
> Flutter at an existing SDK: `flutter config --android-sdk <path>`.

```bash
flutter pub get
flutter run            # needs an Android/iOS device or emulator
flutter test           # unit tests
flutter analyze        # 0 issues
```

Web is enabled for quick UI preview (`flutter run -d chrome`), but camera,
barcode and notifications only work on a real Android/iOS device.

## Roadmap (V2)

- Draw a home blueprint/map and place plants + objects on it.
- Receipt OCR to auto-extract plant name/price.
- Hardiness-zone map viewer.
