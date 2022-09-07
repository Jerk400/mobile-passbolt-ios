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

import Display
import Resources
import SessionData

// MARK: - Interface

internal struct ResourcesListDisplayController {

  internal var viewState: DisplayViewState<ViewState>
  internal var activate: @Sendable () async -> Void
  internal var refresh: () async -> Void
  internal var createResource: (() -> Void)?
  internal var selectResource: (Resource.ID) -> Void
  internal var openResourceMenu: ((Resource.ID) -> Void)?
}

extension ResourcesListDisplayController: DisplayController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

    internal var filter: StateView<ResourcesFilter>
    internal var suggestionFilter: (ResourceListItemDSV) -> Bool
    internal var createResource: (() -> Void)?
    internal var selectResource: (Resource.ID) -> Void
    internal var openResourceMenu: ((Resource.ID) -> Void)?
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Hashable {

    internal var suggested: Array<ResourceListItemDSV>
    internal var resources: Array<ResourceListItemDSV>
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      activate: { unimplemented() },
      refresh: { unimplemented() },
      createResource: { unimplemented() },
      selectResource: { _ in unimplemented() },
      openResourceMenu: { _ in unimplemented() }
    )
  }
  #endif
}

// MARK: - Implementation

extension ResourcesListDisplayController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let sessionData: SessionData = try await features.instance()
    let resources: Resources = try await features.instance()

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        suggested: .init(),
        resources: .init()
      )
    )
    let viewState: DisplayViewState<ViewState> = .init(
      stateSource: state
    )

    context
      .filter
      .sink { (filter: ResourcesFilter) in
        updateDisplayedResources(filter)
      }
      .store(in: viewState.cancellables)

    @Sendable nonisolated func activate() async {
      do {
        try await sessionData
          .updatesSequence
          .forLatest {
            updateDisplayedResources(context.filter.get())
          }
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Resources list updates broken!"
          )
        )
        context.showMessage(.error(error))
      }
    }

    nonisolated func refresh() async {
      do {
        try await sessionData.refreshIfNeeded()
      }
      catch {
        diagnostics.log(
          error: error,
          info: .message(
            "Failed to refresh session data."
          )
        )
        context.showMessage(.error(error))
      }
    }

    @Sendable nonisolated func updateDisplayedResources(
      _ filter: ResourcesFilter
    ) {
      asyncExecutor.schedule(.replace) {
        do {
          try Task.checkCancellation()

          let filteredResources: Array<ResourceListItemDSV> =
            try await resources.filteredResourcesList(filter)

          try Task.checkCancellation()

          viewState.mutate { (viewState: inout ViewState) in
            viewState.suggested = filteredResources.filter(context.suggestionFilter)
            viewState.resources = filteredResources
          }
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to access resources list."
            )
          )
          context.showMessage(.error(error))
        }
      }
    }

    return .init(
      viewState: viewState,
      activate: activate,
      refresh: refresh,
      createResource: context.createResource,
      selectResource: context.selectResource,
      openResourceMenu: context.openResourceMenu
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourcesListDisplayController() {
    self.use(
      .disposable(
        ResourcesListDisplayController.self,
        load: ResourcesListDisplayController.load(features:context:)
      )
    )
  }
}