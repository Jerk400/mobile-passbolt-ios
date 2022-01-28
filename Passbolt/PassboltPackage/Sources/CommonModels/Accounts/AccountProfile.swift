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

// Mutable part of account, used to store profile details and settings.
// WARNING: Do not add new or rename fields in this structure
// - it will cause data wipe on devices after update.
// Prepare data migration mechanism before making such changes.
public struct AccountProfile {

  public let accountID: Account.LocalID
  public var label: String
  public var username: String
  public var firstName: String
  public var lastName: String
  public var avatarImageURL: String
  public var biometricsEnabled: Bool
  // Due to data migration limitations, properties that are yet undefined can be stored
  // in this dictionary until migration becomes implemented.
  public var settings: Dictionary<String, String> = .init()

  public init(
    accountID: Account.LocalID,
    label: String,
    username: String,
    firstName: String,
    lastName: String,
    avatarImageURL: String,
    biometricsEnabled: Bool,
    settings: Dictionary<String, String> = .init()
  ) {
    self.accountID = accountID
    self.label = label
    self.username = username
    self.firstName = firstName
    self.lastName = lastName
    self.avatarImageURL = avatarImageURL
    self.biometricsEnabled = biometricsEnabled
    self.settings = settings
  }
}

extension AccountProfile: Equatable {}
extension AccountProfile: Codable {}
