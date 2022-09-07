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
import Session
import SessionData
import SharedUIComponents
import Users

internal struct ResourceSearchDisplayController {

  internal var viewState: DisplayViewState<ViewState>
  internal var searchText: StateView<String>
  internal var activate: @Sendable () async -> Void
  internal var showPresentationMenu: () -> Void
  internal var signOut: () -> Void
}

extension ResourceSearchDisplayController: NavigationNodeController {

  internal struct Context: LoadableFeatureContext {
    // feature is disposable, we don't care about ID
    internal let identifier: AnyHashable = IID()

    internal var searchPrompt: DisplayableString
    internal var showMessage: (SnackBarMessage?) -> Void
  }

  internal struct ViewState: Hashable {

    internal var searchPrompt: DisplayableString
    internal var accountAvatar: Data?
    internal var searchText: String
  }

  #if DEBUG
  nonisolated static var placeholder: Self {
    .init(
      viewState: .placeholder,
      searchText: .placeholder,
      activate: { unimplemented() },
      showPresentationMenu: { unimplemented() },
      signOut: { unimplemented() }
    )
  }
  #endif
}

extension ResourceSearchDisplayController {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context: Context
  ) async throws -> Self {
    let diagnostics: Diagnostics = features.instance()
    let navigationTree: NavigationTree = features.instance()
    let asyncExecutor: AsyncExecutor = features.instance(of: AsyncExecutor.self).detach()
    let session: Session = try await features.instance()
    let currentAccount: Account = try await session.currentAccount()
    let accountDetails: AccountDetails = try await features.instance(context: currentAccount)

    let state: StateBinding<ViewState> = .variable(
      initial: .init(
        searchPrompt: context.searchPrompt,
        accountAvatar: .none,
        searchText: ""
      )
    )

    let viewState: DisplayViewState<ViewState> = .init(stateSource: state)

    @Sendable nonisolated func activate() async {
      asyncExecutor.schedule(.reuse) {
        do {
          let avatar: Data? = try await accountDetails.avatarImage()
          state.mutate { state in
            state.accountAvatar = avatar
          }
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to load account avatar image, using placeholder."
            )
          )
        }
      }
    }

    nonisolated func showPresentationMenu() {
      asyncExecutor.schedule(.reuse) {
        do {
          try await navigationTree.present(
            HomePresentationMenuNodeView.self,
            controller: features.instance()
          )
        }
        catch {
          diagnostics.log(
            error: error,
            info: .message(
              "Failed to open home presentation menu."
            )
          )
          context.showMessage(.error(error))
        }
      }
    }

    nonisolated func signOut() {
      asyncExecutor.schedule(.reuse) {
        await session.close(.none)
      }
    }

    return .init(
      viewState: viewState,
      searchText: state.scopeView(\.searchText),
      activate: activate,
      showPresentationMenu: showPresentationMenu,
      signOut: signOut
    )
  }
}

extension FeatureFactory {

  @MainActor public func usePassboltResourceSearchDisplayController() {
    self.use(
      .disposable(
        ResourceSearchDisplayController.self,
        load: ResourceSearchDisplayController.load(features:context:)
      )
    )
  }
}