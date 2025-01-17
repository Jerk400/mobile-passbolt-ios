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

import Features

// MARK: - Interface

public typealias ResourceCreateNetworkOperation =
  NetworkOperation<ResourceCreateNetworkOperationDescription>

public enum ResourceCreateNetworkOperationDescription: NetworkOperationDescription {

  public typealias Input = ResourceCreateNetworkOperationVariable
  public typealias Output = ResourceCreateNetworkOperationResult
}

public struct ResourceCreateNetworkOperationVariable: Encodable {

  public var resourceTypeID: ResourceType.ID
  public var parentFolderID: ResourceFolder.ID?
  public var name: String
  public var username: String?
  public var url: URLString?
  public var description: String?
  public var secrets: Array<Secret>

  public struct Secret: Encodable {

    public var userID: User.ID
    public var data: ArmoredPGPMessage

    public enum CodingKeys: String, CodingKey {

      case userID = "user_id"
      case data = "data"
    }
  }

  public init(
    resourceTypeID: ResourceType.ID,
    parentFolderID: ResourceFolder.ID?,
    name: String,
    username: String?,
    url: URLString?,
    description: String?,
    secrets: OrderedSet<EncryptedMessage>
  ) {
    self.resourceTypeID = resourceTypeID
    self.parentFolderID = parentFolderID
    self.name = name
    self.username = username
    self.url = url
    self.description = description
    self.secrets = secrets.map { Secret(userID: $0.recipient, data: $0.message) }
  }

  public enum CodingKeys: String, CodingKey {

    case name = "name"
    case parentFolderID = "folder_parent_id"
    case description = "description"
    case username = "username"
    case url = "uri"
    case resourceTypeID = "resource_type_id"
    case secrets = "secrets"
  }
}

public struct ResourceCreateNetworkOperationResult: Decodable {

  public var resourceID: Resource.ID
  public var ownerPermissionID: Permission.ID

  public init(
    resourceID: Resource.ID,
    ownerPermissionID: Permission.ID
  ) {
    self.resourceID = resourceID
    self.ownerPermissionID = ownerPermissionID
  }

  public init(
    from decoder: Decoder
  ) throws {
    let container: KeyedDecodingContainer<ResourceCreateNetworkOperationResult.CodingKeys> =
      try decoder.container(keyedBy: CodingKeys.self)

    self.resourceID = try container.decode(Resource.ID.self, forKey: .resourceID)

    let permissionContainer: KeyedDecodingContainer<ResourceCreateNetworkOperationResult.PermissionCodingKeys> =
      try container.nestedContainer(keyedBy: PermissionCodingKeys.self, forKey: .permission)

    self.ownerPermissionID = try permissionContainer.decode(Permission.ID.self, forKey: .permissionID)
  }

  public enum CodingKeys: String, CodingKey {

    case resourceID = "id"
    case permission = "permission"
  }

  public enum PermissionCodingKeys: String, CodingKey {

    case permissionID = "id"
  }
}
