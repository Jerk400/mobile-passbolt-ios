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
import Crypto
import Features
import NetworkClient
import TestExtensions
import XCTest

@testable import Accounts

// swift-format-ignore: AlwaysUseLowerCamelCase, NeverUseImplicitlyUnwrappedOptionals
final class AccountSessionTests: TestCase {

  var accountsDataStore: AccountsDataStore!
  var networkClient: NetworkClient!

  override func setUp() {
    super.setUp()
    accountsDataStore = .placeholder
    accountsDataStore.loadLastUsedAccount = always(validAccount)
    networkClient = .placeholder
    networkClient.setAuthorizationRequest = always(Void())
    networkClient.setMFARequest = always(Void())
    networkClient.setSessionStatePublisher = always(Void())
    environment.appLifeCycle.lifeCyclePublisher = always(Empty().eraseToAnyPublisher())
    environment.time.timestamp = always(0)
    environment.pgp.verifyPassphrase = always(.success)
  }

  override func tearDown() {
    accountsDataStore = nil
    networkClient = nil
    super.tearDown()
  }

  func test_statePublisher_publishesNoneState_initially() {
    features.patch(
      \AccountsDataStore.loadLastUsedAccount,
      with: always(.none)
    )
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    var result: AccountSessionState?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    XCTAssertEqual(result, .some(.none(lastUsed: .none)))
  }

  func test_statePublisher_publishesLastUsedAccount_initially() {
    features.patch(
      \AccountsDataStore.loadLastUsedAccount,
      with: always(validAccount)
    )
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .none(lastUsed) = state
        else { return }
        result = lastUsed
      }
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesAuthorized_whenAuthorizationSucceeds() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorized(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesAuthorizationRequired_whenAppGoesIntoBackgroundWithSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    let lifeCycleSubject: PassthroughSubject<AppLifeCycle.Transition, Never> = .init()
    features.environment.appLifeCycle.lifeCyclePublisher = {
      lifeCycleSubject.eraseToAnyPublisher()
    }

    let feature: AccountSession = testInstance()

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorizationRequired(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    lifeCycleSubject.send(.didEnterBackground)

    XCTAssertEqual(result, validAccount)
  }

  func test_statePublisher_publishesNone_whenClosingSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    features.patch(
      \NetworkSession.closeSession,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: Void?
    feature
      .statePublisher()
      .dropFirst()
      .sink { state in
        guard case .none = state
        else { return }
        result = Void()
      }
      .store(in: cancellables)

    feature.close()

    XCTAssertNotNil(result)
  }

  func test_statePublisher_publishesNoLastUsedAccount_whenClosingSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    features.patch(
      \NetworkSession.closeSession,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: Account?
    feature
      .statePublisher()
      .dropFirst()
      .sink { state in
        guard case let .none(lastUsed) = state
        else { return }
        result = lastUsed
      }
      .store(in: cancellables)

    feature.close()

    XCTAssertNil(result)
  }

  func test_statePublisher_publishesAuthorizationRequired_whenPassphraseCacheIsExpired() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    features.patch(
      \NetworkSession.closeSession,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    var currentTimestamp: Timestamp = 0
    environment.time.timestamp = always(currentTimestamp)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    var result: Account?
    feature
      .statePublisher()
      .sink { state in
        guard case let .authorizationRequired(account) = state
        else { return }
        result = account
      }
      .store(in: cancellables)

    XCTAssertEqual(result, validAccount)
  }

  func test_decryptMessage_fails_whenPassphraseCacheIsExpired() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    features.patch(
      \NetworkSession.closeSession,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )

    var currentTimestamp: Timestamp = 0
    environment.time.timestamp = always(currentTimestamp)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    var result: TheErrorLegacy?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(result?.legacyBridge, matches: SessionAuthorizationRequired.self)
  }

