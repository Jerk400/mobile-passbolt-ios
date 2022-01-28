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
import Environment

public typealias SignOutRequest = NetworkRequest<EmptyNetworkSessionVariable, SignOutRequestVariable, Void>

extension SignOutRequest {

  internal static func live(
    using networking: Networking,
    with sessionVariablePublisher: AnyPublisher<EmptyNetworkSessionVariable, Error>
  ) -> Self {
    Self(
      template: .init { sessionVariable, requestVariable in
        .combined(
          .url(string: requestVariable.domain.rawValue),
          .pathSuffix("/auth/jwt/logout.json"),
          .method(.post),
          .jsonBody(from: requestVariable)
        )
      },
      responseDecoder: .statusCodes(200..<300),
      using: networking,
      with: sessionVariablePublisher
    )
  }
}

public struct SignOutRequestVariable: Encodable {

  public var domain: URLString  // not encoded into json
  public var refreshToken: String

  private enum CodingKeys: String, CodingKey {
    case refreshToken = "refresh_token"
  }

  public init(
    domain: URLString,
    refreshToken: String
  ) {
    self.domain = domain
    self.refreshToken = refreshToken
  }
}

public typealias SignOutResponse = Void
