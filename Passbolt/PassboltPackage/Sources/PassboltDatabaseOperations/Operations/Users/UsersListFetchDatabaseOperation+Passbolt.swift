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

extension UsersListFetchDatabaseOperation {

  @MainActor fileprivate static func load(
    features: FeatureFactory
  ) async throws -> Self {
    unowned let features: FeatureFactory = features

    let sessionDatabase: SessionDatabase = try await features.instance()

    nonisolated func execute(
      _ input: UsersDatabaseFilter,
      connection: SQLiteConnection
    ) throws -> Array<UserDetailsDSV> {
      var statement: SQLiteStatement =
        .statement(
          """
          SELECT
            users.id AS id,
            users.username AS username,
            users.firstName AS firstName,
            users.lastName AS lastName,
            users.publicPGPKeyFingerprint AS fingerprint,
            users.avatarImageURL AS avatarImageURL
          FROM
            users
          WHERE
            1 -- equivalent of true, used to simplify dynamic query building
          """
        )

      if !input.text.isEmpty {
        statement
          .append(
            """
            AND
            (
               users.username LIKE '%' || ? || '%'
            OR users.firstName LIKE '%' || ? || '%'
            OR users.lastName LIKE '%' || ? || '%'
            )

            """
          )
        // adding multiple times since we can't count args when using dynamic query
        // and argument has to be used multiple times
        statement.appendArgument(input.text)
        statement.appendArgument(input.text)
        statement.appendArgument(input.text)
      }
      else { /* NOP */
      }

      statement.append(";")

      return
        try connection
        .fetch(using: statement) { dataRow -> UserDetailsDSV in
          guard
            let id: User.ID = dataRow.id.flatMap(User.ID.init(rawValue:)),
            let username: String = dataRow.username,
            let firstName: String = dataRow.firstName,
            let lastName: String = dataRow.lastName,
            let fingerprint: Fingerprint = dataRow.fingerprint.flatMap(Fingerprint.init(rawValue:)),
            let avatarImageURL: URLString = dataRow.avatarImageURL.flatMap(URLString.init(rawValue:))
          else {
            throw
              DatabaseIssue
              .error(
                underlyingError:
                  DatabaseDataInvalid
                  .error(for: ResourceUserGroupListItemDSV.self)
              )
          }

          return UserDetailsDSV(
            id: id,
            username: username,
            firstName: firstName,
            lastName: lastName,
            fingerprint: fingerprint,
            avatarImageURL: avatarImageURL
          )
        }
    }

    nonisolated func executeAsync(
      _ input: UsersDatabaseFilter
    ) async throws -> Array<UserDetailsDSV> {
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

  internal func usePassboltUsersListFetchDatabaseOperation() {
    self.use(
      .disposable(
        UsersListFetchDatabaseOperation.self,
        load: UsersListFetchDatabaseOperation
          .load(features:)
      )
    )
  }
}