  func test_decryptMessage_fails_withoutActiveSession() {
    features.use(accountsDataStore)
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertError(result?.legacyBridge, matches: SessionMissing.self)
  }

  func test_decryptMessage_fails_whenLoadingAccountPrivateKeyFails() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.failure(.testError()))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_decryptMessage_fails_whenDecryptionFails() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    environment.pgp.decrypt = always(.failure(MockIssue.error()))

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .legacyBridge)
  }

  func test_decryptMessage_succeeds_whenDecryptionSucceeds() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    environment.pgp.decrypt = always(.success("decrypted"))

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: String?
    feature
      .decryptMessage("encrypted message", nil)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { decrypted in
          result = decrypted
        }
      )
      .store(in: cancellables)

    XCTAssertEqual(result, "decrypted")
  }

  func
    test_authorizationPromptPresentationPublisher_publishesCurrentAccount_whenDecryptMessage_fails_withSessionAuthorizationRequired()
  {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success("PRIVATE KEY"))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    var currentTimestamp: Timestamp = 0
    environment.time.timestamp = always(currentTimestamp)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", armoredPGPPrivateKey))
      .sinkDrop()
      .store(in: cancellables)

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { request in
        result = request
      }
      .store(in: cancellables)

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    feature
      .decryptMessage("message", nil)
      .sink(
        receiveCompletion: { _ in },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.account, validAccount)
  }

  func test_authorize_fails_whenSessionCreateFails() {
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Fail(error: .testError())
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var resultError: TheErrorLegacy?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          resultError = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(resultError?.identifier, .testError)
  }

  func test_authorize_succeeds_whenSessionCreateSucceeds() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var resultError: TheErrorLegacy?
    var result: Void?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          resultError = error
        },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNil(resultError)
    XCTAssertNotNil(result)
  }

  func test_authorize_succeedsWithAuthorized_whenSessionCreateSucceedsWithNoMFAProviders() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    features.patch(
      \NetworkSession.closeSession,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )

    let feature: AccountSession = testInstance()

    var result: AccountSessionState?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    guard case .authorized = result
    else { return XCTFail() }
  }

  func test_authorize_succeedsWithAuthorizedMFARequired_whenSessionCreateSucceedsWithMFAProviders() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>([.totp]))
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var result: AccountSessionState?
    feature
      .statePublisher()
      .sink { state in
        result = state
      }
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result, .authorizedMFARequired(validAccount, providers: [.totp]))
  }

  func test_authorize_fails_whenPrivateKeyIsInaccessibleWhileUsingPassphrase() {
    accountsDataStore.loadAccountPrivateKey = always(.failure(.testError()))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .authorize(validAccount, .passphrase("passphrase"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_authorize_succeeds_whenPrivateKeyIsAccessibleWhileUsingPassphrase() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .authorize(validAccount, .passphrase("passphrase"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_authorize_fails_whenPrivateKeyIsInaccessibleWhileUsingBiometrics() {
    accountsDataStore.loadAccountPassphrase = always(.success("passphrase"))
    accountsDataStore.loadAccountPrivateKey = always(.failure(.testError()))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .authorize(validAccount, .biometrics)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_authorize_fails_whenPassphraseIsInaccessibleWhileUsingBiometrics() {
    accountsDataStore.loadAccountPassphrase = always(.failure(.testError()))
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .authorize(validAccount, .biometrics)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_authorize_succeeds_whenPrivateKeyAndPassphraseIsAccessibleWhileUsingBiometrics() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccountPassphrase = always(.success("passphrase"))
    accountsDataStore.loadAccountPrivateKey = always(.success(armoredPGPPrivateKey))
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .authorize(validAccount, .biometrics)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in }
      )
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_close_callsNetworkSessionClose() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    var result: Void?
    features.patch(
      \NetworkSession.closeSession,
      with: {
        result = Void()
        return Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      }
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .statePublisher()
      .dropFirst()
      .sink { _ in }
      .store(in: cancellables)

    feature.close()

    XCTAssertNotNil(result)
  }

  func test_close_doesNothing_withoutActiveSession() {
    accountsDataStore.loadLastUsedAccount = always(nil)
    features.use(accountsDataStore)
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    var result: Void?
    feature
      .statePublisher()
      .dropFirst()
      .sink { session in
        result = Void()
      }
      .store(in: cancellables)

    feature.close()

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_doesNotPublish_initially() {
    features.use(accountsDataStore)
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_doesNotPublish_whenRequestingExplicitlyWithoutActiveSession() {
    features.use(accountsDataStore)
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    feature.requestAuthorizationPrompt(.testMessage())

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_publishesRequest_whenRequestingExplicitly() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { authorizationPromptRequest in
        result = authorizationPromptRequest
      }
      .store(in: cancellables)

    feature.requestAuthorizationPrompt(.testMessage())

    XCTAssertEqual(result?.account, validAccount)
    XCTAssertEqual(result?.message?.string(), "testLocalizationKey")
  }

  func test_authorize_succeeds_whenSwitchingSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadServerFingerprint = always(.success(.init(rawValue: "FINGERPRINT")))
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    features.patch(
      \NetworkSession.closeSession,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccountAlternative, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var resultError: TheErrorLegacy?
    var result: Void?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          resultError = error
        },
        receiveValue: { _ in
          result = Void()
        }
      )
      .store(in: cancellables)

    XCTAssertNil(resultError)
    XCTAssertNotNil(result)
  }

  func test_authorize_doesNotClosePreviousSession_whenSwitchingToSameAccount() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    var result: Void?
    features.patch(
      \NetworkSession.closeSession,
      with: {
        result = Void()
        return Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      }
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNil(result)
  }

  func test_authorizationPromptPresentationPublisher_publishesCurrentAccount_whenApplicationWillEnterForeground() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let appLifeCycleSubject: PassthroughSubject<AppLifeCycle.Transition, Never> = .init()
    environment.appLifeCycle.lifeCyclePublisher = always(appLifeCycleSubject.eraseToAnyPublisher())

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: AuthorizationPromptRequest?
    feature
      .authorizationPromptPresentationPublisher()
      .sink { request in
        result = request
      }
      .store(in: cancellables)

    appLifeCycleSubject.send(.willEnterForeground)

    XCTAssertEqual(result?.account, validAccount)
  }

  func test_mfaAuthorization_fails_withNoActiveSession() {
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    features.patch(
      \NetworkSession.createMFAToken,
      with: always(
        Empty()
          .eraseToAnyPublisher()
      )
    )

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .mfaAuthorize(.totp("OTP"), false)
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: {}
      )
      .store(in: cancellables)

    XCTAssertError(result?.legacyBridge, matches: SessionMissing.self)
  }

  func test_mfaAuthorization_isForwardedToNetworkSession() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    var result: (account: Account, authorization: AccountSession.MFAAuthorizationMethod, remember: Bool)?
    features.patch(
      \NetworkSession.createMFAToken,
      with: { account, authorization, remember in
        result = (account, authorization, remember)
        return Empty().eraseToAnyPublisher()
      }
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    feature
      .mfaAuthorize(.totp("OTP"), false)
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertEqual(result?.account, validAccount)
    XCTAssertEqual(result?.authorization, .totp("OTP"))
    XCTAssertEqual(result?.remember, false)
  }

  func test_authorize_fails_whenSessionRefreshIsAvailableAndPassphraseIsNotValid() {
    environment.pgp.verifyPassphrase = always(.failure(MockIssue.error()))
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(true)
    )

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .legacyBridge)
  }

  func test_authorize_fallbacksToCreateSession_whenSessionRefreshIsAvailableAndSessionRefreshFails() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    var result: Void?
    features.patch(
      \NetworkSession.createSession,
      with: { _, _, _ in
        result = Void()
        return Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      }
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(true)
    )
    features.patch(
      \NetworkSession.refreshSessionIfNeeded,
      with: always(
        Fail(error: .testError())
          .eraseToAnyPublisher()
      )
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_authorize_doesSessionRefresh_whenSessionRefreshIsAvailableAndPassphraseIsValid() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(true)
    )
    var result: Void?
    features.patch(
      \NetworkSession.refreshSessionIfNeeded,
      with: { _ in
        result = Void()
        return Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      }
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_authorize_succeeds_whenSessionRefreshSucceeds() {
    accountsDataStore.storeLastUsedAccount = always(Void())
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(true)
    )
    features.patch(
      \NetworkSession.refreshSessionIfNeeded,
      with: always(
        Just(Void())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )

    let feature: AccountSession = testInstance()

    var result: Void?
    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sink(
        receiveCompletion: { completion in
          guard case .finished = completion
          else { return }
          result = Void()
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_storePassphraseWithBiometry_failsStore_withoutSession() {
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    let result: Result<Void, TheErrorLegacy> =
      feature
      .storePassphraseWithBiometry(true)

    XCTAssertFailure(result)
  }

  func test_storePassphraseWithBiometry_failsStore_whenPassphraseExpires() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    var currentTimestamp: Timestamp = 0
    environment.time.timestamp = always(currentTimestamp)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    let result: Result<Void, TheErrorLegacy> =
      feature
      .storePassphraseWithBiometry(true)

    XCTAssertFailure(result)
  }

  func test_storePassphraseWithBiometry_failsStore_whenPassphraseStoreFails() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.storeAccountPassphrase,
      with: always(.failure(.testError()))
    )
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    let result: Result<Void, TheErrorLegacy> =
      feature
      .storePassphraseWithBiometry(true)

    XCTAssertFailure(result)
  }

  func test_storePassphraseWithBiometry_succeedsStore_whenPassphraseStoreSucceeds() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.storeAccountPassphrase,
      with: always(.success)
    )
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    let result: Result<Void, TheErrorLegacy> =
      feature
      .storePassphraseWithBiometry(true)

    XCTAssertSuccess(result)
  }

  func test_storePassphraseWithBiometry_failsDelete_withoutSession() {
    accountsDataStore.loadAccounts = always([validAccount, validAccountAlternative])
    features.use(accountsDataStore)
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    let result: Result<Void, TheErrorLegacy> =
      feature
      .storePassphraseWithBiometry(false)

    XCTAssertFailure(result)
  }

  func test_storePassphraseWithBiometry_failsDelete_whenPassphraseStoreFails() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.deleteAccountPassphrase,
      with: always(.failure(.testError()))
    )
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    let result: Result<Void, TheErrorLegacy> =
      feature
      .storePassphraseWithBiometry(false)

    XCTAssertFailure(result)
  }

  func test_storePassphraseWithBiometry_succeedsDelete_whenPassphraseDeleteSucceeds() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.deleteAccountPassphrase,
      with: always(.success)
    )
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    let result: Result<Void, TheErrorLegacy> =
      feature
      .storePassphraseWithBiometry(false)

    XCTAssertSuccess(result)
  }

  func test_encryptAndSignMessage_fails_withoutSession() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    var result: TheErrorLegacy?
    feature
      .encryptAndSignMessage("message", "public key")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertError(result?.legacyBridge, matches: SessionMissing.self)
  }

  func test_encryptAndSignMessage_fails_whenLoadingPrivateKeyFails() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always(.failure(.testError()))
    )
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    feature
      .encryptAndSignMessage("message", "public key")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .testError)
  }

  func test_encryptAndSignMessage_fails_whenEncryptAndSignFails() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always(.success("private key"))
    )
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    environment.pgp.encryptAndSign = always(.failure(MockIssue.error()))

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: TheErrorLegacy?
    feature
      .encryptAndSignMessage("message", "public key")
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion else { return }
          result = error
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertEqual(result?.identifier, .legacyBridge)
  }

  func test_encryptAndSignMessage_succeeds_withHappyPath() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.loadAccountPrivateKey,
      with: always(.success("private key"))
    )
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )
    environment.pgp.encryptAndSign = always(.success("encrypted"))

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    var result: Void?
    feature
      .encryptAndSignMessage("message", "public key")
      .sink(
        receiveCompletion: { completion in
          guard case let .finished = completion else { return }
          result = Void()
        },
        receiveValue: { _ in /* NOP */ }
      )
      .store(in: cancellables)

    XCTAssertNotNil(result)
  }

  func test_databaseKey_isNone_withoutSession() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.usePlaceholder(for: NetworkSession.self)

    let feature: AccountSession = testInstance()

    let result: String? = feature.databaseKey()

    XCTAssertNil(result)
  }

  func test_databaseKey_isNone_whenPassphraseCacheExpires() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    var currentTimestamp: Timestamp = 0
    environment.time.timestamp = always(currentTimestamp)

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    currentTimestamp = Timestamp(rawValue: 5 * 60)  // expired time

    let result: String? = feature.databaseKey()

    XCTAssertNil(result)
  }

  func test_databaseKey_isAvailable_withValidSession() {
    features.use(accountsDataStore)
    features.patch(
      \AccountsDataStore.storeLastUsedAccount,
      with: always(Void())
    )
    features.patch(
      \AccountsDataStore.loadAccounts,
      with: always([validAccount, validAccountAlternative])
    )
    features.use(networkClient)
    features.patch(
      \NetworkSession.createSession,
      with: always(
        Just(Array<MFAProvider>())
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      )
    )
    features.patch(
      \NetworkSession.sessionRefreshAvailable,
      with: always(false)
    )

    let feature: AccountSession = testInstance()

    feature
      .authorize(validAccount, .adHoc("passphrase", "private key"))
      .sinkDrop()
      .store(in: cancellables)

    let result: String? = feature.databaseKey()

    XCTAssertNotNil(result)
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
  domain: "https://alt.passbolt.dev",
  userID: "USER_ID_ALT",
  fingerprint: "FINGERPRINT_ALT"
)

