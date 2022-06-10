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

import CommonModels
import UICommons

internal struct UserGroupMembersListRowView: View {

  private let item: UserGroupMembersListRowItem
  private let action: () async -> Void

  internal init(
    _ item: UserGroupMembersListRowItem,
    action: @escaping () async -> Void
  ) {
    self.item = item
    self.action = action
  }

  internal var body: some View {
    ListRowView(
      action: {
        await self.action()
      },
      chevronVisible: true,
      leftAccessory: {
        UserAvatarView(imageData: self.item.avatarImageData)
      },
      title: "\(self.item.userDetails.firstName) \(self.item.userDetails.lastName)",
      subtitle: "\(self.item.userDetails.username)"
    )
  }
}

#if DEBUG

internal struct UserGroupMembersListRowView_Previews: PreviewProvider {

  internal static var previews: some View {
    UserGroupMembersListRowView(
      .init(
        userDetails: .init(
          id: User.ID
            .randomGenerator()
            .next(),
          username: Generator<String>
            .randomEmail()
            .next(),
          firstName: Generator<String>
            .randomFirstName()
            .next(),
          lastName: Generator<String>
            .randomLastName()
            .next(),
          fingerprint:
            Fingerprint
            .randomGenerator()
            .next(),
          avatarImageURL:
            URLString
            .randomGenerator()
            .next()
        ),
        avatarImageData: Generator<Data?>
          .randomAvatarImage()
          .next
      ),
      action: {}
    )
  }
}
#endif