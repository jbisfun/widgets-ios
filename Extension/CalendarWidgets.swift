import AppIntents
import FossifyCommons
import SwiftUI
import WidgetKit

// Calendar's MyWidgetDateProvider, MyWidgetListProvider and MyWidgetMonthlyProvider with their
// configure activities (calendar-ios CalendarWidgets), drawn from CalendarWidgetData's snapshot.

private let mediumAlpha = 0.5 // MEDIUM_ALPHA

private func calendarColors(_ background: WidgetColor, _ backgroundHex: String?, _ opacity: Int, _ text: WidgetColor, _ textHex: String?) -> (UInt32, UInt32) {
    (WidgetColors.resolve(background, hex: backgroundHex, opacity: opacity, fallback: 0xFF00_0000),
     WidgetColors.resolve(text, hex: textHex, fallback: WidgetColor.theme.argb))
}

private func nextMidnight(after date: Date) -> Date {
    Calendar.current.nextDate(after: date, matching: DateComponents(hour: 0, minute: 0), matchingPolicy: .nextTime)
        ?? date.addingTimeInterval(86_400)
}

private func dayCode(_ date: Date) -> String {
    let f = DateFormatter()
    f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyyMMdd"
    return f.string(from: date)
}

// MARK: - Date (widget_date.xml)

struct DateWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Date"

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

struct ColorsEntry: TimelineEntry {
    let date: Date
    let background: UInt32
    let text: UInt32
}

struct DateProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ColorsEntry {
        ColorsEntry(date: Date(), background: 0xAA00_0000, text: WidgetTheme.default.primary)
    }

    func snapshot(for c: DateWidgetIntent, in context: Context) async -> ColorsEntry { make(c, Date()) }

    func timeline(for c: DateWidgetIntent, in context: Context) async -> Timeline<ColorsEntry> {
        let midnight = nextMidnight(after: Date())
        return Timeline(entries: [make(c, Date()), make(c, midnight)], policy: .after(midnight))
    }

    private func make(_ c: DateWidgetIntent, _ date: Date) -> ColorsEntry {
        let (bg, text) = calendarColors(c.background, c.backgroundHex, c.opacity, c.text, c.textHex)
        return ColorsEntry(date: date, background: bg, text: text)
    }
}

struct DateWidgetView: View {
    let entry: ColorsEntry

    var body: some View {
        let cal = Calendar.current
        GeometryReader { geo in
            let inner = max(0, geo.size.height - 4)
            VStack(spacing: 0) {
                // TextClock "d", weight 2, autosized
                Text("\(cal.component(.day, from: entry.date))")
                    .font(.system(size: 300))
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
                    .padding(.top, 8)
                    .frame(width: geo.size.width - 8, height: inner * 2 / 3)
                // TextClock "MMM", weight 1, autosized
                Text(DateFormatter().shortMonthSymbols[cal.component(.month, from: entry.date) - 1])
                    .font(.system(size: 300))
                    .minimumScaleFactor(0.01)
                    .lineLimit(1)
                    .padding(.bottom, 8)
                    .frame(width: geo.size.width - 8, height: inner / 3)
            }
            .foregroundStyle(Color(argb: entry.text))
            .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
        }
        .widgetBackground(entry.background)
        .widgetURL(WidgetBridge.url(WidgetApps.calendar))
    }
}

struct CalendarDateWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.calendarDate, intent: DateWidgetIntent.self, provider: DateProvider()) { entry in
            DateWidgetView(entry: entry)
        }
        .configurationDisplayName("Date")
        .description("Today's date.")
        // widget_date_info.xml: 1x1.
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

// MARK: - Event list (widget_event_list.xml + EventListWidgetAdapter)

/// The period choices of WidgetListConfigureActivity.showPeriodSelector().
enum ListPeriod: String, AppEnum {
    case today, week, month, year

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Period"
    static var caseDisplayRepresentations: [ListPeriod: DisplayRepresentation] = [
        .today: "Today only",
        .week: "Within the next 1 week",
        .month: "Within the next 1 month",
        .year: "Within the next 1 year",
    ]
}

struct ListWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Event list"

    @Parameter(title: "Period", default: .year)
    var period: ListPeriod
    @Parameter(title: "Within the next … days (overrides the period)", inclusiveRange: (1, 3650))
    var customDays: Int?
    @Parameter(title: "Show widget header", default: true)
    var showHeader: Bool
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

