//
//  SettingsManager.swift
//  Annota
//
//  Generic settings manager with auto-save and file watching
//

import SwiftUI
import Combine

@MainActor
final class SettingsManager<Settings: Codable & Equatable>: ObservableObject {
    @Published private(set) var current: Settings
    let defaults: Settings
    private let storage: SettingsStorage

    var fileURL: URL { storage.fileURL }

    private var fileWatcher: FileWatcher?
    private var saveTask: Task<Void, Never>?
    private let saveDebounceInterval: Duration = .milliseconds(500)

    init(defaults: Settings, storage: SettingsStorage) {
        self.defaults = defaults
        self.storage = storage
        self.current = defaults

        // Load existing or write defaults
        if let loaded: Settings = try? storage.load(Settings.self) {
            self.current = loaded
        } else {
            self.current = defaults
            try? storage.save(defaults)
        }

        // Setup file watching
        self.fileWatcher = FileWatcher(fileURL: storage.fileURL) { [weak self] in
            Task { @MainActor in
                self?.reloadFromDisk()
            }
        }
        self.fileWatcher?.start()
    }

    // MARK: - Updates

    func update(_ mutation: (inout Settings) -> Void) {
        var newValue = current
        mutation(&newValue)
        guard newValue != current else { return }
        current = newValue
        scheduleSave()
    }

    func set<V>(_ keyPath: WritableKeyPath<Settings, V>, to value: V) {
        var newValue = current
        newValue[keyPath: keyPath] = value
        guard newValue != current else { return }
        current = newValue
        scheduleSave()
    }

    func binding<V>(for keyPath: WritableKeyPath<Settings, V>) -> Binding<V> {
        Binding(
            get: { self.current[keyPath: keyPath] },
            set: { newValue in
                self.set(keyPath, to: newValue)
            }
        )
    }

    // MARK: - Actions

    func resetToDefaults() {
        current = defaults
        scheduleSave()
    }

    func reloadFromDisk() {
        guard let loaded: Settings = try? storage.load(Settings.self) else { return }
        guard loaded != current else { return }
        current = loaded
    }

    func revealInFinder() {
        NSWorkspace.shared.selectFile(storage.fileURL.path, inFileViewerRootedAtPath: "")
    }

    func openInEditor() {
        NSWorkspace.shared.open(storage.fileURL)
    }

    // MARK: - Private

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            guard let self = self else { return }
            try? await Task.sleep(for: self.saveDebounceInterval)
            guard !Task.isCancelled else { return }

            self.fileWatcher?.isSuppressed = true
            try? self.storage.save(self.current)
            // Allow time for the DispatchSource event to fire (and be ignored)
            // before re-enabling the watcher
            try? await Task.sleep(for: .milliseconds(100))
            self.fileWatcher?.isSuppressed = false
        }
    }
}