private let validAccountAlternativeWithIDCollision: Account = .init(
  localID: .init(rawValue: UUID.testAlt.uuidString),
  domain: "https://alt.passbolt.dev",
  userID: "USER_ID",  // colliding ID
  fingerprint: "FINGERPRINT_ALT"
)

private let validSessionTokens: NetworkSessionState = .init(
  account: validAccount,
  accessToken: validJWTToken,
  refreshToken: "refresh_token"
)

private let armoredPGPPrivateKey: ArmoredPGPPrivateKey = "private_key"

private let validJWTToken: JWT = try! .from(
  rawValue: """
    eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9.eyJhdWQiOiJpb3MiLCJleHAiOjE1MTYyMzkwMjIsImlzcyI6IlBhc3Nib2x0Iiwic3ViIjoiMTIzNDU2Nzg5MCJ9.mooyAR9uQ1F6sHMaA3Ya4bRKPazydqowEsgm-Sbr7RmED36CShWdF3a-FdxyezcgI85FPyF0Df1_AhTOknb0sPs-Yur1Oa0XwsDsXfpw-xJsnlx9JCylp6C6rm_rypJL1E8t_63QCS_k5rv7hpDc8ctjLW8mXoFXXP_bDkSezyPVUaRDvjLgaDm01Ocin112h1FvQZTittQhhdL-KU5C1HjCJn03zNmH46TihstdK7PZ7mRz2YgIpm9P-5JzYYmSV3eP70_0dVCC_lv0N3VJFLKVB9FP99R4jChJv5DEilEgMwi_73YsP3Z55rGDaoyjhj661rDteq-42LMXcvSmOg
    """
)
.get()
