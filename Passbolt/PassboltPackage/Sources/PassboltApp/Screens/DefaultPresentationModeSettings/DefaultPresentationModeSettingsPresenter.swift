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
import Display

internal struct DefaultPresentationModeSettingsController {

  internal var displayViewState: DisplayViewState<ViewState>
  internal var selectMode: (HomePresentationMode?) -> Void
}

extension DefaultPresentationModeSettingsController {

  internal struct ViewState: Hashable {

    internal var selectedMode: HomePresentationMode?
    internal var availableModes: OrderedSet<HomePresentationMode>
  }
}

extension DefaultPresentationModeSettingsController: ContextlessDisplayController {

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      displayViewState: .placeholder,
      selectMode: unimplemented()
    )
  }
  #endif
}

extension DefaultPresentationModeSettingsController {

  fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let navigation: DisplayNavigation = try await features.instance()
    let currentAccount: CurrentAccount = try await features.instance()
    let accountPreferences: AccountPreferences = try await features.instance(context: currentAccount.account().localID)
    let homePresentation: HomePresentation = try await features.instance()

    let useLastUsedHomePresentationAsDefault: ValueBinding<Bool> = accountPreferences
      .useLastUsedHomePresentationAsDefault
    let defaultHomePresentation: ValueBinding<HomePresentationMode> = accountPreferences.defaultHomePresentation

    let displayViewState: DisplayViewState<ViewState> = .init(
      initial: .init(
        selectedMode: useLastUsedHomePresentationAsDefault.value
          ? .none
          : defaultHomePresentation.value,
        availableModes: await homePresentation.availableHomePresentationModes()
      )
    )

    nonisolated func selectMode(
      _ mode: HomePresentationMode?
    ) {
      displayViewState.selectedMode = mode
      if let mode: HomePresentationMode = mode {
        useLastUsedHomePresentationAsDefault.set(false)
        defaultHomePresentation.set(mode)
      }
      else {
        useLastUsedHomePresentationAsDefault.set(true)
      }
      Task {
        await navigation.pop(if: DefaultPresentationModeSettingsView.self)
      }
    }

    return Self(
      displayViewState: displayViewState,
      selectMode: selectMode(_:)
    )
  }
}
extension FeatureFactory {

  internal func useLiveDefaultPresentationModeSettingsController() {
    self.use(
      .disposable(
        DefaultPresentationModeSettingsController.self,
        load: DefaultPresentationModeSettingsController.load(features:)
      )
    )
  }
}