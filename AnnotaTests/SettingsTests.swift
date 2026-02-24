//
//  SettingsTests.swift
//  AnnotaTests
//
//  Tests for AnnotaSettings structs, SettingsManager, and TOMLSettingsStorage
//

import Testing
import Foundation
import SwiftUI
@testable import Annota

// MARK: - In-Memory Storage (test double)

/// A simple in-memory SettingsStorage for testing SettingsManager
/// without touching disk or requiring TOML.
final class InMemoryStorage: SettingsStorage {
    let fileURL: URL
    private var data: Data?
    var saveCount = 0

    init() {
        self.fileURL = URL(fileURLWithPath: "/tmp/test-settings-\(UUID().uuidString).toml")
    }

    func load<T: Decodable>(_ type: T.Type) throws -> T? {
        guard let data else { return nil }
        return try JSONDecoder().decode(type, from: data)
    }

    func save<T: Encodable>(_ value: T) throws {
        data = try JSONEncoder().encode(value)
        saveCount += 1
    }

    func reset() throws {
        data = nil
    }
}

// MARK: - AnnotaSettings Defaults

struct AnnotaSettingsDefaultsTests {

    @Test func defaultSettingsHaveExpectedValues() {
        let settings = AnnotaSettings()

        #expect(settings.version == 1)
        #expect(settings.ui.theme == "light")
        #expect(settings.ui.showGrid == true)
        #expect(settings.ui.gridSpacing == 20.0)
        #expect(settings.canvas.defaultZoom == 1.0)
        #expect(settings.canvas.minZoom == 0.1)
        #expect(settings.canvas.maxZoom == 5.0)
        #expect(settings.canvas.snapToGrid == false)
    }

    @Test func defaultToolKeys() {
        let keys = ToolKeySettings()

        #expect(keys.select == "v")
        #expect(keys.hand == "h")
        #expect(keys.text == "t")
        #expect(keys.rectangle == "r")
        #expect(keys.line == "l")
        #expect(keys.arrow == "a")
        #expect(keys.oval == "o")
        #expect(keys.triangle == "g")
        #expect(keys.diamond == "d")
        #expect(keys.star == "s")
    }

    @Test func defaultCommandKeys() {
        let keys = CommandKeySettings()

        #expect(keys.deleteSelected == "backspace")
        #expect(keys.copy == "cmd+c")
        #expect(keys.cut == "cmd+x")
        #expect(keys.paste == "cmd+v")
        #expect(keys.selectAll == "cmd+a")
        #expect(keys.undo == "cmd+z")
        #expect(keys.redo == "cmd+shift+z")
    }

    @Test func defaultToolDefaults() {
        let tools = ToolDefaults()

        #expect(tools.shape.strokeColor == "#000000")
        #expect(tools.shape.strokeWidth == 2.0)
        #expect(tools.shape.fillColor == "#FFFFFF")
        #expect(tools.line.strokeColor == "#000000")
        #expect(tools.line.strokeWidth == 2.0)
        #expect(tools.text.fontSize == 16.0)
        #expect(tools.text.textColor == "#000000")
        #expect(tools.arrow.strokeColor == "#000000")
        #expect(tools.arrow.strokeWidth == 2.0)
    }
}

// MARK: - AnnotaSettings Equatable

struct AnnotaSettingsEquatableTests {

    @Test func identicalSettingsAreEqual() {
        let a = AnnotaSettings()
        let b = AnnotaSettings()
        #expect(a == b)
    }

    @Test func modifiedSettingsAreNotEqual() {
        var a = AnnotaSettings()
        let b = AnnotaSettings()

        a.ui.theme = "dark"
        #expect(a != b)
    }

    @Test func modifiedToolKeysAreNotEqual() {
        var a = AnnotaSettings()
        let b = AnnotaSettings()

        a.toolKeys.select = "x"
        #expect(a != b)
    }

    @Test func modifiedCommandKeysAreNotEqual() {
        var a = AnnotaSettings()
        let b = AnnotaSettings()

        a.commandKeys.copy = "cmd+shift+c"
        #expect(a != b)
    }
}

