import AppIntents
import FossifyCommons
import FossifyWidgetIntents
import SwiftUI
import WidgetKit

// Music Player's MyWidgetProvider + WidgetConfigureActivity (music-player-ios MusicPlayerWidgets):
// title, artist and previous / play-pause / next. The buttons are AudioPlaybackIntents, which iOS
// runs in the app (MusicPlayerWidgetData registered the actions there).

struct MusicWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Music Player"

    @Parameter(title: "Background color", default: .black)
    var background: WidgetColor
    @Parameter(title: "Background opacity (%)", default: 67, inclusiveRange: (0, 100))
    var opacity: Int
    @Parameter(title: "Custom background (#RRGGBB)")
    var backgroundHex: String?
    @Parameter(title: "Text color", default: .theme)
    var text: WidgetColor
    @Parameter(title: "Custom text color (#RRGGBB)")
    var textHex: String?
}

struct MusicEntry: TimelineEntry {
    let date: Date
    let song: MusicWidgetSnapshot
    let background: UInt32
    let text: UInt32
}

struct MusicProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MusicEntry {
        MusicEntry(date: Date(), song: .init(hasTrack: true, title: "Song title", artist: "Artist", isPlaying: false, artwork: nil),
                   background: 0xAA00_0000, text: WidgetTheme.default.primary)
    }

    func snapshot(for configuration: MusicWidgetIntent, in context: Context) async -> MusicEntry {
        var entry = make(configuration)
        if context.isPreview, !entry.song.hasTrack {
            entry = MusicEntry(date: Date(), song: placeholder(in: context).song, background: entry.background, text: entry.text)
        }
        return entry
    }

    func timeline(for configuration: MusicWidgetIntent, in context: Context) async -> Timeline<MusicEntry> {
        Timeline(entries: [make(configuration)], policy: .never)
    }

    private func make(_ c: MusicWidgetIntent) -> MusicEntry {
        MusicEntry(date: Date(),
                   song: Snapshots.music ?? .init(hasTrack: false, title: "", artist: "", isPlaying: false, artwork: nil),
                   background: WidgetColors.resolve(c.background, hex: c.backgroundHex, opacity: c.opacity, fallback: 0xFF00_0000),
                   text: WidgetColors.resolve(c.text, hex: c.textHex, fallback: WidgetColor.theme.argb))
    }
}

/// widget.xml: song_info_holder (60dp, centered title 18sp + artist 16sp) above widget_controls.xml.
struct MusicWidgetView: View {
    let entry: MusicEntry

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text(entry.song.hasTrack ? entry.song.title : "Music Player").font(.system(size: 18))
                Text(entry.song.artist).font(.system(size: 16))
            }
            .lineLimit(1)
            .truncationMode(.tail)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack(spacing: 0) {
                button("backward.end.fill", .previous)
                button(entry.song.isPlaying ? "pause.fill" : "play.fill", .toggle)
                button("forward.end.fill", .next)
            }
            .frame(maxHeight: .infinity)
        }
        .foregroundStyle(Color(argb: entry.text))
        .widgetBackground(entry.background)
        .widgetURL(WidgetBridge.url(WidgetApps.musicPlayer))
    }

    private func button(_ icon: String, _ action: MusicControlAction) -> some View {
        Button(intent: MusicControlIntent(action)) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .frame(maxWidth: .infinity, minHeight: 48, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct MusicPlayerWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.musicPlayer, intent: MusicWidgetIntent.self, provider: MusicProvider()) { entry in
            MusicWidgetView(entry: entry)
        }
        .configurationDisplayName("Music Player")
        .description("The current song with playback controls.")
        // widget_info.xml: targetCell 4x2, min 3x1.
        .supportedFamilies([.systemMedium])
        .contentMarginsDisabled()
    }
}
