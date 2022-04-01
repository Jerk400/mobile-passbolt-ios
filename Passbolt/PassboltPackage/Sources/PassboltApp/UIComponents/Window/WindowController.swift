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

import AccountSetup
import Accounts
import CommonModels
import NetworkClient
import UIComponents

internal struct WindowController {

  internal var screenStateDispositionPublisher: @MainActor () -> AnyPublisher<ScreenStateDisposition, Never>
}

extension WindowController {

  internal enum ScreenStateDisposition: Equatable {

    case useInitialScreenState(for: Account?)
    case useCachedScreenState(for: Account)
    case requestPassphrase(Account, message: DisplayableString?)
    case requestMFA(Account, providers: Array<MFAProvider>)
  }
}

extension WindowController: UIController {

  internal typealias Context = Void

  internal static func instance(
    in context: Void,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let accountSession: AccountSession = try await features.instance()

    let screenStateDispositionSubject: CurrentValueSubject<ScreenStateDisposition, Never> = .init(
      .useInitialScreenState(for: .none)
    )

    Publishers.Merge(
      accountSession
        .authorizationPromptPresentationPublisher()
        .eraseErrorType()
        .asyncMap { [unowned features] (promptRequest: AuthorizationPromptRequest) -> ScreenStateDisposition? in
          switch (screenStateDispositionSubject.value, promptRequest) {
          // Previous disposition presented authorization prompt for MFA and requesting passphrase
          case let (.requestMFA, .passphraseRequest(account, message)):
            // Replacing mfa prompt with passphrase prompt
            return .requestPassphrase(account, message: message)

          // Previous disposition presented passphrase prompt and requesting MFA
          case let (.requestPassphrase, .mfaRequest(account, providers: mfaProviders)):
            // Pushing mfa prompt on passphrase prompt
            return .requestMFA(account, providers: mfaProviders)

          // Previous disposition presented MFA prompt
          case (.requestPassphrase, _), (.requestMFA, _):
            // Ignoring other cases than previously handled.
            return .none

          // Previous disposition was not authorization prompt and requesting passphrase
          case let (.useCachedScreenState, .passphraseRequest(account, message)),
            let (.useInitialScreenState, .passphraseRequest(account, message)):
            if await features.isLoaded(AccountTransfer.self) {
              // Ignoring prompt requests during new account setup.
              // Setup is finished after successfully providing passphrase for the first time.
              return .none
            }
            else {
              // Presenting passphrase prompt
              return .requestPassphrase(account, message: message)
            }

          // Previous disposition was not authorization prompt and requesting mfa
          case let (.useCachedScreenState, .mfaRequest(account, mfaProviders)),
            let (.useInitialScreenState, .mfaRequest(account, mfaProviders)):
            if await features.isLoaded(AccountTransfer.self) {
              // Ignoring prompt requests during new account setup.
              // Setup is finished after successfully providing passphrase for the first time.
              return .none
            }
            else {
              // Presenting mfa prompt
              return .requestMFA(account, providers: mfaProviders)
            }
          }
        }
        .replaceError(with: nil)
        .filterMapOptional(),
      accountSession
        .statePublisher()
        .compactMap { sessionState -> ScreenStateDisposition? in
          switch (sessionState, screenStateDispositionSubject.value) {
          // authorized after prompting
          case let (.authorized(account), .requestPassphrase(promptedAccount, _))
          where promptedAccount == account,
            let (.authorized(account), .requestMFA(promptedAccount, _))
          where promptedAccount == account:
            return .useCachedScreenState(for: account)

          // switched to same account (mfa has to be handled by sign in flow if needed)
          case let (.authorized(account), .useInitialScreenState(previousAccount))
          where account == previousAccount:
            return .useInitialScreenState(for: account)

          // switched to same account (mfa has to be handled by sign in flow if needed)
          case let (.authorized(account), .useCachedScreenState(previousAccount))
          where account == previousAccount:
            return .useInitialScreenState(for: account)

          // initially authorized (mfa has to be handled by sign in flow if needed)
          case let (.authorized(account), .useInitialScreenState),
            let (.authorized(account), .requestPassphrase):
            return .useInitialScreenState(for: account)

          // switched to other account (mfa has to be handled by sign in flow if needed)
          case let (.authorized(account), .useCachedScreenState):
            return .useInitialScreenState(for: account)

          // passphrase cache cleared or started authorization for other account
          case (.authorizationRequired, _):
            return .none

          // no change at all (authorization screen displayed without session)
          case (.none, .requestPassphrase), (.none, .useInitialScreenState(.none)):
            return .none

          // signed out after requesting MFA
          case (.none, .requestMFA):
            return .useInitialScreenState(for: nil)

          // signed out
          case (.none, .useInitialScreenState(.some)),
            (.none, .useCachedScreenState):
            return .useInitialScreenState(for: .none)

          // Session state changed to mfa required
          case (.authorizedMFARequired, _):
            // always handled by using prompt (prompting changes session state)
            // or during passphrase auth flow if needed
            return .none

          // mfa auth succeeded
          case let (.authorized(account), .requestMFA(previousAccount, _))
          where account == previousAccount:
            return .useCachedScreenState(for: account)

          // mfa auth succeeded but for wrong account
          case (.authorized, .requestMFA):
            unreachable("Cannot authorize to an account after requesting MFA for a different one")
          }
        }
    )
    .subscribe(screenStateDispositionSubject)
    .store(in: cancellables)

    func screenStateDispositionPublisher() -> AnyPublisher<ScreenStateDisposition, Never> {
      screenStateDispositionSubject
        .eraseErrorType()
        .asyncMap { [weak features] (disposition: ScreenStateDisposition) -> (ScreenStateDisposition, Bool) in
          let inTransfer = await features?.isLoaded(AccountTransfer.self) ?? false
          return (disposition, inTransfer)
        }
        .filter { (disposition, inTransfer) in
          switch disposition {
          case .requestPassphrase, .requestMFA, .useCachedScreenState:
            return true
          case .useInitialScreenState:
            // We are blocking automatic screen changes while
            // account transfer is in progress (from QR code scanning
            // up to successfull authorization)
            return !inTransfer
          }
        }
        .map { $0.0 }
        .replaceError(with: .useInitialScreenState(for: nil))
        .eraseToAnyPublisher()
    }

    return Self(
      screenStateDispositionPublisher: screenStateDispositionPublisher
    )
  }
}
