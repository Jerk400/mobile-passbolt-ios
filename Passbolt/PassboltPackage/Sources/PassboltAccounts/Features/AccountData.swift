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

import Accounts

// TODO: future replacement for AccountsDataStore
internal struct AccountData {

  // temporararily exposing updates source for internal use
  internal var updatesSequenceSource: UpdatesSequenceSource
  /// Updates in the context account data.
  internal var updates: UpdatesSequence
}

extension AccountData: LoadableFeature {

  public typealias Context = Account

  #if DEBUG
  nonisolated static var placeholder: Self {
    Self(
      updatesSequenceSource: .init(),
      updates: .placeholder
    )
  }
  #endif
}

extension AccountData {

  @MainActor fileprivate static func load(
    features: Features,
    context account: Account,
    cancellables: Cancellables
  ) throws -> Self {

    let updatesSequenceSource: UpdatesSequenceSource = .init()

    return Self(
      updatesSequenceSource: updatesSequenceSource,
      updates: updatesSequenceSource.updatesSequence
    )
  }
}

extension FeaturesRegistry {

  internal mutating func usePassboltAccountData() {
    self.use(
      .lazyLoaded(
        AccountData.self,
        load: AccountData.load(features:context:cancellables:)
      )
    )
  }
}
