//
// Passbolt - Open source password manager for teams
// Copyright (c) 2021 Passbolt SA
//
// This program is free software: you can redistribute it and/or modify it under the terms of the GNU Affero General
// Public License (AGPL) as published by the Free Software Foundation version 3.
//
// The name "Passbolt" is a registered trademark of Passbolt SA, and Passbolt SA hereby declines to grant a trademark
// license to "Passbolt" pursuant to the GNU Affero General Public License version 3 Section 7(e), without a separate
// agreement with Passbolt SA.
//
// This program is distributed in the hope that it will be useful, but WITHOUT ANY WARRANTY; without even the implied
// warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See GNU Affero General Public License for more details.
//
// You should have received a copy of the GNU Affero General Public License along with this program. If not,
// see GNU Affero General Public License v3 (http://www.gnu.org/licenses/agpl-3.0.html).
//
// @copyright     Copyright (c) Passbolt SA (https://www.passbolt.com)
// @license       https://opensource.org/licenses/AGPL-3.0 AGPL License
// @link          https://www.passbolt.com Passbolt (tm)
// @since         v1.0
//

import Features
import NetworkOperations
import OSFeatures
import Session
import SessionData

import struct Foundation.URL

extension SessionConfigurationLoader {

  @MainActor fileprivate static func load(
    features: Features,
    cancellables: Cancellables
  ) throws -> Self {
    let diagnostics: OSDiagnostics = features.instance()
    let session: Session = try features.instance()
    let configurationFetchNetworkOperation: ConfigurationFetchNetworkOperation = try features.instance()

    let configuration: UpdatableValue<Dictionary<AnyHashable, FeatureConfigItem>> = .init(
      // TODO: we should update only on account changes
      // not on all session changes...
      updatesSequence: session.updatesSequence,
      //        .currentAccountSequence()
      //        .map { _ in Void() },
      update: fetchConfiguration
    )

    @Sendable nonisolated func fetchConfiguration() async throws -> Dictionary<AnyHashable, FeatureConfigItem> {
      diagnostics.log(diagnostic: "Fetching server configuration...")
      guard case .some = try? await session.currentAccount()
      else {
        diagnostics.log(diagnostic: "...server configuration fetching skipped!")
        return .init()
      }
      let rawConfiguration: ConfigurationFetchNetworkOperationResult.Config
      do {
        rawConfiguration = try await configurationFetchNetworkOperation().config
      }
      catch {
        diagnostics.log(error: error)
        diagnostics.log(diagnostic: "...server configuration fetching failed!")
        throw error
      }

      var configuration: Dictionary<AnyHashable, FeatureConfigItem> = .init()

      if let legal: ConfigurationFetchNetworkOperationResult.Legal = rawConfiguration.legal {
        configuration[FeatureFlags.Legal.identifier] = { () -> FeatureFlags.Legal in
          let termsURL: URL? = .init(string: legal.terms.url)
          let privacyPolicyURL: URL? = .init(string: legal.privacyPolicy.url)

          switch (termsURL, privacyPolicyURL) {
          case (.none, .none):
            return .none
          case let (.some(termsURL), .none):
            return .terms(termsURL)
          case let (.none, .some(privacyPolicyURL)):
            return .privacyPolicy(privacyPolicyURL)
          case let (.some(termsURL), .some(privacyPolicyURL)):
            return .both(termsURL: termsURL, privacyPolicyURL: privacyPolicyURL)
          }
        }()
      }
      else {
        configuration[FeatureFlags.Legal.identifier] = FeatureFlags.Legal.default
      }

      if let folders: ConfigurationPlugins.Folders = rawConfiguration.plugins.firstElementOfType(), folders.enabled {
        configuration[FeatureFlags.Folders.identifier] = FeatureFlags.Folders.enabled(
          version: folders.version
        )
      }
      else {
        configuration[FeatureFlags.Folders.identifier] = FeatureFlags.Folders.default
      }

      if let previewPassword: ConfigurationPlugins.PreviewPassword = rawConfiguration.plugins.firstElementOfType() {
        configuration[FeatureFlags.PreviewPassword.identifier] = { () -> FeatureFlags.PreviewPassword in
          if previewPassword.enabled {
            return .enabled
          }
          else {
            return .disabled
          }
        }()
      }
      else {
        configuration[FeatureFlags.PreviewPassword.identifier] = FeatureFlags.PreviewPassword.default
      }

      if let tags: ConfigurationPlugins.Tags = rawConfiguration.plugins.firstElementOfType(), tags.enabled {
        configuration[FeatureFlags.Tags.identifier] = FeatureFlags.Tags.enabled
      }
      else {
        configuration[FeatureFlags.Tags.identifier] = FeatureFlags.Tags.default
      }

      diagnostics.log(diagnostic: "...server configuration fetched!")

      return configuration
    }

    @Sendable nonisolated func fetchIfNeeded() async throws {
      _ = try await configuration.value
    }

    @Sendable nonisolated func configuration(
      _ itemType: FeatureConfigItem.Type
    ) async -> FeatureConfigItem? {
      try? await configuration.value[itemType.identifier]
    }

    return Self(
      fetchIfNeeded: fetchIfNeeded,
      configuration: configuration(_:)
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltSessionConfigurationLoader() {
    self.use(
      .lazyLoaded(
        SessionConfigurationLoader.self,
        load: SessionConfigurationLoader.load(features:cancellables:)
      )
    )
  }
}

extension Array where Element == ConfigurationPlugin {

  fileprivate func firstElementOfType<T>(
    _ ofType: T.Type = T.self
  ) -> T?
  where T: ConfigurationPlugin {
    first { $0 is T } as? T
  }
}
