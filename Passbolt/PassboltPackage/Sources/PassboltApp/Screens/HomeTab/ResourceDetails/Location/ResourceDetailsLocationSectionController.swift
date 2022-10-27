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
import Resources
import UIComponents
import Users

internal struct ResourceDetailsLocationSectionController {

  internal var viewState: ObservableValue<ViewState>
  internal var showResourceLocationDetails: () -> Void
}

extension ResourceDetailsLocationSectionController: ComponentController {

  internal typealias ControlledView = ResourceDetailsLocationSectionView
  internal typealias NavigationContext = Resource.ID

  @MainActor static func instance(
    context: NavigationContext,
    navigation: ComponentNavigation<NavigationContext>,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    unowned let features: FeatureFactory = features
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self)
      .detach()
    let navigation: DisplayNavigation = try await features.instance()
    let resourceDetails: ResourceDetails = try await features.instance(context: context)

    let viewState: ObservableValue<ViewState> = .init(
      initial: .init(
        location:
          try await resourceDetails
          .details()
          .location
          .map(\.folderName)
      )
    )

    nonisolated func showResourceLocationDetails() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigation
            .push(
              ResourceLocationDetailsView.self,
              controller: features.instance(context: context)
            )
        }
        catch {
          error
            .asTheError()
            .asFatalError(message: "Failed to navigate to ResourceLocationDetailsView")
        }
      }
    }

    return Self(
      viewState: viewState,
      showResourceLocationDetails: showResourceLocationDetails
    )
  }
}