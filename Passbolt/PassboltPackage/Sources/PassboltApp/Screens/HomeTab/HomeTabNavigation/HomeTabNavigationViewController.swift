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
import UICommons
import UIComponents

internal final class HomeTabNavigationViewController: NavigationViewController, UIComponent {

  internal typealias Controller = HomeTabNavigationController

  internal static func instance(
    using controller: Controller,
    with components: UIComponentFactory
  ) -> Self {
    Self(
      using: controller,
      with: components
    )
  }

  internal let components: UIComponentFactory
  private let controller: Controller

  internal init(
    using controller: Controller,
    with components: UIComponentFactory
  ) {
    self.controller = controller
    self.components = components
    super.init()
  }

  internal func setup() {
    mut(navigationBarView) {
      .primaryNavigationStyle()
    }
    mut(tabBarItem) {
      .combined(
        .title(.localized(key: "tab.home")),
        .image(named: .homeTab, from: .uiCommons)
      )
    }

    setupSubscriptions()
  }

  private func setupSubscriptions() {
    self.controller
      .currentHomePresentationModePublisher()
      .receive(on: RunLoop.main)
      .sink { [weak self] mode in
        guard let self = self else { return }
        switch mode {
        case .plainResourcesList:
          self.setViewControllers(
            [
              self.components
                .instance(of: PlainResourcesListViewController.self)
            ],
            animated: false
          )

        case .favoriteResourcesList:
          self.setViewControllers(
            [
              self.components
                .instance(of: FavoriteResourcesListViewController.self)
            ],
            animated: false
          )
        }
      }
      .store(in: cancellables)
  }
}