struct ListEntry: TimelineEntry {
    enum Item {
        case month(String)
        case day(String, isPast: Bool)
        case event(CalendarWidgetSnapshot.ListEvent)
    }

    let date: Date
    let items: [Item]
    let hasData: Bool
    let showHeader: Bool
    let fontSize: Double
    let dimPast: Bool
    let dimCompleted: Bool
    let background: UInt32
    let text: UInt32
}

struct ListProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> ListEntry {
        ListEntry(date: Date(), items: [], hasData: true, showHeader: true, fontSize: 17, dimPast: false, dimCompleted: false,
                  background: 0xAA00_0000, text: WidgetTheme.default.primary)
    }

    func snapshot(for c: ListWidgetIntent, in context: Context) async -> ListEntry { make(c, Date()) }

    /// updatePeriodMillis is 10 minutes upstream: entries every 15 minutes keep "past" dimming,
    /// the period and the header date current for two hours.
    func timeline(for c: ListWidgetIntent, in context: Context) async -> Timeline<ListEntry> {
        let now = Date()
        let dates = (0...8).map { now.addingTimeInterval(Double($0) * 900) } + [nextMidnight(after: now)]
        let end = now.addingTimeInterval(8 * 900)
        return Timeline(entries: dates.filter { $0 <= end }.sorted().map { make(c, $0) }, policy: .after(end))
    }

    private func make(_ c: ListWidgetIntent, _ date: Date) -> ListEntry {
        let (bg, text) = calendarColors(c.background, c.backgroundHex, c.opacity, c.text, c.textHex)
        guard let snapshot = Snapshots.calendar else {
            return ListEntry(date: date, items: [], hasData: false, showHeader: c.showHeader, fontSize: 17, dimPast: false,
                             dimCompleted: false, background: bg, text: text)
        }
        // widgetListEvents(): from the oldest past event shown to the end of the period.
        let now = Int64(date.timeIntervalSince1970)
        let from = now - Int64(snapshot.displayPastMinutes * 60)
        let to: Int64
        if let days = c.customDays {
            to = now + Int64(days) * 86_400
        } else {
            switch c.period {
            case .today: to = Int64(nextMidnight(after: date).timeIntervalSince1970) - 1
            case .week: to = now + 604_800
            case .month: to = now + 2_592_000
            case .year: to = now + 31_536_000
            }
        }
        // getEventListItems(): month and day sections around the (already sorted) events.
        var items: [ListEntry.Item] = []
        var prevMonth = "", prevDay = ""
        let today = dayCode(date)
        for e in snapshot.listEvents where e.endTS >= from && e.startTS <= to {
            if e.monthLabel != prevMonth {
                items.append(.month(e.monthLabel))
                prevMonth = e.monthLabel
            }
            if e.dayCode != prevDay {
                items.append(.day(e.dayTitle, isPast: e.dayCode != today && e.startTS < now))
                prevDay = e.dayCode
            }
            items.append(.event(e))
            if items.count > 60 { break }
        }
        return ListEntry(date: date, items: items, hasData: true, showHeader: c.showHeader, fontSize: snapshot.fontSize,
                         dimPast: snapshot.dimPastEvents, dimCompleted: snapshot.dimCompletedTasks, background: bg, text: text)
    }
}

struct ListWidgetView: View {
    let entry: ListEntry

