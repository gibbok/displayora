import Foundation

public enum WelcomeCompletionStoreError: Error, Equatable, LocalizedError, Sendable {
  case unreadable
  case unwritable

  public var errorDescription: String? {
    switch self {
    case .unreadable:
      "Displayora couldn’t load your saved welcome choice."
    case .unwritable:
      "Displayora couldn’t save this choice."
    }
  }
}

public protocol WelcomeCompletionStoring: Sendable {
  func isComplete() throws(WelcomeCompletionStoreError) -> Bool
  func markComplete() throws(WelcomeCompletionStoreError)
}

public final class UserDefaultsWelcomeCompletionStore:
  WelcomeCompletionStoring, @unchecked Sendable
{
  public static let key = "onboarding.hasCompletedWelcome.v1"

  private let defaults: UserDefaults

  public init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
  }

  public func isComplete() throws(WelcomeCompletionStoreError) -> Bool {
    let value = defaults.object(forKey: Self.key)
    guard value == nil || value is Bool else {
      throw .unreadable
    }
    return defaults.bool(forKey: Self.key)
  }

  public func markComplete() throws(WelcomeCompletionStoreError) {
    defaults.set(true, forKey: Self.key)
    guard defaults.bool(forKey: Self.key) else {
      throw .unwritable
    }
  }
}
