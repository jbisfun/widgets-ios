import AppIntents
import FossifyCommons
import Foundation

// Widget button intents that must run in the app process: the app (launcher-ios or the
// FossifyWidgets host) links this module too, so iOS finds them in its Metadata.appintents and
// runs perform() there, where the Kits registered their actions (WidgetBridge.register).

/// MyWidgetProvider's PREVIOUS / PLAYPAUSE / NEXT. An AudioPlaybackIntent runs in the app,
/// which iOS starts in the background if needed, so playback continues without opening it.
public struct MusicControlIntent: AudioPlaybackIntent {
    public static var title: LocalizedStringResource = "Control the music player"
    public static var isDiscoverable = false

    @Parameter(title: "Action")
    public var action: MusicControlAction

    public init() {}

    public init(_ action: MusicControlAction) {
        self.action = action
    }

    @MainActor
    public func perform() async throws -> some IntentResult {
        WidgetBridge.perform("musicplayer.\(action.rawValue)")
        return .result()
    }
}

public enum MusicControlAction: String, AppEnum {
    case previous, toggle, next

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Player action"
    public static var caseDisplayRepresentations: [MusicControlAction: DisplayRepresentation] = [
        .previous: "Previous",
        .toggle: "Play / pause",
        .next: "Next",
    ]
}

/// BackgroundRecordActivity starting a recording. iOS only lets the app start the microphone
/// in the foreground, so this opens it (openAppWhenRun) and starts recording there.
public struct StartRecordingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Start recording"
    public static var isDiscoverable = false
    public static var openAppWhenRun = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        WidgetBridge.perform("voicerecorder.start")
        return .result()
    }
}

/// BackgroundRecordActivity stopping and saving the running recording, in the background
/// (the recording app is already running with its audio session).
public struct StopRecordingIntent: AudioPlaybackIntent {
    public static var title: LocalizedStringResource = "Stop recording"
    public static var isDiscoverable = false

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult {
        WidgetBridge.perform("voicerecorder.stop")
        return .result()
    }
}
