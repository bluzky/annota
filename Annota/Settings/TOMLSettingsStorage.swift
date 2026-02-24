//
//  TOMLSettingsStorage.swift
//  Annota
//
//  TOML-based settings storage implementation
//

import Foundation
import TOML

final class TOMLSettingsStorage: SettingsStorage {
    let fileURL: URL

    private let encoder: TOMLEncoder
    private let decoder: TOMLDecoder

    init(fileURL: URL) {
        self.fileURL = fileURL

        self.encoder = TOMLEncoder()
        self.encoder.outputFormatting = .sortedKeys

        self.decoder = TOMLDecoder()
    }

    convenience init(appName: String) {
        let appSupportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        let appDirectory = appSupportURL.appendingPathComponent(appName, isDirectory: true)
        let settingsURL = appDirectory.appendingPathComponent("settings.toml")
        self.init(fileURL: settingsURL)
    }

    func load<T: Decodable>(_ type: T.Type) throws -> T? {
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }
        let data = try Data(contentsOf: fileURL)
        let tomlString = String(data: data, encoding: .utf8) ?? ""
        guard !tomlString.isEmpty else { return nil }
        return try decoder.decode(type, from: tomlString)
    }

    func save<T: Encodable>(_ value: T) throws {
        // Ensure directory exists
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        // Encode to TOML - TOMLEncoder returns Data
        let data = try encoder.encode(value)

        // Atomic write: write to temp file, then swap
        let tempURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: tempURL)

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: tempURL)
        } else {
            try FileManager.default.moveItem(at: tempURL, to: fileURL)
        }
    }

    func reset() throws {
        if FileManager.default.fileExists(atPath: fileURL.path) {
            try FileManager.default.removeItem(at: fileURL)
        }
    }
}
