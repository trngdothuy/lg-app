# LG Red List Endangered Species Living Atlas
### Developed by Trang Do Thuy (@trngdothuy) for Liquid Galaxy - GeSOC 2026
A Flutter mobile app that turns a Liquid Galaxy (LG) multi-screen rig into an interactive exhibit about Vietnam's critically endangered and endangered species. The phone acts as a remote control and info panel; the rig displays synced camera movement, species markers, and AI-generated storytelling content.

## What this app does

- Connects to a Liquid Galaxy rig over SSH from the Settings screen (manual entry or QR code scan).
- Shows all 40 species as markers on a Google Map (phone) and matching paw icons on the rig, synced in real time as the phone's map is panned/zoomed.
- Tapping a species pin flies the rig to that location and displays an info balloon with an AI-generated narrative, color-coded highlight bullets, a photo, and text-to-speech narration on the phone.
- "History Journey" and "Looking Ahead" buttons show themed AI-generated content (past decline / future outlook) for the selected species, also spoken via TTS.
- A chatbot screen lets the user ask questions about the app and the species dataset, using their own Gemini API key.
- Tools screen provides rig maintenance actions (relaunch/reboot/power off Google Earth, clear KML/logo overlays) and developer utilities for pre-generating AI content.
- Dark mode, shared across every screen via a `ThemeProvider`.

## Architecture

```
lib/
├── main.dart                 # App entry point, Hive/dotenv init, cache seeding
├── data/species_data.dart    # Hardcoded species dataset (40 species, Vietnam)
├── models/species.dart       # Species model
├── providers/
│   ├── theme_provider.dart   # App-wide dark mode state
│   └── nav_bar_provider.dart # Shared bottom navigation bar
├── services/
│   ├── lg_service.dart       # SSH commands to the rig (flyTo, markers, info balloons)
│   ├── kml_service.dart      # Builds all KML sent to the rig
│   ├── species_service.dart  # IUCN + Gemini calls, Hive caching, story generation
│   └── chat_service.dart     # Chatbot Gemini calls, conversation state
├── screens/
│   ├── home_screen.dart
│   ├── maps_screen.dart      # Main map + species interaction screen
│   ├── settings_screen.dart  # SSH connection setup
│   ├── tools_screen.dart     # Rig maintenance + dev utilities
│   └── chat_screen.dart      # AI chatbot
└── widgets/
    ├── dark_mode_toggle.dart
    └── quick_actions_bar.dart
```

## How the rig sync works

- **Camera sync**: the phone's Google Map fires camera-move events, which are throttled and sent to the rig as a `LookAt` KML written to each screen's `/tmp/query.txt` over SSH. A busy-guard prevents overlapping SSH calls from queuing up during fast dragging.
- **Species markers**: a single KML file (`species.kml`) with one 2D icon Placemark per species is loaded once via a persistent NetworkLink (`kmls.txt`), so markers stay visible at any zoom level.
- **Info balloons**: tapping a pin sends a separate KML with a `gx:balloonVisibility` Placemark to the rightmost screen, styled to match the phone's dark theme.
- **Screen numbering**: master is `lg1`; rightmost/leftmost slave numbers are derived from `screens` (`(screens ~/ 2) + 1` and `+ 2` respectively) — this convention was determined empirically for the current rig and may need re-verifying on different hardware.

## AI content pipeline

1. On marker tap, `species_service.dart` fetches live data from the IUCN Red List API and falls back to hardcoded data on failure.
2. That data is sent to Gemini (`gemini-3.5-flash`) with a structured prompt requesting a narrative, a TTS script, and 3–5 color-coded highlight bullets (threat/action/fact/hope), returned as JSON.
3. Successful responses are cached in Hive, keyed by `<internalTaxonId>_<mode>_v3` (`mode` = initial/history/future). Only genuine Gemini successes are cached — failures are never stored, so they retry on the next run instead of getting stuck with fallback text.
4. **Free-tier Gemini quota is very limited (as low as 5 requests/minute in testing).** The Tools screen has a "Preload remaining stories" button that walks through all 40 species with a 20-second delay between calls, skipping anything already cached. This is meant to be run ahead of time, not during a live demo.
5. Once fully preloaded, the cache can be exported to a JSON file (Tools screen → "Export story cache") and bundled into the app as `assets/species_stories_seed.json`, so a fresh install on any device — including the exhibit's own phone — starts pre-populated and never needs to call Gemini live.

## Setup

1. Clone the repo and run `flutter pub get`.
2. Create a `.env` file in the project root with:
   ```
   IUCN_API_KEY=your_iucn_key
   GEMINI_API_KEY=your_gemini_key
   ```
   `.env` must also be listed under `flutter: assets:` in `pubspec.yaml`.
3. Make sure the following are declared under `assets:` in `pubspec.yaml`: `.env`, `assets/logo/`, `assets/kml/`, and `assets/species_stories_seed.json` (once you've generated one).
4. Run on an emulator or device: `flutter run`.

## Known limitations / things to verify on the real rig

- KML `gx:balloonVisibility` auto-open behavior can vary by the exact Earth build LG ships — confirmed working on the development VM, worth re-testing on first connect to the physical rig.
- The rightmost/leftmost screen number formulas above are based on the dev VM's 3-screen layout and should be re-confirmed on the real rig's screen count/layout.
- The History timeline is currently a static AI-estimated trend rendered as shrinking dots inside the info balloon, not an interactive draggable slider — KML cannot run the JavaScript a real slider would need.
- Free-tier Gemini quota means the story cache should be fully preloaded and exported **before** the demo, not generated live.

## Dev-only tools

Two buttons on the Tools screen are for content preparation, not the exhibit itself:
- **Preload remaining stories** — walks the full species list, skipping cached entries, generating anything missing.
- **Export story cache** — writes the current Hive cache to a JSON file on-device, to be pulled off and committed as the bundled seed file.

These should be removed or hidden before a public/release build.