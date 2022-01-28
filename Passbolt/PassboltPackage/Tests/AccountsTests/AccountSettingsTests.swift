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

import Combine
import CommonModels
import Crypto
import Features
import NetworkClient
import TestExtensions

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSettingsTests: TestCase {

  var accountSession: AccountSession!
  var accountsDataStore: AccountsDataStore!
  var permissions: OSPermissions!

  override func setUp() {
    super.setUp()
    accountSession = .placeholder
    accountsDataStore = .placeholder
    accountsDataStore.updateAccountProfile = always(.success)
    permissions = .placeholder
    features.patch(
      \NetworkClient.userProfileRequest,
      with: .respondingWith(
        .init(
          header: .mock(),
          body: .init(
            id: "user-id",
            profile: .init(
              firstName: "firstName",
              lastName: "lastName",
              avatar: .init(
                url: .init(
                  medium: "https://passbolt.com/image.jpg"
                )
              )
            ),
            gpgKey: .init(armoredKey: "armored-public-key")
          )
        )
      )
    )
  }

  override func tearDown() {
    accountSession = nil
    accountsDataStore = nil
    permissions = nil
    super.tearDown()
  }

  func test_biometricsEnabledPublisher_publishesProfileValueInitially() {
    accountSession.statePublisher = always(
      CurrentValueSubject<AccountSessionState, Never>(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    accountSession.requestAuthorizationPrompt = { _ in }
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(Empty().eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: Bool?
    feature
      .biometricsEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_biometricsEnabledPublisher_publishesTrue_afterBiometricsStateInProfileChangesToTrue() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    var currentAccount: AccountProfile = validAccountProfile
    accountsDataStore.loadAccountProfile = always(.success(currentAccount))
    let updatedAccountIDSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountsDataStore.updatedAccountIDsPublisher = always(updatedAccountIDSubject.eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: Bool?
    feature
      .biometricsEnabledPublisher()
      .dropFirst()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    currentAccount.biometricsEnabled = true
    updatedAccountIDSubject.send(currentAccount.accountID)

    XCTAssertTrue(result)
  }

  func test_biometricsEnabledPublisher_publishesFalse_whenProfileLoadingFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.failure(.testError()))
    accountsDataStore.updatedAccountIDsPublisher = always(Just(validAccount.localID).eraseToAnyPublisher())

    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: Bool?
    feature
      .biometricsEnabledPublisher()
      .sink { enabled in
        result = enabled
      }
      .store(in: cancellables)

    XCTAssertFalse(result)
  }

  func test_setBiometricsEnabled_succeedsEnabling_withAllRequirementsFulfilled() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.patch(
      \AccountSession.storePassphraseWithBiometry,
      with: always(.success)
    )
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: TheErrorLegacy?
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_setBiometricsEnabled_succeedsDisabling_withAllRequirementsFulfilled() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    features.patch(
      \AccountSession.storePassphraseWithBiometry,
      with: always(.success)
    )
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.deleteAccountPassphrase = always(.success)
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(true).eraseToAnyPublisher())
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: TheErrorLegacy?
    feature
      .setBiometricsEnabled(false)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_setBiometricsEnabled_fails_withNoBiometricsPermission() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.storeAccountPassphrase = always(.success)
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    permissions.ensureBiometricsPermission = always(Just(false).eraseToAnyPublisher())
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: TheErrorLegacy!
    feature
      .setBiometricsEnabled(true)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .permissionRequired)
  }

  func test_currentAccountProfilePublisher_publishesInitialProfile() {
    accountSession.statePublisher = always(
      CurrentValueSubject<AccountSessionState, Never>(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(
      Just(validAccountProfile.accountID).eraseToAnyPublisher()
    )
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()
    var result: AccountProfile?

    feature
      .currentAccountProfilePublisher()
      .sink { accountWithProfile in
        result = accountWithProfile.profile
      }
      .store(in: cancellables)

    XCTAssertEqual(result, validAccountProfile)
  }

  func test_currentAccountProfilePublisher_publishesUpdatedProfile() {
    let accountSessionAccountSubject: CurrentValueSubject<Account, Never> = .init(validAccount)
    accountSession.statePublisher = always(
      accountSessionAccountSubject
        .map(AccountSessionState.authorized)
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = {
      switch $0 {
      case validAccountProfile.accountID:
        return .success(validAccountProfile)
      case otherValidAccountProfile.accountID:
        return .success(otherValidAccountProfile)
      case _:
        fatalError()
      }
    }
    let updatedAccountIDSubject: PassthroughSubject<Account.LocalID, Never> = .init()
    accountsDataStore.updatedAccountIDsPublisher = always(updatedAccountIDSubject.eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()
    var results: Array<AccountProfile> = .init()

    feature
      .currentAccountProfilePublisher()
      .sink { accountWithProfile in
        results.append(accountWithProfile.profile)
      }
      .store(in: cancellables)

    accountSessionAccountSubject.value = validAccountAlternative

    XCTAssertEqual(results.popLast(), otherValidAccountProfile)
    XCTAssertEqual(results.popLast(), validAccountProfile)
  }

  func test_currentAccountProfilePublisher_doesNotPublish_whenLoadingOfProfileFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.failure(.testError()))
    accountsDataStore.updatedAccountIDsPublisher = always(
      Just(validAccountProfile.accountID).eraseToAnyPublisher()
    )
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    feature
      .currentAccountProfilePublisher()
      .sink(
        receiveCompletion: { completion in
          XCTFail("Unexpected error")
        },
        receiveValue: { _ in
          XCTFail("Unexpected value")
        }
      )
      .store(in: cancellables)
  }

  func test_setAvatarImageURL_succeeds_withHappyPath() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updateAccountProfile = always(.success)
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: Void?
    feature
      .setAvatarImageURL("https://passbolt.com/avatar/image.jpg")
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_setAvatarImageURL_fails_withNoSession() {
    accountSession.statePublisher = always(
      Just(.none(lastUsed: validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: TheErrorLegacy!
    feature
      .setAvatarImageURL("https://passbolt.com/avatar/image.jpg")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .authorizationRequired)
  }

  func test_setAvatarImageURL_fails_withSessionAuthorizationRequired() {
    accountSession.statePublisher = always(
      Just(.authorizationRequired(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: TheErrorLegacy!
    feature
      .setAvatarImageURL("https://passbolt.com/avatar/image.jpg")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .authorizationRequired)
  }

  func test_setAvatarImageURL_fails_whenProfileSaveFails() {
    accountSession.statePublisher = always(
      Just(.authorized(validAccount))
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updateAccountProfile = always(.failure(.testError()))
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    let feature: AccountSettings = testInstance()

    var result: TheErrorLegacy!
    feature
      .setAvatarImageURL("https://passbolt.com/avatar/image.jpg")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertEqual(result.identifier, .testError)
  }

  func test_currentAccountProfileUpdate_isTriggered_whenChangingAccount() {
    let accountSessionAccountSubject: CurrentValueSubject<AccountSessionState, Never> = .init(.none(lastUsed: nil))
    accountSession.statePublisher = always(
      accountSessionAccountSubject
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    var requestVariable: UserProfileRequestVariable? {
      didSet { result = Void() }
    }
    var result: Void?
    features.patch(
      \NetworkClient.userProfileRequest,
      with:
        .respondingWith(
          .init(
            header: .mock(),
            body: .init(
              id: "user-id",
              profile: .init(
                firstName: "firstName",
                lastName: "lastName",
                avatar: .init(
                  url: .init(
                    medium: "https://passbolt.com/image.jpg"
                  )
                )
              ),
              gpgKey: .init(armoredKey: "armored-public-key")
            )
          ),
          storeVariableIn: &requestVariable
        )
    )

    let feature: AccountSettings = testInstance()
    _ = feature  // silence warning

    accountSessionAccountSubject.value = .authorized(validAccount)

    XCTAssertNotNil(result)
  }

  func test_currentAccountProfileUpdate_isNotTriggeredAgain_whenChangingToSameAccount() {
    let accountSessionAccountSubject: CurrentValueSubject<AccountSessionState, Never> = .init(
      .authorized(validAccount)
    )
    accountSession.statePublisher = always(
      accountSessionAccountSubject
        .eraseToAnyPublisher()
    )
    features.use(accountSession)
    accountsDataStore.loadAccountProfile = always(.success(validAccountProfile))
    accountsDataStore.updatedAccountIDsPublisher = always(Empty<Account.LocalID, Never>().eraseToAnyPublisher())
    features.use(accountsDataStore)
    features.use(permissions)

    var requestVariable: UserProfileRequestVariable? {
      didSet { result += 1 }
    }
    var result: Int = 0
    features.patch(
      \NetworkClient.userProfileRequest,
      with:
        .respondingWith(
          .init(
            header: .mock(),
            body: .init(
              id: "user-id",
              profile: .init(
                firstName: "firstName",
                lastName: "lastName",
                avatar: .init(
                  url: .init(
                    medium: "https://passbolt.com/image.jpg"
                  )
                )
              ),
              gpgKey: .init(armoredKey: "armored-public-key")
            )
          ),
          storeVariableIn: &requestVariable
        )
    )

    let feature: AccountSettings = testInstance()
    _ = feature  // silence warning

    accountSessionAccountSubject.value = .authorized(validAccount)
    accountSessionAccountSubject.value = .authorized(validAccount)
    accountSessionAccountSubject.value = .authorized(validAccount)

    XCTAssertEqual(result, 1)
  }
}

private let validAccount: Account = .init(
  localID: .init(rawValue: UUID.test.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID",
  fingerprint: "FINGERPRINT"
)

private let validAccountAlternative: Account = .init(
  localID: .init(rawValue: UUID.testAlt.uuidString),
  domain: "https://passbolt.dev",
  userID: "USER_ID_ALT",
  fingerprint: "FINGERPRINT_ALT"
)

private let validAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.test.uuidString),
  label: "firstName lastName",
  username: "username",
  firstName: "firstName",
  lastName: "lastName",
  avatarImageURL: "avatarImagePath",
  biometricsEnabled: false
)

private let otherValidAccountProfile: AccountProfile = .init(
  accountID: .init(rawValue: UUID.testAlt.uuidString),
  label: "name lastName",
  username: "user",
  firstName: "name",
  lastName: "lastName",
  avatarImageURL: "otherAvatarImagePath",
  biometricsEnabled: true
)

// swift-format-ignore: NeverUseForceTry
private let validSessionTokens: NetworkSessionState = .init(
  account: validAccount,
  accessToken: try! JWT.from(rawValue: validToken).get(),
  refreshToken: "REFRESH_TOKEN"
)

private let validToken: String = """
  eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
  """
