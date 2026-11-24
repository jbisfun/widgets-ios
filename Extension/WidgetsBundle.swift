import SwiftUI
import WidgetKit

/// The extension's entry point: every Fossify app widget (Android AppWidgetProviders).
@main
struct FossifyWidgetsBundle: WidgetBundle {
    var body: some Widget {
        CalculatorWidget()
        CalendarDateWidget()
        CalendarListWidget()
        CalendarMonthlyWidget()
        DigitalClockWidget()
        AnalogueClockWidget()
        FolderWidget()
        MusicPlayerWidget()
        NoteWidget()
        RecordWidget()
    }
}
