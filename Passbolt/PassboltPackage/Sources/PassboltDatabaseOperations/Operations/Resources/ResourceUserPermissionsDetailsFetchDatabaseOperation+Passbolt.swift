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

import DatabaseOperations
import Session

// MARK: - Implementation

extension ResourceUserPermissionsDetailsFetchDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: Resource.ID,
      connection: SQLiteConnection
    ) throws -> Array<UserPermissionDetailsDSV> {
      let statement: SQLiteStatement =
        .statement(
          """
          SELECT
            users.id AS id,
            users.username AS username,
            users.firstName AS firstName,
            users.lastName AS lastName,
            users.publicPGPKeyFingerprint AS fingerprint,
            users.avatarImageURL AS avatarImageURL,
            usersResources.permissionType AS permissionType
          FROM
            usersResources
          INNER JOIN
            users
          ON
            users.id == usersResources.userID
          WHERE
            usersResources.resourceID == ?1
          ;
          """,
          arguments: input
        )

      return
        try connection
        .fetch(using: statement) { dataRow -> UserPermissionDetailsDSV in
          guard
            let id: User.ID = dataRow.id.flatMap(User.ID.init(rawValue:)),
            let username: String = dataRow.username,
            let firstName: String = dataRow.firstName,
            let lastName: String = dataRow.lastName,
            let fingerprint: Fingerprint = dataRow.fingerprint.flatMap(Fingerprint.init(rawValue:)),
            let avatarImageURL: URLString = dataRow.avatarImageURL.flatMap(URLString.init(rawValue:)),
            let permissionType: PermissionTypeDSV = dataRow.permissionType.flatMap(PermissionTypeDSV.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceUserGroupListItemDSV.self)
              )
          }

          return UserPermissionDetailsDSV(
            id: id,
            username: username,
            firstName: firstName,
            lastName: lastName,
            fingerprint: fingerprint,
            avatarImageURL: avatarImageURL,
            permissionType: permissionType
          )
        }
    }

    nonisolated func executeAsync(
      _ input: Resource.ID
    ) async throws -> Array<UserPermissionDetailsDSV> {
      try await execute(
        input,
        connection: sessionDatabase.connection()
      )
    }

    return Self(
      execute: executeAsync(_:)
    )
  }
}

extension FeatureFactory {

  internal func usePassboltResourceUserPermissionsDetailsFetchDatabaseOperation() {
    self.use(
      .disposable(
        ResourceUserPermissionsDetailsFetchDatabaseOperation.self,
        load: ResourceUserPermissionsDetailsFetchDatabaseOperation
          .load(features:)
      )
    )
  }
}