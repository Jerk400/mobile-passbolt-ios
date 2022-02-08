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
import NetworkClient
import Resources
import UIComponents

import struct Foundation.Data

internal struct HomeFilterController {

  internal var resourcesFilterPublisher: () -> AnyPublisher<ResourcesFilter, Never>
  internal var updateSearchText: (String) -> Void
  internal var searchTextPublisher: () -> AnyPublisher<String, Never>
  internal var avatarImagePublisher: () -> AnyPublisher<Data?, Never>
  internal var currentDisplayPublisher: () -> AnyPublisher<ResourcesDisplay, Never>
  internal var presentDisplayMenu: () -> Void
  internal var displayMenuPresentationPublisher:
    () -> AnyPublisher<
      (
        currentDisplay: ResourcesDisplay, availableDisplays: Array<ResourcesDisplay>,
        updateDisplay: (ResourcesDisplay) -> Void
      ), Never
    >
  internal var presentAccountMenu: () -> Void
  internal var accountMenuPresentationPublisher: () -> AnyPublisher<AccountWithProfile, Never>
}

extension HomeFilterController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Context,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) -> Self {
    let accountSettings: AccountSettings = features.instance()
    let networkClient: NetworkClient = features.instance()

    let searchTextSubject: CurrentValueSubject<String, Never> = .init("")
    let accountMenuPresentationSubject: PassthroughSubject<Void, Never> = .init()

    let currentDisplaySubject: CurrentValueSubject<ResourcesDisplay, Never> = .init(.plain)
    let displayMenuPresentationSubject: PassthroughSubject<Void, Never> = .init()

    func resourcesFilterPublisher() -> AnyPublisher<ResourcesFilter, Never> {
      searchTextSubject
        .map { searchText in ResourcesFilter(text: searchText) }
        .eraseToAnyPublisher()
    }

    func updateSearchText(_ text: String) {
      searchTextSubject.send(text)
    }

    func searchTextPublisher() -> AnyPublisher<String, Never> {
      searchTextSubject.eraseToAnyPublisher()
    }

    func avatarImagePublisher() -> AnyPublisher<Data?, Never> {
      accountSettings
        .currentAccountProfilePublisher()
        .map(\.avatarImageURL)
        .map { avatarImageURL in
          networkClient.mediaDownload.make(
            using: .init(urlString: avatarImageURL)
          )
          .map { data -> Data? in data }
          .replaceError(with: nil)
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func currentDisplayPublisher() -> AnyPublisher<ResourcesDisplay, Never> {
      currentDisplaySubject.eraseToAnyPublisher()
    }

    func presentDisplayMenu() {
      displayMenuPresentationSubject.send()
    }

    func displayMenuPresentationPublisher() -> AnyPublisher<
      (
        currentDisplay: ResourcesDisplay, availableDisplays: Array<ResourcesDisplay>,
        updateDisplay: (ResourcesDisplay) -> Void
      ), Never
    > {
      displayMenuPresentationSubject
        .map {
          (
            currentDisplay: currentDisplaySubject.value,
            availableDisplays: [.plain],  // TODO: MOB-167 - refine list of available items
            // TODO: [MOB-183] update display
            updateDisplay: currentDisplaySubject.send
          )
        }
        .eraseToAnyPublisher()
    }

    func presentAccountMenu() {
      accountMenuPresentationSubject.send()
    }

    func accountMenuPresentationPublisher() -> AnyPublisher<AccountWithProfile, Never> {
      accountMenuPresentationSubject
        .map {
          accountSettings
            .currentAccountProfilePublisher()
            .first()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    return Self(
      resourcesFilterPublisher: resourcesFilterPublisher,
      updateSearchText: updateSearchText,
      searchTextPublisher: searchTextPublisher,
      avatarImagePublisher: avatarImagePublisher,
      currentDisplayPublisher: currentDisplayPublisher,
      presentDisplayMenu: presentDisplayMenu,
      displayMenuPresentationPublisher: displayMenuPresentationPublisher,
      presentAccountMenu: presentAccountMenu,
      accountMenuPresentationPublisher: accountMenuPresentationPublisher
    )
  }
}
