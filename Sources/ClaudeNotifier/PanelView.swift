import SwiftUI

/// The settings panel shown when you right-click the menu bar icon.
struct PanelView: View {
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var library: SoundLibrary
    @EnvironmentObject var loginItem: LoginItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: store.config.enabled ? "bell.fill" : "bell.slash")
                    .foregroundStyle(store.config.enabled ? Color.accentColor : .secondary)
                Text("Claude notifications").font(.headline)
                Spacer()
                Toggle("Enabled", isOn: $store.config.enabled)
                    .toggleStyle(.switch)
                    .labelsHidden()
            }

            Divider()

            VStack(alignment: .leading, spacing: 14) {
                ForEach(NotifyEvent.allCases) { event in
                    EventRow(event: event)
                }

                Divider()

                Toggle("Play sound", isOn: $store.config.soundEnabled)
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $store.config.volume, in: 0...1)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                    Text("\(Int((store.config.volume * 100).rounded()))%")
                        .monospacedDigit()
                        .frame(width: 38, alignment: .trailing)
                }
                .disabled(!store.config.soundEnabled)

                Toggle("Show banner", isOn: $store.config.bannerEnabled)
                Toggle("Play sound even when I'm looking at the tab", isOn: $store.config.soundWhenWatching)
                    .disabled(!store.config.soundEnabled)
            }
            .disabled(!store.config.enabled)
            .opacity(store.config.enabled ? 1 : 0.5)

            Divider()

            Toggle("Open at login", isOn: Binding(
                get: { loginItem.isEnabled },
                set: { loginItem.set($0) }
            ))

            ForEach([store.lastError, library.lastError, loginItem.lastError].compactMap { $0 }, id: \.self) {
                Text($0).font(.caption).foregroundStyle(.red)
            }

            HStack {
                Button("Open sounds folder") { library.openFolder() }
                Spacer()
                Button("Quit") { NSApp.terminate(nil) }
            }
            .controlSize(.small)

            Text("Left-click the menu bar icon to turn everything on or off.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .frame(width: 340)
    }
}

/// One event: on/off switch, the chosen sound, preview and import buttons.
struct EventRow: View {
    let event: NotifyEvent
    @EnvironmentObject var store: ConfigStore
    @EnvironmentObject var library: SoundLibrary

    private var config: Binding<EventConfig> {
        Binding(get: { store.config[event] }, set: { store.config[event] = $0 })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: config.enabled) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(event.title)
                    Text(event.detail).font(.caption).foregroundStyle(.secondary)
                }
            }

            HStack(spacing: 6) {
                Picker("Sound", selection: config.sound) {
                    if !library.contains(config.wrappedValue.sound) {
                        Text(missingLabel).tag(config.wrappedValue.sound)
                    }
                    if library.hasDefault(event.defaultSound) {
                        Text("Default").tag(event.defaultSound)
                    }
                    Section("My sounds") {
                        ForEach(library.mySounds) { Text($0.name).tag($0.path) }
                    }
                    Section("macOS") {
                        ForEach(library.systemSounds) { Text($0.name).tag($0.path) }
                    }
                }
                .labelsHidden()

                Button {
                    library.play(library.playablePath(config.wrappedValue.sound, for: event),
                                 volume: store.config.volume)
                } label: {
                    Image(systemName: "play.fill")
                }
                .help("Play this sound")

                Button {
                    if let path = library.importSound() { config.wrappedValue.sound = path }
                } label: {
                    Image(systemName: "plus")
                }
                .help("Add a sound file to your sounds folder")
            }
            .disabled(!config.wrappedValue.enabled)
        }
    }

    private var missingLabel: String {
        let sound = config.wrappedValue.sound
        let name = sound.isEmpty
            ? "No sound chosen"
            : "\(URL(fileURLWithPath: sound).deletingPathExtension().lastPathComponent) (missing)"
        return library.hasDefault(event.defaultSound) ? "\(name), plays Default" : name
    }
}
