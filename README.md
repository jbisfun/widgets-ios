# widgets-ios

The Fossify apps' home-screen widgets re-created for the real iOS home screen as a WidgetKit
extension (SwiftUI, App Intents). launcher-ios embeds it; this repo also builds a small host app.

    idl build -c release     # -> build/release/FossifyWidgets.ipa with PlugIns/WidgetsExtension.appex

Needs `appintentsmetadataprocessor` on PATH ([re-appintentsmetadataprocessor](https://codeberg.org/viraptor/re-appintentsmetadataprocessor),
e.g. `nix profile install nixpkgs#re-appintentsmetadataprocessor`): idl writes `Metadata.appintents`, without
which iOS ignores the widget settings and buttons.

## Widgets

| Widget | Families | Settings (Edit Widget) | Interactive |
| --- | --- | --- | --- |
| Calculator | large, extra large | background color + opacity, text color | every key (state in the app group) |
| Date (Calendar) | small | colors | |
| Event list (Calendar) | small - extra large | period / custom days, header, colors | |
| Monthly view (Calendar) | small, large, extra large | colors | previous / today / next month |
| Digital clock | small, medium | colors | |
| Analogue clock | small, medium | background | |
| Gallery folder | small - large | folder, folder name, colors | |
| Music Player | medium | colors | previous / play-pause / next (in the app process) |
| Note | small - extra large | note, title, colors | |
| Record (Voice Recorder) | small | color + opacity | start (opens the app) / stop and save |

Colors are a Material palette plus "Theme" (the apps' primary color) or a custom `#RRGGBB`. Taps elsewhere
open `fossify://open/<app>?...` in the launcher (note id, folder path).

## Add a widget

Touch and hold the home screen, Edit > Add Widget, search "Fossify Widgets", pick one. Touch and hold a
placed widget > Edit Widget for its settings.

## How it works

- `Extension/`: the `@main WidgetBundle`, one widget per Android AppWidgetProvider, drawn like the
  in-launcher ports (`*-ios/Sources/UI/Widgets.swift`) from snapshots.
- The apps publish snapshots into the launcher's app group (`FossifyCommons.WidgetBridge`,
  `WidgetSnapshots.swift`) from `<App>WidgetData.install()` in each Kit (`Sources/Model/HomeScreenWidget.swift`)
  and reload the timelines when their data changes. Gallery covers and music artwork are written as JPEG files.
- `Shared/`: intents that must run in the app (music controls as `AudioPlaybackIntent`, recording); the app
  links this module too so they are in its `Metadata.appintents`.
- Re-signing renames the app group (`group.org.fossify.launcher.ios` becomes `...ios.<TEAMID>` through
  Jimpactor); `FossifyCommons.AppGroup` finds the entitled one at runtime.

Differences forced by iOS: widgets show the data the apps last published (they update when an app runs, not
live; open the app if a widget looks stale); timelines refresh on WidgetKit's budget (clock and event list use
pre-computed per-minute / 15-minute entries, the digital clock uses live `Text(.time)` when the app's 24-hour
setting matches the system's); no scrolling lists (long notes and event lists are cut); widget backgrounds are
the iOS container (its corner radius, transparency over the home screen); starting a recording opens Voice
Recorder (the microphone can't start in the background); protected notes show no content (no password prompt
in widgets); the calculator shows results after each key press round-trip (intents), and its history joins the
app's history the next time the launcher runs; one month offset is shared by all monthly widgets
(like upstream) and stays within the published 2 months back to 12 ahead.
