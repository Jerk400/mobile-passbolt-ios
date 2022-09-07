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
import SessionData
import Users

// MARK: - Implementation

extension UserGroupDetails {

  @MainActor fileprivate static func load(
    features: FeatureFactory,
    context userGroupID: Context,
    cancellables: Cancellables
  ) async throws -> Self {
    let sessionData: SessionData = try await features.instance()
    let userGroupDetailsFetchDatabaseOperation: UserGroupDetailsFetchDatabaseOperation = try await features.instance()

    @Sendable nonisolated func fetchUserGroupDetails() async throws -> UserGroupDetailsDSV {
      try await userGroupDetailsFetchDatabaseOperation(userGroupID)
    }

    let currentDetails: UpdatableValue<UserGroupDetailsDSV> = .init(
      updatesSequence:
        sessionData
        .updatesSequence,
      update: fetchUserGroupDetails
    )

    @Sendable nonisolated func details() async throws -> UserGroupDetailsDSV {
      try await currentDetails.value
    }

    return .init(
      details: details
    )
  }
}

extension FeatureFactory {

  @MainActor internal func usePassboltUserGroupDetails() {
    self.use(
      .lazyLoaded(
        UserGroupDetails.self,
        load: UserGroupDetails.load(features:context:cancellables:)
      )
    )
  }
}