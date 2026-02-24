//
//  SettingsStorage.swift
//  Annota
//
//  Settings storage backend protocol
//

import Foundation

protocol SettingsStorage {
    func load<T: Decodable>(_ type: T.Type) throws -> T?
    func save<T: Encodable>(_ value: T) throws
    var fileURL: URL { get }
    func reset() throws
}