    var body: some View {
        let fontSize = entry.fontSize
        let textColor = Color(argb: entry.text)
        let weak = Color(argb: entry.text.withAlphaFactor(mediumAlpha))
        VStack(spacing: 0) {
            if entry.showHeader {
                // widget_event_list_header.xml
                HStack(spacing: 0) {
                    Text(DigitalClockView.format(entry.date, "MMM d yyyy (EEEE)"))
                        .font(.system(size: fontSize))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .padding(.horizontal, 8)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Link(destination: WidgetBridge.url(WidgetApps.calendar)) { icon("calendar") }
                    Link(destination: WidgetBridge.url(WidgetApps.calendar, ["new": "1"])) { icon("plus") }
                }
                .foregroundStyle(textColor)
                .padding(.top, 8)
            }
            if !entry.hasData {
                OpenAppHint(text: "Open Calendar once to show your events here.", color: textColor)
            } else if entry.items.isEmpty {
                Text("No upcoming events.")
                    .font(.system(size: fontSize))
                    .foregroundStyle(textColor)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            } else {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(entry.items.enumerated()), id: \.offset) { _, item in
                        row(item, fontSize: fontSize, textColor: textColor, weak: weak)
                    }
                }
                .padding(.top, 4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .clipped()
            }
        }
        .widgetBackground(entry.background)
        .widgetURL(WidgetBridge.url(WidgetApps.calendar))
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 18, weight: .medium))
            .padding(.horizontal, 8)
            .frame(minHeight: 36)
    }

    @ViewBuilder
    private func row(_ item: ListEntry.Item, fontSize: Double, textColor: Color, weak: Color) -> some View {
        switch item {
        case .month(let title):
            // event_list_section_month_widget.xml
            Text(title.uppercased())
                .font(.system(size: 16, weight: .light))
                .foregroundStyle(textColor)
                .padding(.leading, 8)
                .padding(.bottom, 4)
        case let .day(title, isPast):
            // event_list_section_day_widget.xml
            Text(title)
                .font(.system(size: fontSize - 3, weight: .bold))
                .foregroundStyle(entry.dimPast && isPast ? weak : textColor)
                .padding(.leading, 20)
        case .event(let e):
            eventRow(e, fontSize: fontSize, textColor: textColor, weak: weak)
        }
    }

    /// event_list_item_widget.xml, EventListWidgetAdapter.setupListEvent()
    private func eventRow(_ e: CalendarWidgetSnapshot.ListEvent, fontSize: Double, textColor: Color, weak: Color) -> some View {
        let now = Int64(entry.date.timeIntervalSince1970)
        let isPast = e.endTS < now
        let dim = (e.isTask && e.isTaskCompleted && entry.dimCompleted) || (entry.dimPast && isPast && !e.isTask)
        return HStack(alignment: .top, spacing: 0) {
            RoundedRectangle(cornerRadius: 2)
                .fill(Color(argb: e.color))
                .frame(width: 4)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 4) {
                    if e.isTask {
                        Image(systemName: "checkmark.circle").font(.system(size: fontSize - 2))
                    }
                    Text(e.title)
                        .font(.system(size: fontSize))
                        .strikethrough(e.strike)
                        .lineLimit(1)
                }
                Text(e.time)
                    .font(.system(size: fontSize))
                    .lineLimit(2)
                    .opacity(0.8)
            }
            .foregroundStyle(dim ? weak : textColor)
            .padding(.leading, 8)
            .padding(.trailing, 4)
            Spacer(minLength: 0)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
}

struct CalendarListWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.calendarList, intent: ListWidgetIntent.self, provider: ListProvider()) { entry in
            ListWidgetView(entry: entry)
        }
        .configurationDisplayName("Event list")
        .description("Your upcoming events.")
        // widget_list_info.xml: 4x4, down to 1x1.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}

// MARK: - Monthly view (fragment_month_widget[_grid].xml)

/// MyWidgetMonthlyProvider.targetDate: one month offset shared by every monthly widget, like
/// upstream's companion object.
enum MonthlyTarget {
    static let key = "calendar_widget_month_offset"

    static var offset: Int {
        get { WidgetBridge.defaults?.integer(forKey: key) ?? 0 }
        set { WidgetBridge.defaults?.set(newValue, forKey: key) }
    }
}

/// PREV / NEXT / GO_TO_TODAY of the monthly widget (delta 0 = today).
struct CalendarMonthIntent: AppIntent {
    static var title: LocalizedStringResource = "Change the month"
    static var isDiscoverable = false

    @Parameter(title: "Months")
    var delta: Int

    init() {}
    init(_ delta: Int) { self.delta = delta }

    func perform() async throws -> some IntentResult {
        // The app publishes 2 months back to 12 ahead.
        MonthlyTarget.offset = delta == 0 ? 0 : max(-2, min(12, MonthlyTarget.offset + delta))
        return .result()
    }
}

struct MonthlyWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Monthly view"

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

struct MonthlyEntry: TimelineEntry {
    let date: Date
    let month: CalendarWidgetSnapshot.Month?
    let snapshot: CalendarWidgetSnapshot?
    let offset: Int
    let background: UInt32
    let text: UInt32
}

