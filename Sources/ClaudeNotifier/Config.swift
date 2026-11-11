import Foundation

/// Locations shared with the hook script (hooks/notify.sh).
enum Paths {
    static let hooks = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/hooks", isDirectory: true)
    static let config = hooks.appendingPathComponent("notify.json")
    static let sounds = hooks.appendingPathComponent("sounds", isDirectory: true)
    static let systemSounds = URL(fileURLWithPath: "/System/Library/Sounds", isDirectory: true)
}

/// The events the hook script reports. The raw value is the second
/// argument passed to notify.sh in ~/.claude/settings.json.
enum NotifyEvent: String, CaseIterable, Identifiable {
    case input
    case done

    var id: String { rawValue }

    var title: String {
        switch self {
        case .input: return "Needs input"
        case .done: return "Response done"
        }
    }

    var detail: String {
        switch self {
        case .input: return "Permission prompts and questions"
        case .done: return "Claude finished its answer"
        }
    }

    /// The sound shipped with the app for this event, installed by scripts/install.sh.
    /// notify.sh uses the same path when the chosen sound is missing.
    var defaultSound: String {
        Paths.sounds.appendingPathComponent("\(rawValue)/Default.m4a").path
    }
}

struct EventConfig: Codable, Equatable {
    var enabled: Bool
    var sound: String

    init(enabled: Bool = true, sound: String = "") {
        self.enabled = enabled
        self.sound = sound
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
        sound = try c.decodeIfPresent(String.self, forKey: .sound) ?? ""
    }
}

/// Mirrors ~/.claude/hooks/notify.json. Missing keys fall back to defaults,
/// so a hand-edited or older file still loads.
struct NotifierConfig: Codable, Equatable {
    var enabled = true
    var soundEnabled = true
    var bannerEnabled = true
    var soundWhenWatching = false
    var volume: Double = 0.3
    var events: [String: EventConfig] = Dictionary(
        uniqueKeysWithValues: NotifyEvent.allCases.map { ($0.rawValue, EventConfig(sound: $0.defaultSound)) }
    )

    init() {}

    init(from decoder: Decoder) throws {
        let d = NotifierConfig()
        let c = try decoder.container(keyedBy: CodingKeys.self)
        enabled = try c.decodeIfPresent(Bool.self, forKey: .enabled) ?? d.enabled
        soundEnabled = try c.decodeIfPresent(Bool.self, forKey: .soundEnabled) ?? d.soundEnabled
        bannerEnabled = try c.decodeIfPresent(Bool.self, forKey: .bannerEnabled) ?? d.bannerEnabled
        soundWhenWatching = try c.decodeIfPresent(Bool.self, forKey: .soundWhenWatching) ?? d.soundWhenWatching
        volume = try c.decodeIfPresent(Double.self, forKey: .volume) ?? d.volume
        let loaded = try c.decodeIfPresent([String: EventConfig].self, forKey: .events) ?? [:]
        events = d.events.merging(loaded) { _, new in new }
    }

    subscript(event: NotifyEvent) -> EventConfig {
        get { events[event.rawValue] ?? EventConfig(sound: event.defaultSound) }
        set { events[event.rawValue] = newValue }
    }
}

/// Loads and saves notify.json. Every change to `config` is written to disk
/// right away, so the hook picks it up on its next run.
@MainActor
final class ConfigStore: ObservableObject {
    @Published var config = NotifierConfig() {
        didSet { if !isLoading && config != oldValue { save() } }
    }
    @Published private(set) var lastError: String?

    private var isLoading = false

    init() {
        reload()
        if !FileManager.default.fileExists(atPath: Paths.config.path) { save() }
    }

    /// Re-reads the file, in case it was edited by hand.
    func reload() {
        guard let data = try? Data(contentsOf: Paths.config) else { return }
        do {
            let loaded = try JSONDecoder().decode(NotifierConfig.self, from: data)
            isLoading = true
            config = loaded
            isLoading = false
            lastError = nil
        } catch {
            lastError = "Could not read notify.json: \(error.localizedDescription)"
        }
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: Paths.hooks, withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
            try encoder.encode(config).write(to: Paths.config, options: .atomic)
            lastError = nil
        } catch {
            lastError = "Could not save notify.json: \(error.localizedDescription)"
        }
    }
}
