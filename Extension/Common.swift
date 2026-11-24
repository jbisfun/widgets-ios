import AppIntents
import FossifyCommons
import SwiftUI
import WidgetKit

// MARK: Colors (the configure activities' color pickers + alpha seekbar)

/// The color choices of the widget settings: AppIntents has no color parameter, so the
/// Material palette of Fossify's color picker plus "Theme" (the apps' primary color).
enum WidgetColor: String, AppEnum {
    case theme, white, black, gray, red, pink, purple, deepPurple, indigo, blue, lightBlue, cyan, teal, green,
         fossifyGreen, lightGreen, lime, yellow, amber, orange, darkOrange, deepOrange, brown, blueGrey

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Color"
    static var caseDisplayRepresentations: [WidgetColor: DisplayRepresentation] = [
        .theme: "Theme (primary color)",
        .white: "White",
        .black: "Black",
        .gray: "Gray",
        .red: "Red",
        .pink: "Pink",
        .purple: "Purple",
        .deepPurple: "Deep purple",
        .indigo: "Indigo",
        .blue: "Blue",
        .lightBlue: "Light blue",
        .cyan: "Cyan",
        .teal: "Teal",
        .green: "Green",
        .fossifyGreen: "Fossify green",
        .lightGreen: "Light green",
        .lime: "Lime",
        .yellow: "Yellow",
        .amber: "Amber",
        .orange: "Orange",
        .darkOrange: "Dark orange",
        .deepOrange: "Deep orange",
        .brown: "Brown",
        .blueGrey: "Blue grey",
    ]

    var argb: UInt32 {
        switch self {
        case .theme: return Snapshots.theme.primary | 0xFF00_0000
        case .white: return 0xFFFF_FFFF
        case .black: return 0xFF00_0000
        case .gray: return 0xFF9E_9E9E
        case .red: return 0xFFF4_4336
        case .pink: return 0xFFE9_1E63
        case .purple: return 0xFF9C_27B0
        case .deepPurple: return 0xFF67_3AB7
        case .indigo: return 0xFF3F_51B5
        case .blue: return 0xFF21_96F3
        case .lightBlue: return 0xFF03_A9F4
        case .cyan: return 0xFF00_BCD4
        case .teal: return 0xFF00_9688
        case .green: return 0xFF4C_AF50
        case .fossifyGreen: return 0xFF10_6D1F
        case .lightGreen: return 0xFF8B_C34A
        case .lime: return 0xFFCD_DC39
        case .yellow: return 0xFFFF_EB3B
        case .amber: return 0xFFFF_C107
        case .orange: return 0xFFFF_9800
        case .darkOrange: return 0xFFF5_7C00
        case .deepOrange: return 0xFFFF_5722
        case .brown: return 0xFF79_5548
        case .blueGrey: return 0xFF60_7D8B
        }
    }
}

enum WidgetColors {
    /// `#RRGGBB` / `#AARRGGBB` (also without #) or nil.
    static func hex(_ s: String?) -> UInt32? {
        guard var s = s?.trimmingCharacters(in: .whitespaces), !s.isEmpty else { return nil }
        if s.hasPrefix("#") { s.removeFirst() }
        guard s.count == 6 || s.count == 8, let v = UInt32(s, radix: 16) else { return nil }
        return s.count == 6 ? v | 0xFF00_0000 : v
    }

    /// mBgColorWithoutTransparency.adjustAlpha(mBgAlpha): the choice (or custom hex) at `opacity` %.
    static func resolve(_ choice: WidgetColor?, hex custom: String?, opacity: Int? = nil, fallback: UInt32) -> UInt32 {
        let rgb = hex(custom) ?? choice?.argb ?? fallback
        guard let opacity else { return rgb }
        let alpha = UInt32((Double(max(0, min(100, opacity))) / 100 * 255).rounded())
        return alpha << 24 | (rgb & 0x00FF_FFFF)
    }

    /// default_widget_bg_color #AA000000 = black at 67 %.
    static let defaultOpacity = 67
}

extension UInt32 {
    /// adjustAlpha(factor)
    func withAlphaFactor(_ factor: Double) -> UInt32 {
        let a = Double(self >> 24) * factor
        return UInt32(a.rounded()) << 24 | (self & 0x00FF_FFFF)
    }
}

// MARK: Snapshots from the apps

enum Snapshots {
    static var theme: WidgetTheme { WidgetBridge.load(WidgetTheme.self, "theme") ?? .default }
    static var notes: NotesWidgetSnapshot? { WidgetBridge.load(NotesWidgetSnapshot.self, "notes") }
    static var calendar: CalendarWidgetSnapshot? { WidgetBridge.load(CalendarWidgetSnapshot.self, "calendar") }
    static var clock: ClockWidgetSnapshot? { WidgetBridge.load(ClockWidgetSnapshot.self, "clock") }
    static var gallery: GalleryWidgetSnapshot? { WidgetBridge.load(GalleryWidgetSnapshot.self, "gallery") }
    static var music: MusicWidgetSnapshot? { WidgetBridge.load(MusicWidgetSnapshot.self, "musicplayer") }
    static var recorder: RecorderWidgetSnapshot? { WidgetBridge.load(RecorderWidgetSnapshot.self, "voicerecorder") }

    static func image(_ relative: String?) -> UIImage? {
        guard let relative, let url = WidgetBridge.fileURL(relative) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

// MARK: Shared looks

extension View {
    /// widget_round_background tinted with the widget color, as the widget's container. iOS draws
    /// the container itself (with its own corner radius); the alpha shows the home screen through.
    func widgetBackground(_ argb: UInt32) -> some View {
        containerBackground(for: .widget) { Color(argb: argb) }
    }

    /// shadowColor black, shadowDy 1, shadowRadius 1 (the clock texts).
    func widgetTextShadow() -> some View { shadow(color: .black, radius: 1, x: 0, y: 1) }
}

/// Placeholder text when the app hasn't published anything yet.
struct OpenAppHint: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 13))
            .multilineTextAlignment(.center)
            .foregroundStyle(color)
            .padding(8)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