struct MonthlyProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MonthlyEntry {
        MonthlyEntry(date: Date(), month: nil, snapshot: nil, offset: 0, background: 0xAA00_0000, text: WidgetTheme.default.primary)
    }

    func snapshot(for c: MonthlyWidgetIntent, in context: Context) async -> MonthlyEntry { make(c, Date()) }

    func timeline(for c: MonthlyWidgetIntent, in context: Context) async -> Timeline<MonthlyEntry> {
        let midnight = nextMidnight(after: Date())
        return Timeline(entries: [make(c, Date()), make(c, midnight)], policy: .after(midnight))
    }

    private func make(_ c: MonthlyWidgetIntent, _ date: Date) -> MonthlyEntry {
        let (bg, text) = calendarColors(c.background, c.backgroundHex, c.opacity, c.text, c.textHex)
        let snapshot = Snapshots.calendar
        let offset = MonthlyTarget.offset
        let target = Calendar.current.date(byAdding: .month, value: offset, to: date) ?? date
        let code = String(dayCode(target).prefix(6))
        return MonthlyEntry(date: date, month: snapshot?.months.first { $0.code == code }, snapshot: snapshot, offset: offset,
                            background: bg, text: text)
    }
}

struct MonthlyWidgetView: View {
    let entry: MonthlyEntry
    @Environment(\.widgetFamily) private var family

    private var gridColor: Color { Color(argb: 0xFF33_3333) }

