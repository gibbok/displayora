import DisplayoraUI
import Foundation

struct HostSnapshot: Codable, Equatable {
  let features: [String]
  let controls: [String]
  let settings: [String]
  let capabilities: [String]
  let commands: [String]
}

@MainActor
func makeHostSnapshot(from snapshot: FeatureRegistrySnapshot) -> HostSnapshot {
  HostSnapshot(
    features: snapshot.features.map(\.rawValue),
    controls: snapshot.controls.map(\.id.rawValue),
    settings: snapshot.settings.map(\.id.rawValue),
    capabilities: snapshot.capabilities.map(\.id.rawValue),
    commands: snapshot.commands.map(\.id.rawValue)
  )
}

func encodeHostSnapshot(_ snapshot: HostSnapshot) throws -> Data {
  let encoder = JSONEncoder()
  encoder.outputFormatting = [.sortedKeys]
  return try encoder.encode(snapshot)
}
