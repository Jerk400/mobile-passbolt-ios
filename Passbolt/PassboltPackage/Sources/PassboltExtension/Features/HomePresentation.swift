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

import Accounts
import CommonModels
import Commons
import Display
import Session
import SessionData

// MARK: - Interface

internal struct HomePresentation {

  internal var currentMode: StateBinding<HomePresentationMode>
  internal var availableModes: @Sendable () -> OrderedSet<HomePresentationMode>
}

extension HomePresentation: LoadableContextlessFeature {

  #if DEBUG
  internal nonisolated static var placeholder: Self {
    .init(
      currentMode: .placeholder,
      availableModes: unimplemented()
    )
  }
  #endif
}

// MARK: - Implementation

extension HomePresentation {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let sessionConfiguration: SessionConfiguration = try await features.instance()
    let session: Session = try await features.instance()
    let accountPreferences: AccountPreferences = try await features.instance(context: session.currentAccount())

    let useLastUsedHomePresentationAsDefault: StateBinding<Bool> = accountPreferences
      .useLastHomePresentationAsDefault
    let defaultHomePresentation: StateBinding<HomePresentationMode> = accountPreferences.defaultHomePresentation

    let foldersConfig: FeatureFlags.Folders = await sessionConfiguration.configuration(for: FeatureFlags.Folders.self)
    let tagsConfig: FeatureFlags.Tags = await sessionConfiguration.configuration(for: FeatureFlags.Tags.self)

    let availablePresentationModes: OrderedSet<HomePresentationMode> = {
      // order is preserved on display
      var availableModes: OrderedSet<HomePresentationMode> = [
        .plainResourcesList,
        .favoriteResourcesList,
        .modifiedResourcesList,
        .sharedResourcesList,
        .ownedResourcesList,
      ]

      switch foldersConfig {
      case .disabled:
        break  // skip

      case .enabled:
        availableModes.append(.foldersExplorer)
      }

      switch tagsConfig {
      case .disabled:
        break  // skip

      case .enabled:
        availableModes.append(.tagsExplorer)
      }

      availableModes.append(.resourceUserGroupsExplorer)

      return availableModes
    }()

    let initialPresentationMode: HomePresentationMode = {
      let defaultMode: HomePresentationMode = accountPreferences
        .defaultHomePresentation
        .get(\.self)

      if availablePresentationModes.contains(defaultMode) {
        return defaultMode
      }
      else {
        return .plainResourcesList
      }
    }()

    let currentModeBinding: StateBinding<HomePresentationMode> = .variable(initial: initialPresentationMode)

    currentModeBinding
      .sink { mode in
        if useLastUsedHomePresentationAsDefault.get() {
          defaultHomePresentation.set(to: mode)
        }  // else NOP
      }
      .store(in: cancellables)

    @Sendable nonisolated func availableModes() -> OrderedSet<HomePresentationMode> {
      availablePresentationModes
    }

    return Self(
      currentMode: currentModeBinding,
      availableModes: availableModes
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltHomePresentation() {
    self.use(
      .lazyLoaded(
        HomePresentation.self,
        load: HomePresentation.load(features:cancellables:)
      )
    )
  }
}