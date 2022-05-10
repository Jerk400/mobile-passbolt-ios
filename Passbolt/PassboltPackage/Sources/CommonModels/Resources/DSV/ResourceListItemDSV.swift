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

import Commons

public struct ResourceListItemDSV {

  public let id: Resource.ID
  public var parentFolderID: ResourceFolder.ID?
  public var name: String
  public var username: String?
  public var url: String?

  public init(
    id: Resource.ID,
    parentFolderID: ResourceFolder.ID?,
    name: String,
    username: String?,
    url: String?
  ) {
    self.id = id
    self.parentFolderID = parentFolderID
    self.name = name
    self.username = username
    self.url = url
  }
}

extension ResourceListItemDSV: DSV {}

extension ResourceListItemDSV: Hashable {}

#if DEBUG

extension ResourceListItemDSV: RandomlyGenerated {

  public static func randomGenerator(
    using randomnessGenerator: RandomnessGenerator
  ) -> Generator<Self> {
    zip(
      with: ResourceListItemDSV.init(id:parentFolderID:name:username:url:),
      Resource.ID
        .randomGenerator(using: randomnessGenerator),
      ResourceFolder.ID
        .randomGenerator(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Generator<String>
        .randomResourceName(using: randomnessGenerator),
      Generator<String>
        .randomEmail(using: randomnessGenerator)
        .optional(using: randomnessGenerator),
      Generator<String>
        .randomURL(using: randomnessGenerator)
        .optional(using: randomnessGenerator)
    )
  }
}
#endif