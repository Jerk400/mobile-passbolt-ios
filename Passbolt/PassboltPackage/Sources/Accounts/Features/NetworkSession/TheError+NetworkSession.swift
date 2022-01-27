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
import Commons
import Crypto

extension TheErrorLegacy {

  public static func signInError(
    underlyingError: Error? = nil
  ) -> Self {
    .init(
      identifier: .signInError,
      underlyingError: underlyingError,
      extensions: .init()
    )
  }

  public static func missingSessionError(
    underlyingError: Error? = nil
  ) -> Self {
    .init(
      identifier: .missingSessionError,
      underlyingError: underlyingError,
      extensions: .init()
    )
  }

  public static func invalidServerFingerprint(
    underlyingError: Error? = nil,
    accountID: Account.LocalID,
    updatedFingerprint: Fingerprint
  ) -> Self {
    .init(
      identifier: .invalidServerFingerprint,
      underlyingError: underlyingError,
      extensions: [
        .accountID: accountID,
        .serverFingerprint: updatedFingerprint,
      ]
    )
  }
}

extension TheErrorLegacy.ID {

  public static let signInError: Self = "signInError"
  public static let missingSessionError: Self = "missingSessionError"
  public static let invalidServerFingerprint: Self = "invalidServerFingerprint"
}

extension TheErrorLegacy.Extension {

  public static let accountID: Self = "accountID"
  public static let serverFingerprint: Self = "serverFingerprint"
}

extension TheErrorLegacy {

  public var accountID: Account.LocalID? { extensions[.accountID] as? Account.LocalID }
  public var serverFingerprint: Fingerprint? { extensions[.serverFingerprint] as? Fingerprint }
}
