import AppIntents
import CalculatorKit
import FossifyCommons
import SwiftUI
import WidgetKit

// MyWidgetProvider (calculator-ios CalculatorWidgets): layout/widget.xml on the home screen. Every
// button runs CalculatorKeyIntent in the extension, which drives the widget calculator kept in
// the app group (CalculatorWidgetEngine) and redraws the widget.

struct CalculatorWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Calculator"
    static var description = IntentDescription("Background and text colors of the calculator widget.")

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

/// One key of view_calculator.xml.
struct CalculatorKeyIntent: AppIntent {
    static var title: LocalizedStringResource = "Calculator key"
    static var isDiscoverable = false

    @Parameter(title: "Key")
    var key: String

    init() {}
    init(_ key: String) { self.key = key }

    func perform() async throws -> some IntentResult {
        CalculatorWidgetEngine.press(key)
        return .result()
    }
}

struct CalculatorEntry: TimelineEntry {
    let date: Date
    let display: CalculatorWidgetSnapshot
    let background: UInt32
    let text: UInt32
}

struct CalculatorProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> CalculatorEntry {
        CalculatorEntry(date: Date(), display: CalculatorWidgetSnapshot(formula: "15,937*5", result: "79,685"),
                        background: 0xAA00_0000, text: WidgetTheme.default.primary)
    }

    func snapshot(for configuration: CalculatorWidgetIntent, in context: Context) async -> CalculatorEntry {
        entry(configuration, preview: context.isPreview)
    }

    func timeline(for configuration: CalculatorWidgetIntent, in context: Context) async -> Timeline<CalculatorEntry> {
        Timeline(entries: [entry(configuration, preview: false)], policy: .never)
    }

    private func entry(_ c: CalculatorWidgetIntent, preview: Bool) -> CalculatorEntry {
        CalculatorEntry(date: Date(),
                        display: preview ? CalculatorWidgetSnapshot(formula: "15,937*5", result: "79,685") : CalculatorWidgetEngine.snapshot(),
                        background: WidgetColors.resolve(c.background, hex: c.backgroundHex, opacity: c.opacity, fallback: 0xFF00_0000),
                        text: WidgetColors.resolve(c.text, hex: c.textHex, fallback: WidgetColor.theme.argb))
    }
}

struct CalculatorWidgetView: View {
    let entry: CalculatorEntry

    /// view_calculator.xml rows (btn_reset "AC" visible on the widget).
    private static let rows: [[(String, String)]] = [
        [("percent", "%"), ("power", "^"), ("root", "√"), ("reset", "AC"), ("divide", "÷")],
        [("digit7", "7"), ("digit8", "8"), ("digit9", "9"), ("multiply", "×")],
        [("digit4", "4"), ("digit5", "5"), ("digit6", "6"), ("minus", "-")],
        [("digit1", "1"), ("digit2", "2"), ("digit3", "3"), ("plus", "+")],
        [("digit0", "0"), ("decimal", "."), ("clear", "C"), ("equals", "=")],
    ]

    var body: some View {
        GeometryReader { geo in
            let unit = geo.size.height / (2.1 + 1.8 + 2 * Double(Self.rows.count))
            VStack(spacing: 0) {
                Link(destination: WidgetBridge.url(WidgetApps.calculator)) {
                    VStack(spacing: 0) {
                        display(entry.display.formula, alignment: .bottomTrailing).frame(height: unit * 2.1)
                        display(entry.display.result, alignment: .trailing).frame(height: unit * 1.8)
                    }
                }
                ForEach(Self.rows.indices, id: \.self) { r in
                    HStack(spacing: 0) {
                        ForEach(Self.rows[r], id: \.0) { key in
                            Button(intent: CalculatorKeyIntent(key.0)) {
                                Text(key.0 == "decimal" ? entry.display.decimalSeparator : key.1)
                                    .font(.system(size: 26, weight: .light))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.5)
                                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .padding(4)
                        }
                    }
                    .frame(height: unit * 2)
                }
            }
        }
        .foregroundStyle(Color(argb: entry.text))
        .environment(\.layoutDirection, .leftToRight)
        .overlay(alignment: .top) {
            if let message = entry.display.message {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.black.opacity(0.8)))
                    .padding(8)
            }
        }
        .widgetBackground(entry.background)
    }

    private func display(_ text: String, alignment: Alignment) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .light))
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment)
            .padding(.horizontal, 16)
    }
}

struct CalculatorWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: WidgetKinds.calculator, intent: CalculatorWidgetIntent.self, provider: CalculatorProvider()) { entry in
            CalculatorWidgetView(entry: entry)
        }
        .configurationDisplayName("Calculator")
        .description("A calculator on your home screen.")
        // widget_info.xml: targetCell 4x4, minResize 3x3.
        .supportedFamilies([.systemLarge, .systemExtraLarge])
        .contentMarginsDisabled()
    }
}
