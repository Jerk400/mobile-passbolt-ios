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

import AuthenticationServices
import Features

// MARK: - Interface

public struct OSExtensions {

  public var autofillExtensionEnabled: @Sendable () async -> Bool
}

extension OSExtensions: StaticFeature {

  #if DEBUG
  nonisolated public static var placeholder: Self {
    Self(
      autofillExtensionEnabled: unimplemented0()
    )
  }
  #endif
}

// MARK: - Implementation

extension OSExtensions {

  fileprivate static var live: Self {

    @Sendable func autofillExtensionEnabled() async -> Bool {
      await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
        ASCredentialIdentityStore.shared.getState { state in
          continuation.resume(returning: state.isEnabled)
        }
      }
    }

    return Self(
      autofillExtensionEnabled: autofillExtensionEnabled
    )
  }
}

extension FeaturesRegistry {

  internal mutating func useOSExtensions() {
    self.use(
      OSExtensions.live
    )
  }
}
