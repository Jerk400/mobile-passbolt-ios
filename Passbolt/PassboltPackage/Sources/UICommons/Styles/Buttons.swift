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

import AegithalosCocoa

extension Mutation where Subject: TextButton {

  public static func primaryStyle() -> Self {
    .combined(
      .backgroundColor(dynamic: .primaryBlue),
      .pressedBackgroundColor(dynamic: .primaryBluePressed),
      .disabledBackgroundColor(dynamic: .primaryBlueDisabled),
      .cornerRadius(4, masksToBounds: true),
      .heightAnchor(.equalTo, constant: 56),
      .textColor(dynamic: .primaryButtonText),
      .pressedTextColor(dynamic: .primaryButtonText),
      .disabledTextColor(dynamic: .primaryButtonText),
      .font(.inter(ofSize: 14, weight: .medium)),
      .textAlignment(.center),
      .textInsets(.init(top: 4, leading: 8, bottom: -4, trailing: -8))
    )
  }

  public static func linkStyle() -> Self {
    .combined(
      .font(.inter(ofSize: 14, weight: .medium)),
      .backgroundColor(.clear),
      .textAlignment(.center),
      .textColor(dynamic: .primaryText),
      .pressedTextColor(dynamic: .primaryText),
      .disabledTextColor(dynamic: .primaryText),
      .textInsets(.init(top: 4, leading: 8, bottom: -4, trailing: -8)),
      .heightAnchor(.equalTo, constant: 56)
    )
  }

  public static func destructiveStyle() -> Self {
    .combined(
      .backgroundColor(dynamic: .secondaryRed),
      .pressedBackgroundColor(dynamic: .secondaryDarkRed),
      .disabledBackgroundColor(dynamic: .secondaryGray),
      .cornerRadius(4, masksToBounds: true),
      .heightAnchor(.equalTo, constant: 56),
      .textColor(dynamic: .primaryButtonText),
      .pressedTextColor(dynamic: .primaryButtonText),
      .disabledTextColor(dynamic: .primaryButtonText),
      .font(.inter(ofSize: 14, weight: .medium)),
      .textAlignment(.center),
      .textInsets(.init(top: 4, leading: 8, bottom: -4, trailing: -8))
    )
  }
}

extension Mutation where Subject: UIBarButtonItem {

  public static func backStyle() -> Self {
    .combined(
      .style(.done),
      .image(named: .arrowLeft, from: .uiCommons)
    )
  }

  public static func placeholderStyle() -> Self {
    .combined(
      .style(.plain),
      .image(named: .navigationBarPlaceholder, from: .uiCommons)
    )
  }

  public static func closeStyle() -> Self {
    .combined(
      .style(.plain),
      .image(named: .close, from: .uiCommons)
    )
  }
}
