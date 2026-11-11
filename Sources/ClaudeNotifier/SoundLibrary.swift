import AppKit
import UniformTypeIdentifiers

struct SoundFile: Identifiable, Hashable {
    let path: String
    var id: String { path }
    var name: String { URL(fileURLWithPath: path).deletingPathExtension().lastPathComponent }
}

/// Lists the sounds you can pick from: your own folder (~/.claude/hooks/sounds)
/// and the built-in macOS sounds. Also plays previews and imports new files.
@MainActor
final class SoundLibrary: ObservableObject {
    @Published private(set) var mySounds: [SoundFile] = []
    @Published private(set) var systemSounds: [SoundFile] = []
    @Published var lastError: String?

    private static let extensions: Set<String> = ["aiff", "aif", "m4a", "mp3", "wav", "caf", "aac", "m4r"]
    private var player: NSSound?

    init() { refresh() }

    func refresh() {
        try? FileManager.default.createDirectory(at: Paths.sounds, withIntermediateDirectories: true)
        mySounds = Self.list(Paths.sounds)
        systemSounds = Self.list(Paths.systemSounds)
    }

    func contains(_ path: String) -> Bool {
        hasDefault(path)
            || mySounds.contains { $0.path == path }
            || systemSounds.contains { $0.path == path }
    }

    /// True if `path` is the default sound of some event and the file exists.
    func hasDefault(_ path: String) -> Bool {
        NotifyEvent.allCases.contains { $0.defaultSound == path }
            && FileManager.default.fileExists(atPath: path)
    }

    /// The sound that will really play for `event`: the chosen one, or the
    /// default if the chosen file is missing. Same rule as notify.sh.
    func playablePath(_ path: String, for event: NotifyEvent) -> String {
        FileManager.default.fileExists(atPath: path) ? path : event.defaultSound
    }

    func play(_ path: String, volume: Double) {
        player?.stop()
        guard let sound = NSSound(contentsOf: URL(fileURLWithPath: path), byReference: true) else {
            lastError = "Could not play \(URL(fileURLWithPath: path).lastPathComponent)"
            return
        }
        sound.volume = Float(volume)
        sound.play()
        player = sound
        lastError = nil
    }

    /// Asks for an audio file, copies it into the sounds folder and returns the new path.
    func importSound() -> String? {
        let panel = NSOpenPanel()
        panel.title = "Choose a notification sound"
        panel.allowedContentTypes = [.audio]
        panel.allowsMultipleSelection = false
        NSApp.activate(ignoringOtherApps: true)
        guard panel.runModal() == .OK, let src = panel.url else { return nil }

        if src.deletingLastPathComponent().standardizedFileURL == Paths.sounds.standardizedFileURL {
            return src.path
        }
        var dest = Paths.sounds.appendingPathComponent(src.lastPathComponent)
        let base = src.deletingPathExtension().lastPathComponent
        var n = 2
        while FileManager.default.fileExists(atPath: dest.path) {
            dest = Paths.sounds.appendingPathComponent("\(base) \(n).\(src.pathExtension)")
            n += 1
        }
        do {
            try FileManager.default.copyItem(at: src, to: dest)
            refresh()
            return dest.path
        } catch {
            lastError = "Could not copy sound: \(error.localizedDescription)"
            return nil
        }
    }

    func openFolder() {
        refresh()
        NSWorkspace.shared.open(Paths.sounds)
    }

    private static func list(_ dir: URL) -> [SoundFile] {
        let files = (try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil)) ?? []
        return files
            .filter { extensions.contains($0.pathExtension.lowercased()) }
            .map { SoundFile(path: $0.path) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
