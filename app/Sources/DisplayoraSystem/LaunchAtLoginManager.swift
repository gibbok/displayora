import ServiceManagement

public enum LaunchAtLoginStatus: Equatable, Sendable {
  case disabled
  case enabled
  case requiresApproval
  case unavailable
}

public enum LaunchAtLoginError: Error, Equatable, Sendable {
  case operationFailed
}

@MainActor
public protocol LaunchAtLoginManaging: AnyObject {
  func status() -> LaunchAtLoginStatus
  func enable() throws(LaunchAtLoginError)
  func disable() throws(LaunchAtLoginError)
  func openLoginItemsSettings()
}

@MainActor
public final class SystemLaunchAtLoginManager: LaunchAtLoginManaging {
  public init() {}

  public func status() -> LaunchAtLoginStatus {
    switch SMAppService.mainApp.status {
    case .enabled:
      .enabled
    case .requiresApproval:
      .requiresApproval
    case .notRegistered:
      .disabled
    case .notFound:
      .unavailable
    @unknown default:
      .unavailable
    }
  }

  public func enable() throws(LaunchAtLoginError) {
    do {
      try SMAppService.mainApp.register()
    } catch {
      throw .operationFailed
    }
  }

  public func disable() throws(LaunchAtLoginError) {
    do {
      try SMAppService.mainApp.unregister()
    } catch {
      throw .operationFailed
    }
  }

  public func openLoginItemsSettings() {
    SMAppService.openSystemSettingsLoginItems()
  }
}