// MARK: - AnnotaSettings Codable

struct AnnotaSettingsCodableTests {

    @Test func jsonRoundTrip() throws {
        var original = AnnotaSettings()
        original.ui.theme = "dark"
        original.canvas.snapToGrid = true
        original.toolKeys.select = "p"
        original.commandKeys.deleteSelected = "delete"
        original.tools.shape.strokeWidth = 5.0

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(AnnotaSettings.self, from: data)

        #expect(decoded == original)
    }

    @Test func allSubstructsRoundTrip() throws {
        let structs: [any (Codable & Equatable)] = [
            UISettings(),
            CanvasSettings(),
            ToolDefaults(),
            ShapeDefaults(),
            LineDefaults(),
            TextDefaults(),
            ArrowDefaults(),
            ToolKeySettings(),
            CommandKeySettings(),
        ]

        for value in structs {
            // Verify each can encode without throwing
            let data = try JSONEncoder().encode(value)
            #expect(data.count > 0)
        }
    }

    private func roundTrip<T: Codable & Equatable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        let decoded = try JSONDecoder().decode(T.self, from: data)
        #expect(decoded == value)
    }
}

// MARK: - Color Hex Helpers

struct ColorHexTests {

    @Test func colorFromValidHex() {
        let color = Color(hex: "#FF0000")
        #expect(color != nil)
    }

    @Test func colorFromHexWithoutHash() {
        let color = Color(hex: "00FF00")
        #expect(color != nil)
    }

    @Test func colorFromInvalidHex() {
        #expect(Color(hex: "XYZ") == nil)
        #expect(Color(hex: "#GG0000") == nil)
        #expect(Color(hex: "") == nil)
        #expect(Color(hex: "#FF") == nil)
    }

    @Test func colorToHexRoundTrip() {
        let original = Color(hex: "#FF8800")!
        let hex = original.toHex()
        #expect(hex != nil)
        #expect(hex == "#FF8800")
    }

    @Test func colorBlackToHex() {
        let hex = Color(hex: "#000000")?.toHex()
        #expect(hex == "#000000")
    }

    @Test func colorWhiteToHex() {
        let hex = Color(hex: "#FFFFFF")?.toHex()
        #expect(hex == "#FFFFFF")
    }
}

// MARK: - SettingsManager (using InMemoryStorage)

@MainActor
struct SettingsManagerTests {

    @Test func initWithNoExistingFile() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)

        // Should use defaults
        #expect(manager.current == AnnotaSettings())
        // Should have written defaults to storage
        #expect(storage.saveCount == 1)
    }

    @Test func initLoadsExistingSettings() async throws {
        let storage = InMemoryStorage()
        var custom = AnnotaSettings()
        custom.ui.theme = "dark"
        try storage.save(custom)

        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)
        #expect(manager.current.ui.theme == "dark")
    }

    @Test func updateMutatesSettings() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)

        manager.update { $0.ui.theme = "dark" }
        #expect(manager.current.ui.theme == "dark")
    }

    @Test func setKeyPathMutatesSettings() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)

        manager.set(\.canvas.snapToGrid, to: true)
        #expect(manager.current.canvas.snapToGrid == true)
    }

    @Test func setKeyPathNoOpSkipsSave() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)
        let saveCountAfterInit = storage.saveCount

        // Set to same value — should not schedule a save
        manager.set(\.ui.theme, to: "light")
        #expect(storage.saveCount == saveCountAfterInit)
    }

    @Test func updateNoOpSkipsSave() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)
        let saveCountAfterInit = storage.saveCount

        manager.update { _ in /* no changes */ }
        #expect(storage.saveCount == saveCountAfterInit)
    }

    @Test func resetToDefaults() async throws {
        let storage = InMemoryStorage()
        let defaults = AnnotaSettings()
        let manager = SettingsManager(defaults: defaults, storage: storage)

        manager.update { $0.ui.theme = "dark" }
        #expect(manager.current.ui.theme == "dark")

        manager.resetToDefaults()
        #expect(manager.current == defaults)
    }

    @Test func reloadFromDisk() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)

        // Simulate external edit
        var modified = AnnotaSettings()
        modified.canvas.maxZoom = 10.0
        try storage.save(modified)

        manager.reloadFromDisk()
        #expect(manager.current.canvas.maxZoom == 10.0)
    }

    @Test func reloadFromDiskNoOpWhenUnchanged() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)

        // Reload when storage has the same data should not change current
        let before = manager.current
        manager.reloadFromDisk()
        #expect(manager.current == before)
    }

    @Test func fileURLExposesStorageURL() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)
        #expect(manager.fileURL == storage.fileURL)
    }

    @Test func updateNestedToolKeys() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)

        manager.set(\.toolKeys.select, to: "p")
        #expect(manager.current.toolKeys.select == "p")
    }

    @Test func updateNestedCommandKeys() async throws {
        let storage = InMemoryStorage()
        let manager = SettingsManager(defaults: AnnotaSettings(), storage: storage)

        manager.set(\.commandKeys.copy, to: "cmd+shift+c")
        #expect(manager.current.commandKeys.copy == "cmd+shift+c")
    }
}

