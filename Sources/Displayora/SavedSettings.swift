import CoreGraphics
import Foundation

struct SavedSettings: Codable, Equatable, Identifiable {
  let id: UUID
  var name: String
  var configuration: SavedDisplayConfiguration

  init(id: UUID = UUID(), name: String, configuration: SavedDisplayConfiguration) {
    self.id = id
    self.name = name
    self.configuration = configuration
  }
}

struct SavedDisplayConfiguration: Codable, Equatable {
  var monitors: [SavedMonitorConfiguration]
  var nightMode: NightMode
}

struct SavedMonitorConfiguration: Codable, Equatable {
  let displayUUID: UUID
  var lastKnownName: String
  var isEnabled: Bool
  var brightnessPercentage: Int
}

protocol SavedSettingsStoring {
  func load() throws -> [SavedSettings]
  func save(_ settings: [SavedSettings]) throws
}

enum SavedSettingsStoreError: LocalizedError, Equatable {
  case unsupportedVersion(Int)
  case malformedData

  var errorDescription: String? {
    switch self {
    case .unsupportedVersion(let version):
      return "Saved settings use unsupported data version \(version)."
    case .malformedData:
      return "Saved settings data is malformed."
    }
  }
}

final class UserDefaultsSavedSettingsStore: SavedSettingsStoring {
  static let key = "displayora.saved-settings.v1"

  private struct Collection: Codable {
    let version: Int
    let settings: [SavedSettings]
  }

  private let defaults: UserDefaults
  private let encoder: JSONEncoder
  private let decoder: JSONDecoder

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    encoder = JSONEncoder()
    decoder = JSONDecoder()
  }

  func load() throws -> [SavedSettings] {
    guard let data = defaults.data(forKey: Self.key) else { return [] }
    let collection: Collection
    do {
      collection = try decoder.decode(Collection.self, from: data)
    } catch {
      throw SavedSettingsStoreError.malformedData
    }
    guard collection.version == 1 else {
      throw SavedSettingsStoreError.unsupportedVersion(collection.version)
    }
    return collection.settings
  }

  func save(_ settings: [SavedSettings]) throws {
    defaults.set(try encoder.encode(Collection(version: 1, settings: settings)), forKey: Self.key)
  }
}

struct SavedSettingsCompatibility: Equatable {
  let missingMonitorNames: [String]
  let additionalMonitorNames: [String]

  var isAvailable: Bool {
    missingMonitorNames.isEmpty && additionalMonitorNames.isEmpty
  }
}