    var body: some View {
        let fontSize = (entry.snapshot?.fontSize ?? 17) - (family == .systemSmall ? 5 : 0)
        let textColor = Color(argb: entry.text)
        VStack(spacing: 0) {
            HStack(spacing: 0) {
                arrow("chevron.left", -1)
                Text(entry.month?.title ?? DigitalClockView.format(entry.date, "LLLL yyyy"))
                    .font(.system(size: fontSize + 3))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .padding(.vertical, family == .systemSmall ? 2 : 8)
                    .frame(maxWidth: .infinity)
                if entry.offset != 0 && family != .systemSmall {
                    arrow("calendar", 0)
                }
                arrow("chevron.right", 1)
                if family != .systemSmall {
                    Link(destination: WidgetBridge.url(WidgetApps.calendar, ["new": "1"])) { icon("plus") }
                }
            }
            .foregroundStyle(textColor)
            if let month = entry.month, let snapshot = entry.snapshot, month.days.count == 42 {
                labels(snapshot, fontSize: fontSize)
                grid(month, snapshot, fontSize: fontSize)
            } else {
                OpenAppHint(text: "Open Calendar once to show your events here.", color: textColor)
            }
        }
        .widgetBackground(entry.background)
        .widgetURL(WidgetBridge.url(WidgetApps.calendar))
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: family == .systemSmall ? 13 : 18, weight: .medium))
            .padding(.horizontal, family == .systemSmall ? 4 : 8)
            .frame(minHeight: family == .systemSmall ? 24 : 36)
    }

    private func arrow(_ name: String, _ delta: Int) -> some View {
        Button(intent: CalendarMonthIntent(delta)) { icon(name) }.buttonStyle(.plain)
    }

    /// first_row_widget.xml, updateDayLabels()
    private func labels(_ s: CalendarWidgetSnapshot, fontSize: Double) -> some View {
        HStack(spacing: 0) {
            if s.showWeekNumbers {
                Text("#").frame(maxWidth: .infinity).foregroundStyle(Color(argb: entry.text))
            }
            ForEach(0..<7, id: \.self) { i in
                let weekend = s.highlightWeekends && (entry.month?.days[i].isWeekend ?? false)
                Text(s.weekDayLetters.indices.contains(i) ? s.weekDayLetters[i] : "")
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(Color(argb: weekend ? s.weekendColor : entry.text))
            }
        }
        .font(.system(size: fontSize, weight: .bold))
        .lineLimit(1)
        .minimumScaleFactor(0.5)
        .padding(.vertical, family == .systemSmall ? 1 : 4)
    }

    private func grid(_ month: CalendarWidgetSnapshot.Month, _ s: CalendarWidgetSnapshot, fontSize: Double) -> some View {
        let smaller = fontSize - 3
        let eventFont = smaller - 3
        let rowH = ceil(eventFont * 1.25) + 2
        let today = dayCode(entry.date)
        return VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { row in
                if s.showGrid && row > 0 { gridColor.frame(height: 1) }
                HStack(spacing: 0) {
                    if s.showWeekNumbers {
                        // WeekNumberStyle: the fourth day of the week decides the week of the year
                        Text("\(month.days[row * 7 + 3].weekOfYear):")
                            .font(.system(size: smaller, weight: .light))
                            .foregroundStyle(Color(argb: entry.text))
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    ForEach(0..<7, id: \.self) { col in
                        if s.showGrid && col > 0 { gridColor.frame(width: 1) }
                        dayCell(month, row * 7 + col, s, today: today, smaller: smaller, eventFont: eventFont, rowH: rowH)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
    }

    private func dayCell(_ month: CalendarWidgetSnapshot.Month, _ i: Int, _ s: CalendarWidgetSnapshot, today: String,
                         smaller: Double, eventFont: Double, rowH: Double) -> some View {
        let day = month.days[i]
        let dayText = s.highlightWeekends && day.isWeekend ? s.weekendColor : entry.text
        let cur = day.isThisMonth ? dayText : dayText.withAlphaFactor(mediumAlpha)
        let isToday = day.code == today
        return VStack(spacing: 0) {
            // day_monthly_number_view.xml, addDayNumber()
            Text("\(day.value)")
                .font(.system(size: smaller))
                .foregroundStyle(isToday ? cur.contrastColor : Color(argb: cur))
                .lineLimit(1)
                .frame(minWidth: smaller * 1.7, minHeight: smaller * 1.7)
                .background { if isToday { Circle().fill(Color(argb: cur)) } }
                .padding(.vertical, 1)
            if family != .systemSmall {
                ForEach(Array(day.slots.enumerated()), id: \.offset) { slot, index in
                    if month.events.indices.contains(index) {
                        eventView(month, index, slot: slot, at: i, s, eventFont: eventFont, rowH: rowH)
                    } else {
                        Color.clear.frame(height: rowH)
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
    }

    private func eventView(_ month: CalendarWidgetSnapshot.Month, _ index: Int, slot: Int, at i: Int, _ s: CalendarWidgetSnapshot,
                           eventFont: Double, rowH: Double) -> some View {
        let e = month.events[index]
        func has(_ d: Int) -> Bool { month.days[d].slots.indices.contains(slot) && month.days[d].slots[slot] == index }
        let prevInRun = i > 0 && i % 7 != 0 && has(i - 1)
        let nextInRun = i < month.days.count - 1 && (i + 1) % 7 != 0 && has(i + 1)
        let isPast = e.endTS < Int64(entry.date.timeIntervalSince1970)
        let dim = (e.isTask && e.isTaskCompleted && s.dimCompletedTasks) || (s.dimPastEvents && isPast && !e.isTask)
        let fg = e.color.contrastColor.opacity(dim ? mediumAlpha : 1)
        let r: CGFloat = 2
        let radii = RectangleCornerRadii(topLeading: prevInRun ? 0 : r, bottomLeading: prevInRun ? 0 : r,
                                         bottomTrailing: nextInRun ? 0 : r, topTrailing: nextInRun ? 0 : r)
        let leading: CGFloat = prevInRun ? 0 : 1
        let trailing: CGFloat = nextInRun ? 0 : 1
        return ZStack(alignment: .leading) {
            UnevenRoundedRectangle(cornerRadii: radii)
                .fill(Color(argb: e.color))
                .padding(.vertical, 1)
                .padding(.leading, leading)
                .padding(.trailing, trailing)
            HStack(spacing: 1) {
                if !prevInRun && e.isTask {
                    Image(systemName: "checkmark.circle").font(.system(size: eventFont))
                }
                Text(prevInRun ? " " : e.title)
                    .font(.system(size: eventFont))
                    .strikethrough(e.strike)
                    .lineLimit(1)
                    .fixedSize()
            }
            .foregroundStyle(fg)
            .padding(.horizontal, 2 + leading)
        }
        .frame(maxWidth: .infinity, minHeight: rowH, maxHeight: rowH, alignment: .leading)
        .clipped()
    }
}

struct CalendarMonthlyWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.calendarMonthly, intent: MonthlyWidgetIntent.self, provider: MonthlyProvider()) { entry in
            MonthlyWidgetView(entry: entry)
        }
        .configurationDisplayName("Monthly view")
        .description("The month with its events.")
        // widget_monthly_info.xml: 4x4, down to 2x2.
        .supportedFamilies([.systemSmall, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}
