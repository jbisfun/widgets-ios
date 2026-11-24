import AppIntents
import FossifyCommons
import FossifyWidgetIntents
import SwiftUI
import WidgetKit

// Voice Recorder's MyWidgetRecordDisplayProvider + WidgetRecordDisplayConfigureActivity
// (voice-recorder-ios VoiceRecorderWidgets): a microphone, white while idle and tinted with the
// widget color while recording, always at the widget color's alpha. Tapping starts recording
// (opens the app: iOS only starts the microphone in the foreground) or stops and saves it.

struct RecordWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Record"

    @Parameter(title: "Color", default: .darkOrange)
    var color: WidgetColor
    @Parameter(title: "Opacity (%)", default: 100, inclusiveRange: (0, 100))
    var opacity: Int
    @Parameter(title: "Custom color (#RRGGBB)")
    var colorHex: String?
}

struct RecordEntry: TimelineEntry {
    let date: Date
    let isRecording: Bool
    let color: UInt32
}

struct RecordProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> RecordEntry {
        RecordEntry(date: Date(), isRecording: false, color: 0xFFF5_7C00)
    }

    func snapshot(for configuration: RecordWidgetIntent, in context: Context) async -> RecordEntry {
        make(configuration)
    }

    func timeline(for configuration: RecordWidgetIntent, in context: Context) async -> Timeline<RecordEntry> {
        Timeline(entries: [make(configuration)], policy: .never)
    }

    private func make(_ c: RecordWidgetIntent) -> RecordEntry {
        RecordEntry(date: Date(), isRecording: Snapshots.recorder?.isRecording ?? false,
                    color: WidgetColors.resolve(c.color, hex: c.colorHex, opacity: c.opacity, fallback: 0xFFF5_7C00))
    }
}

struct RecordWidgetView: View {
    let entry: RecordEntry

    var body: some View {
        let alpha = Double((entry.color >> 24) & 0xFF) / 255
        // changeWidgetIcon(): widget color while recording, white otherwise.
        let tint = entry.isRecording ? Color(argb: entry.color | 0xFF00_0000) : .white
        Group {
            if entry.isRecording {
                Button(intent: StopRecordingIntent()) { mic(tint, alpha) }
            } else {
                Button(intent: StartRecordingIntent()) { mic(tint, alpha) }
            }
        }
        .buttonStyle(.plain)
        .containerBackground(for: .widget) { Color.clear }
        .accessibilityLabel(entry.isRecording ? "Stop recording" : "Start recording")
    }

    private func mic(_ tint: Color, _ alpha: Double) -> some View {
        MicrophoneShape()
            .fill(tint.opacity(alpha))
            .aspectRatio(1, contentMode: .fit)
            .padding(5) // layout_margin 5dp
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
    }
}

struct RecordWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.voiceRecorder, intent: RecordWidgetIntent.self, provider: RecordProvider()) { entry in
            RecordWidgetView(entry: entry)
        }
        .configurationDisplayName("Record")
        .description("Start or stop a Voice Recorder recording.")
        // minWidth/minHeight 40dp, no resizeMode: one cell.
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

/// voice-recorder-ios MicrophoneShape (ic_microphone_vector pathData).
struct MicrophoneShape: Shape {
    private static let data = "M12 14.02c1.691 0 3.046-1.365 3.046-3.057l0.01-6.113c0-1.69-1.365-3.056-3.056-3.056S8.943 3.159 8.943 4.85v6.113c0 1.691 1.366 3.057 3.057 3.057zm5.4-3.057c0 3.057-2.588 5.196-5.4 5.196-2.812 0-5.406-2.007-5.406-5.064 0 0 0-1.037-0.844-1.033-0.843 0.005-0.882 0.901-0.882 0.901 0 3.474 2.771 6.347 6.113 6.847v3.273s-0.107 1.11 1.025 1.123c1.11 0.013 1.013-1.124 1.013-1.124V17.81c3.341-0.49 6.113-3.362 6.113-6.847 0 0 0.004-0.906-0.835-0.893-0.856 0.014-0.897 0.893-0.897 0.893z"
    private static let path = VectorPath.parse(data)

    func path(in rect: CGRect) -> Path {
        let s = min(rect.width, rect.height) / 24
        let t = CGAffineTransform(translationX: rect.midX - 12 * s, y: rect.midY - 12 * s).scaledBy(x: s, y: s)
        return Self.path.applying(t)
    }
}
