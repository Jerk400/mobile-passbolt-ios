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

import struct Foundation.Date
import func Foundation.time

// MARK: - Interface

public struct OSTime {

  public var timestamp: () -> Timestamp
}

extension OSTime: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      timestamp: unimplemented0()
    )
  }
  #endif
}

extension OSTime {

  public func dateNow() -> Date {
    timestamp().asDate
  }
}

// MARK: - Implementation

extension OSTime {

  fileprivate static var live: Self {

    func timestamp() -> Timestamp {
      .init(rawValue: time(nil))
    }

    return Self(
      timestamp: timestamp
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useOSTime() {
    self.use(
      OSTime.live
    )
  }
}
