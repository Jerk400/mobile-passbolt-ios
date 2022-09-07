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

// MARK: - Interface

/// Session feature manages session state.
public struct Session {
  /// Async sequence distributing new values
  /// each time session state changes including
  /// requesting authorization and authorizing.
  public var updatesSequence: UpdatesSequence
  /// Check if there is any pending
  /// authorization request.
  public var pendingAuthorization: @SessionActor @Sendable () -> SessionAuthorizationRequest?
  /// Get the current session account if any.
  /// Throws if there is no active session.
  public var currentAccount: @SessionActor @Sendable () async throws -> Account
  /// Create new session using provided method.
  /// Closes current session if used account is different.
  /// Successful authorization should change
  /// features scope based on current account and
  /// creating new stack if needed.
  /// Throws if provided method or data is invalid.
  /// Throws when MFA is required after successful
  /// authorization.
  public var authorize: @SessionActor @Sendable (SessionAuthorizationMethod) async throws -> Void
  /// Creates MFA token to be used for current session.
  /// Throws if there is no session or MFA was not required.
  /// Throws if provided method or data is invalid.
  public var authorizeMFA: @SessionActor @Sendable (SessionMFAAuthorizationMethod) async throws -> Void
  /// Close session for given account if any
  /// or current session if any otherwise.
  public var close: @SessionActor @Sendable (_ account: Account?) async -> Void

  public init(
    updatesSequence: UpdatesSequence,
    pendingAuthorization: @escaping @SessionActor @Sendable () -> SessionAuthorizationRequest?,
    currentAccount: @escaping @SessionActor @Sendable () async throws -> Account,
    authorize: @escaping @SessionActor @Sendable (SessionAuthorizationMethod) async throws -> Void,
    authorizeMFA: @escaping @SessionActor @Sendable (SessionMFAAuthorizationMethod) async throws -> Void,
    close: @escaping @SessionActor @Sendable (_ account: Account?) async -> Void
  ) {
    self.updatesSequence = updatesSequence
    self.pendingAuthorization = pendingAuthorization
    self.currentAccount = currentAccount
    self.authorize = authorize
    self.authorizeMFA = authorizeMFA
    self.close = close
  }
}

extension Session: LoadableContextlessFeature {

  #if DEBUG
  public nonisolated static var placeholder: Self {
    Self(
      updatesSequence: .placeholder,
      pendingAuthorization: unimplemented(),
      currentAccount: unimplemented(),
      authorize: unimplemented(),
      authorizeMFA: unimplemented(),
      close: unimplemented()
    )
  }
  #endif
}

extension Session {

  @Sendable public func currentAccountSequence() -> AnyAsyncThrowingSequence<Account?> {
    self.updatesSequence
      .map { try await self.currentAccount() }
      .removeDuplicates()
      .asAnyAsyncThrowingSequence()
  }

  @Sendable public func authorizationRequestSequence() -> AnyAsyncSequence<SessionAuthorizationRequest?> {
    self.updatesSequence
      .map { await self.pendingAuthorization() }
      .removeDuplicates()
      .asAnyAsyncSequence()
  }
}