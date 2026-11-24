import AppIntents
import FossifyCommons
import SwiftUI
import WidgetKit

// Gallery's MyWidgetProvider + WidgetConfigureActivity (gallery-ios GalleryWidgets): a folder's
// cover and name. Covers are thumbnails GalleryWidgetData writes into the app group.

struct FolderEntity: AppEntity {
    let id: String
    let name: String

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Folder"
    static var defaultQuery = FolderQuery()
    var displayRepresentation: DisplayRepresentation { DisplayRepresentation(title: "\(name)") }
}

struct FolderQuery: EntityQuery {
    private var all: [FolderEntity] {
        (Snapshots.gallery?.folders ?? []).map { FolderEntity(id: $0.path, name: $0.name) }
    }

    func entities(for identifiers: [String]) async throws -> [FolderEntity] {
        all.filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [FolderEntity] { all }

    func defaultResult() async -> FolderEntity? { all.first }
}

struct FolderWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Gallery folder"

    @Parameter(title: "Folder")
    var folder: FolderEntity?
    @Parameter(title: "Show folder name", default: true)
    var showName: Bool
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

struct FolderEntry: TimelineEntry {
    let date: Date
    let folder: GalleryWidgetSnapshot.Folder?
    let image: UIImage?
    let crop: Bool
    let showName: Bool
    let background: UInt32
    let text: UInt32
}

struct FolderProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> FolderEntry {
        FolderEntry(date: Date(), folder: .init(path: "", name: "Camera", thumbnail: nil, count: 0), image: nil, crop: true,
                    showName: true, background: 0xAA00_0000, text: WidgetTheme.default.primary)
    }

    func snapshot(for configuration: FolderWidgetIntent, in context: Context) async -> FolderEntry {
        make(configuration)
    }

    func timeline(for configuration: FolderWidgetIntent, in context: Context) async -> Timeline<FolderEntry> {
        Timeline(entries: [make(configuration)], policy: .never)
    }

    private func make(_ c: FolderWidgetIntent) -> FolderEntry {
        let snapshot = Snapshots.gallery
        let folders = snapshot?.folders ?? []
        let folder = c.folder.flatMap { e in folders.first { $0.path == e.id } } ?? (c.folder == nil ? folders.first : nil)
        return FolderEntry(date: Date(), folder: folder, image: Snapshots.image(folder?.thumbnail), crop: snapshot?.cropThumbnails ?? true,
                           showName: c.showName,
                           background: WidgetColors.resolve(c.background, hex: c.backgroundHex, opacity: c.opacity, fallback: 0xFF00_0000),
                           text: WidgetColors.resolve(c.text, hex: c.textHex, fallback: WidgetColor.theme.argb))
    }
}

/// widget.xml: the folder thumbnail and an optional one-line name.
struct FolderWidgetView: View {
    let entry: FolderEntry

    var body: some View {
        VStack(spacing: 0) {
            Group {
                if let image = entry.image {
                    if entry.crop {
                        // A max(w, h) square, center-cropped, fitted into the image view.
                        Color.clear
                            .aspectRatio(1, contentMode: .fit)
                            .overlay(Image(uiImage: image).resizable().scaledToFill())
                            .clipped()
                    } else {
                        Image(uiImage: image).resizable().scaledToFit()
                    }
                } else {
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 28))
                        .foregroundStyle(Color(argb: entry.text).opacity(0.6))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
            if entry.showName {
                Text(entry.folder?.name ?? "Open Gallery once")
                    .font(.system(size: 16))
                    .foregroundStyle(Color(argb: entry.text))
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity)
                    .padding(2)
                    .padding(.bottom, 4)
            }
        }
        .padding(4)
        .widgetBackground(entry.background)
        .widgetURL(WidgetBridge.url(WidgetApps.gallery, entry.folder.map { ["folder": $0.path] } ?? [:]))
    }
}

struct FolderWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.galleryFolder, intent: FolderWidgetIntent.self, provider: FolderProvider()) { entry in
            FolderWidgetView(entry: entry)
        }
        .configurationDisplayName("Gallery folder")
        .description("The cover of a Gallery folder.")
        // widget_info.xml: targetCell 2x1, down to 1x1, resizable.
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
        .contentMarginsDisabled()
    }
}
