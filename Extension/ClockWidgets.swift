import AppIntents
import FossifyCommons
import SwiftUI
import WidgetKit

// MyDigitalTimeWidgetProvider / MyAnalogueTimeWidgetProvider (clock-ios ClockWidgets). WidgetKit
// draws the time: Text(.time) (live) when the app's 24-hour setting matches the system's,
// otherwise per-minute entries; the analogue hands always come from per-minute entries.

struct DigitalClockIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Digital clock"

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

struct AnalogueClockIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Analogue clock"

    @Parameter(title: "Background color", default: .black)
    var background: WidgetColor
    @Parameter(title: "Background opacity (%)", default: 67, inclusiveRange: (0, 100))
    var opacity: Int
    @Parameter(title: "Custom background (#RRGGBB)")
    var backgroundHex: String?
}

struct ClockEntry: TimelineEntry {
    let date: Date
    let background: UInt32
    let text: UInt32
    let nextAlarm: String
    let use24Hour: Bool
    /// Text(.time) keeps the time current between entries.
    let liveTime: Bool
}

private enum ClockTimeline {
    /// The system's own setting (Text(.time) follows it).
    static var system24Hour: Bool {
        !(DateFormatter.dateFormat(fromTemplate: "j", options: 0, locale: .current) ?? "").contains("a")
    }

    /// Entries every minute for the next hour; Text(.time) needs only the midnight (date) change.
    static func entries(perMinute: Bool, alarmChange: Date?, make: (Date) -> ClockEntry) -> Timeline<ClockEntry> {
        let cal = Calendar.current
        let now = Date()
        let minute = cal.dateInterval(of: .minute, for: now)?.start ?? now
        var dates = [now]
        if perMinute {
            dates += (1...60).compactMap { cal.date(byAdding: .minute, value: $0, to: minute) }
        }
        if let midnight = cal.nextDate(after: now, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime) {
            dates.append(midnight)
        }
        if let alarmChange, alarmChange > now { dates.append(alarmChange.addingTimeInterval(1)) }
        dates = Array(Set(dates)).sorted()
        let end = perMinute ? cal.date(byAdding: .minute, value: 60, to: minute) ?? now.addingTimeInterval(3600)
            : dates.dropFirst().first ?? now.addingTimeInterval(3600)
        return Timeline(entries: dates.filter { $0 <= end }.map(make), policy: .after(end))
    }
}

struct DigitalClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), background: 0xAA00_0000, text: WidgetTheme.default.primary, nextAlarm: "", use24Hour: true, liveTime: true)
    }

    func snapshot(for configuration: DigitalClockIntent, in context: Context) async -> ClockEntry {
        make(configuration, Date())
    }

    func timeline(for configuration: DigitalClockIntent, in context: Context) async -> Timeline<ClockEntry> {
        let entry = make(configuration, Date())
        return ClockTimeline.entries(perMinute: !entry.liveTime, alarmChange: Snapshots.clock?.nextAlarmDate) { make(configuration, $0) }
    }

    private func make(_ c: DigitalClockIntent, _ date: Date) -> ClockEntry {
        let clock = Snapshots.clock
        let use24 = clock?.use24Hour ?? ClockTimeline.system24Hour
        // The alarm string is only valid until that alarm rings (the app republishes when it runs).
        let alarm = (clock?.nextAlarmDate ?? .distantFuture) > date ? clock?.nextAlarm ?? "" : ""
        return ClockEntry(date: date,
                          background: WidgetColors.resolve(c.background, hex: c.backgroundHex, opacity: c.opacity, fallback: 0xFF00_0000),
                          text: WidgetColors.resolve(c.text, hex: c.textHex, fallback: WidgetColor.theme.argb),
                          nextAlarm: alarm, use24Hour: use24, liveTime: use24 == ClockTimeline.system24Hour)
    }
}

struct AnalogueClockProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), background: 0xAA00_0000, text: 0xFFFF_FFFF, nextAlarm: "", use24Hour: true, liveTime: false)
    }

    func snapshot(for configuration: AnalogueClockIntent, in context: Context) async -> ClockEntry {
        make(configuration, Date())
    }

    func timeline(for configuration: AnalogueClockIntent, in context: Context) async -> Timeline<ClockEntry> {
        ClockTimeline.entries(perMinute: true, alarmChange: nil) { make(configuration, $0) }
    }

    private func make(_ c: AnalogueClockIntent, _ date: Date) -> ClockEntry {
        ClockEntry(date: date,
                   background: WidgetColors.resolve(c.background, hex: c.backgroundHex, opacity: c.opacity, fallback: 0xFF00_0000),
                   text: 0xFFFF_FFFF, nextAlarm: "", use24Hour: true, liveTime: false)
    }
}

