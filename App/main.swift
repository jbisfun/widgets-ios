import CalculatorKit
import CalendarKit
import ClockKit
import FossifyCommons
import FossifyWidgetIntents
import GalleryKit
import MusicPlayerKit
import NotesKit
import SwiftUI
import VoiceRecorderKit
import WidgetKit

/// Standalone host of the widget extension. Inside launcher-ios the launcher does the same
/// install() calls and opens the tapped app; here the apps' Kits publish this app's own data.
struct FossifyWidgetsApp: App {
    init() {
        CalculatorWidgetData.install()
        CalendarWidgetData.install()
        ClockWidgetData.install()
        GalleryWidgetData.install()
        MusicPlayerWidgetData.install()
        NotesWidgetData.install()
        VoiceRecorderWidgetData.install()
        WidgetBridge.publishTheme()
    }

    var body: some Scene {
        WindowGroup { HowToView().fossifyTheme() }
    }
}

private struct HowToView: View {
    @Environment(\.palette) private var palette
    @State private var opened: String?

    private let widgets: [(String, String)] = [
        ("Calculator", "Large. Buttons calculate right on the home screen."),
        ("Date", "Small. Today's date (Calendar)."),
        ("Event list", "Small to large. Upcoming events for a period."),
        ("Monthly view", "Small or large. The month with its events, with month navigation."),
        ("Digital clock", "Small or medium. Time, date and the next alarm."),
        ("Analogue clock", "Small or medium."),
        ("Gallery folder", "Small to large. A folder's cover and name."),
        ("Music Player", "Medium. The current song with previous, play/pause and next."),
        ("Note", "Small to extra large. A note or checklist."),
        ("Record", "Small. Starts or stops a Voice Recorder recording."),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Touch and hold the home screen, tap Edit > Add Widget (or +), search for Fossify Widgets and pick a widget. Touch and hold a placed widget and choose Edit Widget for its colors, note, folder or period.")
                }
                if let opened {
                    Section("Opened from a widget") {
                        Text("\(opened): inside Fossify (launcher-ios) this opens the app.")
                    }
                }
                Section("Widgets") {
                    ForEach(widgets, id: \.0) { w in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(w.0).font(.headline)
                            Text(w.1).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                Section {
                    Button("Refresh widgets") { WidgetCenter.shared.reloadAllTimelines() }
                    if WidgetBridge.groupIdentifier == nil {
                        Text("No app group entitlement: widgets can't see the apps' data. Install through Jimpactor or sign with the app group.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Fossify Widgets")
        }
        .onOpenURL { url in opened = WidgetBridge.parse(url)?.app ?? url.absoluteString }
    }
}

FossifyWidgetsApp.main()
