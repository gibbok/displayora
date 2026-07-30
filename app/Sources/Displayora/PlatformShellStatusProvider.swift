import DisplayoraSystem
import DisplayoraUI

final class PlatformShellStatusProvider: ShellDisplayStatusProviding, @unchecked Sendable {
  private let provider: DisplayPlatformShellStatusProvider

  init(platform: DisplayPlatform) {
    provider = DisplayPlatformShellStatusProvider(reader: platform)
  }

  func statusUpdates() -> AsyncStream<ShellDisplayStatus> {
    AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
      Task {
        let updates = await provider.statusUpdates()
        for await status in updates {
          let shellStatus: ShellDisplayStatus = switch status {
          case .loading: .loading
          case .available: .available
          case .noDisplays: .noDisplays
          case .failed:
            .failed(ShellDisplayStatusFailure(code: "display-platform-unavailable", recoveryMessage: "Try again, or reconnect or wake your display."))
          }
          continuation.yield(shellStatus)
        }
        continuation.finish()
      }
    }
  }

  func retry() async { await provider.retry() }
}
