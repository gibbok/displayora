import DisplayoraDisplay

public actor CapabilityProbeScheduler {
  private let probes: [any DisplayCapabilityProbing]

  public init(probes: [any DisplayCapabilityProbing]) throws {
    var registered: Set<String> = []
    for probe in probes {
      let key = "\(probe.owner.rawValue)|\(probe.capabilityID.rawValue)|\(probe.mechanism.rawValue)"
      guard registered.insert(key).inserted else { throw CapabilityProbeSchedulerError.duplicateRegistration }
    }
    self.probes = probes
  }

  public func probe(display: DisplayID, generation: UInt64) async -> [DisplayCapability] {
    let endpoint = DisplayProbeEndpoint(id: display, generation: generation)
    var grouped: [DisplayCapabilityID: (hardware: CapabilityProbeResult?, software: CapabilityProbeResult?)] = [:]
    for probe in probes {
      let result = await probe.probe(endpoint)
      var values = grouped[probe.capabilityID] ?? (nil, nil)
      if probe.mechanism == .hardware { values.hardware = result } else { values.software = result }
      grouped[probe.capabilityID] = values
    }
    return grouped.map { DisplayCapability(id: $0.key, availability: CapabilitySelection.resolve(hardware: $0.value.hardware, software: $0.value.software)) }.sorted { $0.id < $1.id }
  }
}

public enum CapabilityProbeSchedulerError: Error, Sendable { case duplicateRegistration }
