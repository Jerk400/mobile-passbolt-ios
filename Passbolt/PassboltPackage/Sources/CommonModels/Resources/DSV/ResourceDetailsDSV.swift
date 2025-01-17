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

public struct ResourceDetailsDSV {

  public let id: Resource.ID
  public var permissionType: PermissionTypeDSV
  public var name: String
  public var url: String?
  public var username: String?
  public var description: String?
  public var fields: Array<ResourceFieldDSV>
  public var favoriteID: Resource.FavoriteID?
  public var location: Array<ResourceFolderLocationItemDSV>
  public var permissions: OrderedSet<PermissionDSV>
  public var tags: Array<ResourceTagDSV>

  public init(
    id: Resource.ID,
    permissionType: PermissionTypeDSV,
    name: String,
    url: String?,
    username: String?,
    description: String?,
    fields: Array<ResourceFieldDSV>,
    favoriteID: Resource.FavoriteID?,
    location: Array<ResourceFolderLocationItemDSV>,
    permissions: OrderedSet<PermissionDSV>,
    tags: Array<ResourceTagDSV>
  ) {
    self.id = id
    self.permissionType = permissionType
    self.name = name
    self.url = url
    self.username = username
    self.description = description
    self.fields = fields
    self.favoriteID = favoriteID
    self.location = location
    self.permissions = permissions
    self.tags = tags
  }
}

extension ResourceDetailsDSV: DSV {}

extension ResourceDetailsDSV {

  public var favorite: Bool {
    self.favoriteID != .none
  }
}
