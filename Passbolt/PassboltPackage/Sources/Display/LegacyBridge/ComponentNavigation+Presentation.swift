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

import UIComponents  // LegacyBridge only

extension ComponentNavigation {

  @available(*, deprecated, message: "Please switch to `NavigationTree`")
  @MainActor public func push<DisplayComponent>(
    _ type: DisplayComponent.Type,
    controller: DisplayComponent.Controller,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.push(
      DisplayViewBridge<DisplayComponent>.self,
      in: controller,
      animated: animated
    )
  }

  @available(*, deprecated, message: "Please switch to `NavigationTree`")
  @MainActor public func pop<DisplayComponent>(
    if type: DisplayComponent.Type,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.pop(
      if: DisplayViewBridge<DisplayComponent>.self,
      animated: animated
    )
  }

  @available(*, deprecated, message: "Please switch to `NavigationTree`")
  @MainActor public func present<DisplayComponent>(
    _ type: DisplayComponent.Type,
    controller: DisplayComponent.Controller,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.present(
      DisplayViewBridge<DisplayComponent>.self,
      in: controller,
      animated: animated
    )
  }

  @available(*, deprecated, message: "Please switch to `NavigationTree`")
  @MainActor public func dismiss<DisplayComponent>(
    type: DisplayComponent.Type,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.dismiss(
      DisplayViewBridge<DisplayComponent>.self,
      animated: animated
    )
  }

  @available(*, deprecated, message: "Please switch to `NavigationTree`")
  @MainActor public func presentSheet<DisplayComponent>(
    _ type: DisplayComponent.Type,
    controller: DisplayComponent.Controller,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.presentSheet(
      DisplayViewBridge<DisplayComponent>.self,
      in: controller,
      animated: animated
    )
  }

  @available(*, deprecated, message: "Please switch to `NavigationTree`")
  @MainActor public func dismissSheet<DisplayComponent>(
    _ type: DisplayComponent.Type,
    animated: Bool = true
  ) async where DisplayComponent: ControlledView {
    await self.dismiss(
      SheetViewController<DisplayViewBridge<DisplayComponent>>.self,
      animated: animated
    )
  }

  @available(*, deprecated, message: "Please switch to `NavigationTree`")
  @MainActor public func presentInfoSnackbar(
    _ displayable: DisplayableString,
    with arguments: Array<CVarArg> = .init()
  ) {
    self.present(
      snackbar: Mutation<UICommons.PlainView>
        .snackBarMessage(
          displayable,
          with: arguments,
          backgroundColor: .primaryText,
          textColor: .primaryTextAlternative
        )
        .instantiate(),
      presentationMode: .global
    )
  }
}