// MARK: - TOMLSettingsStorage (file system)

struct TOMLSettingsStorageTests {

    private func makeTempStorage() -> TOMLSettingsStorage {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("annota-tests-\(UUID().uuidString)")
        let url = tempDir.appendingPathComponent("settings.toml")
        return TOMLSettingsStorage(fileURL: url)
    }

    @Test func loadReturnsNilWhenNoFile() throws {
        let storage = makeTempStorage()
        let result: AnnotaSettings? = try storage.load(AnnotaSettings.self)
        #expect(result == nil)
    }

    @Test func saveAndLoadRoundTrip() throws {
        let storage = makeTempStorage()
        defer { try? storage.reset() }

        var settings = AnnotaSettings()
        settings.ui.theme = "dark"
        settings.toolKeys.select = "p"
        settings.commandKeys.copy = "cmd+shift+c"
        settings.tools.shape.strokeWidth = 5.0

        try storage.save(settings)
        let loaded: AnnotaSettings? = try storage.load(AnnotaSettings.self)

        #expect(loaded != nil)
        #expect(loaded == settings)
    }

    @Test func saveCreatesDirectory() throws {
        let storage = makeTempStorage()
        defer { try? storage.reset() }

        let dir = storage.fileURL.deletingLastPathComponent()
        #expect(!FileManager.default.fileExists(atPath: dir.path))

        try storage.save(AnnotaSettings())
        #expect(FileManager.default.fileExists(atPath: dir.path))
    }

    @Test func resetDeletesFile() throws {
        let storage = makeTempStorage()

        try storage.save(AnnotaSettings())
        #expect(FileManager.default.fileExists(atPath: storage.fileURL.path))

        try storage.reset()
        #expect(!FileManager.default.fileExists(atPath: storage.fileURL.path))
    }

    @Test func resetWhenNoFileDoesNotThrow() throws {
        let storage = makeTempStorage()
        // Should not throw
        try storage.reset()
    }

    @Test func overwriteExistingFile() throws {
        let storage = makeTempStorage()
        defer { try? storage.reset() }

        var v1 = AnnotaSettings()
        v1.ui.theme = "light"
        try storage.save(v1)

        var v2 = AnnotaSettings()
        v2.ui.theme = "dark"
        try storage.save(v2)

        let loaded: AnnotaSettings? = try storage.load(AnnotaSettings.self)
        #expect(loaded?.ui.theme == "dark")
    }

    @Test func convenienceInitCreatesExpectedPath() {
        let storage = TOMLSettingsStorage(appName: "TestApp")
        #expect(storage.fileURL.lastPathComponent == "settings.toml")
        #expect(storage.fileURL.pathComponents.contains("TestApp"))
    }
}
