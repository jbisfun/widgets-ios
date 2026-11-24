import AppIntents
import FossifyCommons
import SwiftUI
import WidgetKit

// Notes' MyWidgetProvider + WidgetConfigureActivity (notes-ios NotesWidgets): one note, text or
// checklist, from the snapshot NotesWidgetData publishes.

struct NoteEntity: AppEntity {
    let id: String
    let title: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Note"
    static var defaultQuery = NoteQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(title)") }
}

struct NoteQuery: EntityQuery {
    private var all: [NoteEntity] {
        (Snapshots.notes?.notes ?? []).map { NoteEntity(id: String($0.id), title: $0.title) }
    }

    func entities(for identifiers: [String]) async throws -> [NoteEntity] {
        all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [NoteEntity] { all }

    /// NotesHelper.getNotes { }: the first unlocked note.
    func defaultResult() async -> NoteEntity? {
        let notes = Snapshots.notes?.notes ?? []
        return (notes.first { !$0.isLocked } ?? notes.first).map { NoteEntity(id: String($0.id), title: $0.title) }
    }
}

struct NoteWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Note"

    @Parameter(title: "Note")
    var note: NoteEntity?
    @Parameter(title: "Show note title", default: false)
    var showTitle: Bool
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

struct NoteEntry: TimelineEntry {
    let date: Date
    let note: NotesWidgetSnapshot.Note?
    let gravity: Int
    let fontSize: Double
    let monospaced: Bool
    let showTitle: Bool
    let background: UInt32
    let text: UInt32
}

struct NoteProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> NoteEntry {
        NoteEntry(date: Date(), note: .init(id: 1, title: "General note", isChecklist: false, isLocked: false,
                                             text: "Thank you for using Fossify Notes.", tasks: []),
                  gravity: 0, fontSize: 17, monospaced: false, showTitle: false, background: 0xAA00_0000, text: WidgetTheme.default.primary)
    }

    func snapshot(for configuration: NoteWidgetIntent, in context: Context) async -> NoteEntry {
        var entry = make(configuration)
        if context.isPreview, entry.note == nil { entry = placeholder(in: context) }
        return entry
    }

    func timeline(for configuration: NoteWidgetIntent, in context: Context) async -> Timeline<NoteEntry> {
        Timeline(entries: [make(configuration)], policy: .never)
    }

    private func make(_ c: NoteWidgetIntent) -> NoteEntry {
        let snapshot = Snapshots.notes
        let notes = snapshot?.notes ?? []
        let note = c.note.flatMap { e in notes.first { String($0.id) == e.id } } ?? (c.note == nil ? notes.first { !$0.isLocked } : nil)
        return NoteEntry(date: Date(), note: note, gravity: snapshot?.gravity ?? 0, fontSize: snapshot?.fontSize ?? 17,
                         monospaced: snapshot?.monospaced ?? false, showTitle: c.showTitle,
                         background: WidgetColors.resolve(c.background, hex: c.backgroundHex, opacity: c.opacity, fallback: 0xFF00_0000),
                         text: WidgetColors.resolve(c.text, hex: c.textHex, fallback: WidgetColor.theme.argb))
    }
}

/// widget.xml (optional one-line title) + widget_text_layout / item_checklist_widget rows.
struct NoteWidgetView: View {
    let entry: NoteEntry

    /// DONE_CHECKLIST_ITEM_ALPHA
    private let doneAlpha = 0.4

    var body: some View {
        let color = Color(argb: entry.text)
        VStack(spacing: 0) {
            if entry.showTitle {
                Text(entry.note?.title ?? "")
                    .font(.system(size: 12))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(2)
                    .padding(.top, 4)
            }
            if let note = entry.note {
                if note.isLocked {
                    OpenAppHint(text: "Protected note. Tap to open it in Notes.", color: color)
                } else if note.isChecklist {
                    VStack(spacing: 0) {
                        ForEach(Array(note.tasks.enumerated()), id: \.offset) { _, task in
                            Text(task.title)
                                .font(font)
                                .strikethrough(task.isDone)
                                .opacity(task.isDone ? doneAlpha : 1)
                                .multilineTextAlignment(textAlignment)
                                .frame(maxWidth: .infinity, alignment: alignment)
                                .padding(.leading, 16)
                                .padding([.top, .bottom, .trailing], 8)
                        }
                    }
                    .frame(maxHeight: .infinity, alignment: .top)
                    .clipped()
                } else {
                    Text(note.text)
                        .font(font)
                        .multilineTextAlignment(textAlignment)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: Alignment(horizontal: alignment.horizontal, vertical: .top))
                        .padding(16) // small_margin + normal_margin
                        .clipped()
                }
            } else {
                OpenAppHint(text: "Open Notes once, then pick a note in Edit Widget.", color: color)
            }
        }
        .foregroundStyle(color)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .widgetBackground(entry.background)
        // setupAppOpenIntent(): open the app on this note.
        .widgetURL(WidgetBridge.url(WidgetApps.notes, entry.note.map { ["note": String($0.id)] } ?? [:]))
    }

    private var alignment: Alignment { [.leading, .center, .trailing][max(0, min(2, entry.gravity))] }
    private var textAlignment: TextAlignment { [.leading, .center, .trailing][max(0, min(2, entry.gravity))] }
    private var font: Font {
        entry.monospaced ? .system(size: entry.fontSize, design: .monospaced) : .system(size: entry.fontSize)
    }
}

struct NoteWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.notes, intent: NoteWidgetIntent.self, provider: NoteProvider()) { entry in
            NoteWidgetView(entry: entry)
        }
        .configurationDisplayName("Note")
        .description("A note or checklist from Notes.")
        // widget_info.xml: targetCell 2x2, down to 1x1, resizable.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}