/// widget_digital: the time, "EEE, d MMM" and the next alarm, weighted 4:1:1 and auto-sized.
struct DigitalClockView: View {
    let entry: ClockEntry

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.height / (entry.nextAlarm.isEmpty ? 5 : 6)
            VStack(spacing: 0) {
                Group {
                    if entry.liveTime {
                        Text(entry.date, style: .time)
                    } else {
                        Text(Self.format(entry.date, entry.use24Hour ? "HH:mm" : "h:mm a"))
                    }
                }
                .font(.system(size: max(2, unit * 4 * 0.95)))
                .lineLimit(1)
                .minimumScaleFactor(0.02)
                .frame(maxWidth: .infinity)
                .frame(height: unit * 4)
                Text(Self.format(entry.date, "EEE, d MMM"))
                    .font(.system(size: max(2, unit * 0.95)))
                    .lineLimit(1)
                    .minimumScaleFactor(0.02)
                    .frame(maxWidth: .infinity)
                    .frame(height: unit)
                if !entry.nextAlarm.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "alarm")
                            .resizable()
                            .scaledToFit()
                            .frame(width: min(18, unit), height: min(18, unit))
                        Text(entry.nextAlarm)
                            .font(.system(size: min(14, unit * 0.9)))
                            .lineLimit(1)
                            .minimumScaleFactor(0.2)
                    }
                    .frame(height: unit)
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .foregroundStyle(Color(argb: entry.text))
        .widgetTextShadow()
        .padding([.horizontal, .bottom], 4)
        .padding(.top, 8)
        .widgetBackground(entry.background)
        .widgetURL(WidgetBridge.url(WidgetApps.clock))
    }

    static func format(_ date: Date, _ pattern: String) -> String {
        let f = DateFormatter()
        f.locale = .current
        f.dateFormat = pattern
        return f.string(from: date)
    }
}

/// Android's AnalogClock: twelve ticks and white hour/minute hands, square and centered.
struct AnalogueClockView: View {
    let entry: ClockEntry

    var body: some View {
        let c = Calendar.current.dateComponents([.hour, .minute], from: entry.date)
        let minutes = Double(c.minute ?? 0)
        let hours = Double((c.hour ?? 0) % 12) + minutes / 60
        GeometryReader { geo in
            let r = min(geo.size.width, geo.size.height) / 2
            ZStack {
                ClockTicks().stroke(.white, style: StrokeStyle(lineWidth: max(1, r * 0.045), lineCap: .round))
                ClockHand(angle: hours * 30, length: 0.5)
                    .stroke(.white, style: StrokeStyle(lineWidth: max(1.5, r * 0.08), lineCap: .round))
                ClockHand(angle: minutes * 6, length: 0.72)
                    .stroke(.white, style: StrokeStyle(lineWidth: max(1, r * 0.05), lineCap: .round))
            }
            .shadow(color: .black.opacity(0.6), radius: max(1, r * 0.03), x: 0, y: max(0.5, r * 0.01))
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .padding(8)
        .widgetBackground(entry.background)
        .widgetURL(WidgetBridge.url(WidgetApps.clock))
    }
}

private func clockPoint(_ rect: CGRect, _ angle: Double, _ fraction: CGFloat) -> CGPoint {
    let r = min(rect.width, rect.height) / 2
    let a = angle * .pi / 180
    return CGPoint(x: rect.midX + CGFloat(sin(a)) * r * fraction, y: rect.midY - CGFloat(cos(a)) * r * fraction)
}

private struct ClockTicks: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        for i in 0..<12 {
            p.move(to: clockPoint(rect, Double(i) * 30, 0.78))
            p.addLine(to: clockPoint(rect, Double(i) * 30, 0.92))
        }
        return p
    }
}

private struct ClockHand: Shape {
    let angle: Double
    let length: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.midX, y: rect.midY))
        p.addLine(to: clockPoint(rect, angle, length))
        return p
    }
}

struct DigitalClockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.clockDigital, intent: DigitalClockIntent.self, provider: DigitalClockProvider()) { entry in
            DigitalClockView(entry: entry)
        }
        .configurationDisplayName("Digital clock")
        .description("The time, the date and your next alarm.")
        // widget_digital_clock_info: 3x1 cells, down to 1x1.
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct AnalogueClockWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.clockAnalogue, intent: AnalogueClockIntent.self, provider: AnalogueClockProvider()) { entry in
            AnalogueClockView(entry: entry)
        }
        .configurationDisplayName("Analogue clock")
        .description("An analogue clock.")
        // widget_analogue_clock_info: 2x1 cells, down to 1x1.
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}
