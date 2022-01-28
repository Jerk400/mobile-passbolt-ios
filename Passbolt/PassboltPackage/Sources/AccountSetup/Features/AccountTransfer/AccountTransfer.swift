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
import CommonModels
import Crypto
import Features
import NetworkClient

import struct Foundation.Data

#if DEBUG
import Dispatch
#endif

public struct AccountTransfer {
  // Publishes progess, finishes when process is completed or fails if it becomes interrupted.
  public var progressPublisher: () -> AnyPublisher<Progress, TheErrorLegacy>
  public var accountDetailsPublisher: () -> AnyPublisher<AccountDetails, TheErrorLegacy>
  public var processPayload: (String) -> AnyPublisher<Never, TheErrorLegacy>
  public var completeTransfer: (Passphrase) -> AnyPublisher<Never, TheErrorLegacy>
  public var avatarPublisher: () -> AnyPublisher<Data, TheErrorLegacy>
  public var cancelTransfer: () -> Void
  public var featureUnload: () -> Bool
}

extension AccountTransfer {

  public struct AccountDetails {

    public let domain: URLString
    public let label: String
    public let username: String
  }
}

extension AccountTransfer: Feature {

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> AccountTransfer {
    let diagnostics: Diagnostics = features.instance()
    diagnostics.diagnosticLog("Beginning new account transfer...")
    #if DEBUG
    let mdmSupport: MDMSupport = features.instance()
    #endif
    let networkClient: NetworkClient = features.instance()
    let accounts: Accounts = features.instance()
    let transferState: CurrentValueSubject<AccountTransferState, TheErrorLegacy> = .init(.init())
    var transferCancelationCancellable: AnyCancellable?
    _ = transferCancelationCancellable  // silence warning

    #if DEBUG
    if let mdmTransferedAccount: MDMSupport.TransferedAccount = mdmSupport.transferedAccount() {
      let accountAlreadyStored: Bool =
        accounts
        .storedAccounts()
        .contains(
          where: { stored in
            stored.userID.rawValue == mdmTransferedAccount.userID
              && stored.domain == mdmTransferedAccount.domain
          }
        )
      if !accountAlreadyStored {
        // since this bypass is not a proper app feature we have a bit hacky solution
        // where we set the state before presenting associated views and without informing it
        // this results in view presentation issues and requires some delay
        // which happened to be around 1 sec minimum at the time of writing this code
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          transferState.send(
            .init(
              configuration: AccountTransferConfiguration(
                transferID: "N/A",
                pagesCount: 0,
                userID: mdmTransferedAccount.userID,
                authenticationToken: "N/A",
                domain: mdmTransferedAccount.domain,
                hash: "N/A"
              ),
              account: AccountTransferAccount(
                userID: mdmTransferedAccount.userID,
                fingerprint: .init(rawValue: mdmTransferedAccount.fingerprint),
                armoredKey: ArmoredPGPPrivateKey(rawValue: mdmTransferedAccount.armoredKey)
              ),
              profile: AccountTransferAccountProfile(
                username: mdmTransferedAccount.username,
                firstName: mdmTransferedAccount.firstName,
                lastName: mdmTransferedAccount.lastName,
                avatarImageURL: mdmTransferedAccount.avatarImageURL
              ),
              scanningParts: []
            )
          )
        }
      }
      else {
        diagnostics.debugLog("Skipping account transfer bypass - duplicate account")
      }
    }
    else {
      /* */
    }
    #endif

    let progressPublisher: AnyPublisher<Progress, TheErrorLegacy> =
      transferState
      .map { state -> Progress in
        if state.scanningFinished {
          return .scanningFinished
        }
        else if let configuration: AccountTransferConfiguration = state.configuration {
          return .scanningProgress(
            Double(state.nextScanningPage ?? configuration.pagesCount)
              / Double(configuration.pagesCount)
          )
        }
        else {
          return .configuration
        }
      }
      .collectErrorLog(using: diagnostics)
      .eraseToAnyPublisher()

    let accountDetailsPublisher: AnyPublisher<AccountDetails, TheErrorLegacy> =
      transferState
      .compactMap { state in
        guard
          let config: AccountTransferConfiguration = state.configuration,
          let profile: AccountTransferAccountProfile = state.profile
        else { return nil }

        return AccountDetails(
          domain: config.domain,
          label: "\(profile.firstName) \(profile.lastName)",
          username: profile.username
        )
      }
      .eraseToAnyPublisher()

    let mediaPublisher: AnyPublisher<Data, TheErrorLegacy> =
      transferState
      .compactMap { $0.profile }
      .map {
        networkClient
          .mediaDownload
          .make(
            using: .init(
              urlString: $0.avatarImageURL
            )
          )
          .mapErrorsToLegacy()
      }
      .switchToLatest()
      .eraseToAnyPublisher()

    // swift-format-ignore: NoLeadingUnderscores
    func _processPayload(
      _ payload: String,
      using features: FeatureFactory
    ) -> AnyPublisher<Never, TheErrorLegacy> {
      diagnostics.diagnosticLog("Processing QR code payload...")
      switch processQRCodePayload(payload, in: transferState.value) {
      case var .success(updatedState):
        // if we have config we can ask for profile,
        // there is no need to do it every time
        // so doing it once when requesting for the next page first time
        if let configuration: AccountTransferConfiguration = updatedState.configuration,
          updatedState.profile == nil
        {
          // since we do this once per process (hopefully)
          // and right after reading initial configuration
          // we can verify immediately if we already have the same account stored
          let accountAlreadyStored: Bool =
            accounts
            .storedAccounts()
            .contains(
              where: { stored in
                stored.userID.rawValue == configuration.userID
                  && stored.domain == configuration.domain
              }
            )

          guard !accountAlreadyStored
          else {
            diagnostics.diagnosticLog("...duplicate account detected, aborting!")
            requestCancelation(
              with: configuration,
              lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
              using: networkClient,
              causedByError: nil
            )
            .handleEvents(receiveCompletion: { completion in
              // we are completing transfer with duplicate regardless the response
              transferState.send(completion: .failure(.duplicateAccount()))
              features.unload(Self.self)
            })
            .ignoreOutput()
            .sink(receiveCompletion: { _ in })
            .store(in: cancellables)

            return Fail<Never, TheErrorLegacy>(error: .duplicateAccount())
              .eraseToAnyPublisher()
          }

          guard !updatedState.scanningFinished
          else {
            diagnostics.diagnosticLog("...missing profile data, aborting!")
            transferState
              .send(
                completion: .failure(
                  .accountTransferScanningError(
                    context: "account-transfer-complete-missing-profile"
                  )
                )
              )
            features.unload(Self.self)
            return Empty<Never, TheErrorLegacy>()
              .eraseToAnyPublisher()
          }

          diagnostics.diagnosticLog("...processing succeeded, continuing transfer...")
          return requestNextPageWithUserProfile(
            for: updatedState,
            using: networkClient
          )
          .handleEvents(
            receiveOutput: { user in
              updatedState.profile = .init(
                username: user.username,
                firstName: user.profile.firstName,
                lastName: user.profile.lastName,
                avatarImageURL: user.profile.avatar.url.medium
              )
            },
            receiveCompletion: { completion in
              guard case .finished = completion else { return }
              transferState.value = updatedState
            }
          )
          .ignoreOutput()
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        }
        else {
          diagnostics.diagnosticLog("...processing succeeded, continuing transfer...")
          return requestNextPage(
            for: updatedState,
            using: networkClient
          )
          .handleEvents(receiveCompletion: { completion in
            guard case .finished = completion else { return }
            transferState.value = updatedState
          })
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        }
      case let .failure(error)
      where error.identifier == .canceled:
        diagnostics.diagnosticLog("...processing canceled!")
        return Fail<Never, TheErrorLegacy>(error: error)
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()

      case let .failure(error)
      where error.identifier == .accountTransferScanningRecoverableError:
        diagnostics.diagnosticLog("...processing failed, recoverable!")
        return Fail<Never, TheErrorLegacy>(error: error)
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()

      case let .failure(error):
        diagnostics.diagnosticLog("...processing failed, aborting!")
        if let configuration: AccountTransferConfiguration = transferState.value.configuration {
          return requestCancelation(
            with: configuration,
            lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
            using: networkClient,
            causedByError: error
          )
          .handleEvents(receiveCompletion: { completion in
            guard case let .failure(error) = completion
            else { unreachable("Cannot complete without an error when processing error") }
            transferState.send(completion: .failure(error))
            features.unload(Self.self)
          })
          .ignoreOutput()  // we care only about completion or failure
          .collectErrorLog(using: diagnostics)
          .eraseToAnyPublisher()
        }
        else {  // we can't cancel if we don't have configuration yet
          transferState.send(completion: .failure(error))
          features.unload(Self.self)
          return Fail<Never, TheErrorLegacy>(error: error)
            .collectErrorLog(using: diagnostics)
            .eraseToAnyPublisher()
        }
      }
    }

    let processPayload: (String) -> AnyPublisher<Never, TheErrorLegacy> = { [unowned features] payload in
      _processPayload(payload, using: features)
    }

    func completeTransfer(_ passphrase: Passphrase) -> AnyPublisher<Never, TheErrorLegacy> {
      diagnostics.diagnosticLog("Completing account transfer...")
      guard
        let configuration = transferState.value.configuration,
        let account = transferState.value.account,
        let profile = transferState.value.profile
      else {
        diagnostics.diagnosticLog("...missing required data!")
        return Fail<Never, TheErrorLegacy>(
          error: .accountTransferScanningRecoverableError(
            context: "account-transfer-complete-invalid-state"
          )
        )
        .eraseToAnyPublisher()
      }
      return
        accounts
        .transferAccount(
          configuration.domain,
          account.userID,
          profile.username,
          profile.firstName,
          profile.lastName,
          profile.avatarImageURL,
          account.fingerprint,
          account.armoredKey,
          passphrase
        )
        .handleEvents(receiveCompletion: { [weak features] completion in
          switch completion {
          case .finished:
            diagnostics.diagnosticLog("...account transfer succeeded!")
            transferState.send(completion: .finished)
            features?.unload(Self.self)
          case let .failure(error)
          where error.identifier == .duplicateAccount:
            diagnostics.diagnosticLog("...account transfer failed!")
            transferState.send(completion: .failure(error))
            features?.unload(Self.self)

          case .failure:
            diagnostics.diagnosticLog("...account transfer failed!")
          }
        })
        .ignoreOutput()
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
    }

    // swift-format-ignore: NoLeadingUnderscores
    func _cancelTransfer(using features: FeatureFactory) {
      if let configuration: AccountTransferConfiguration = transferState.value.configuration,
        !transferState.value.scanningFinished
      {
        transferCancelationCancellable = requestCancelation(
          with: configuration,
          lastPage: transferState.value.lastScanningPage ?? transferState.value.configurationScanningPage,
          using: networkClient
        )
        .collectErrorLog(using: diagnostics)
        // we don't care about response, user exits process anyway
        .sink(receiveCompletion: { _ in }, receiveValue: { _ in })
      }
      else { /* we can't cancel if we don't have configuration yet */
      }
      transferState.send(
        completion: .failure(
          .canceled.appending(context: "account-transfer-scanning-cancel")
        )
      )
      features.unload(Self.self)
    }
    let cancelTransfer: () -> Void = { [unowned features] in
      _cancelTransfer(using: features)
    }

    func featureUnload() -> Bool {
      diagnostics.diagnosticLog("...account transfer process closed!")
      #if DEBUG
      _ =
        progressPublisher
        .receive(on: ImmediateScheduler.shared)
        .sink(
          receiveCompletion: { _ in /* expected */ },
          receiveValue: { _ in
            assertionFailure("\(Self.self) has to have finished (either completed or canceled) scanning to be unloaded")
          }
        )
      #endif
      return true  // we should unload this feature after use and it always succeeds
    }

    return Self(
      progressPublisher: { progressPublisher },
      accountDetailsPublisher: { accountDetailsPublisher },
      processPayload: processPayload,
      completeTransfer: completeTransfer,
      avatarPublisher: { mediaPublisher },
      cancelTransfer: cancelTransfer,
      featureUnload: featureUnload
    )
  }

  #if DEBUG
  // placeholder implementation for mocking and testing, unavailable in release
  public static var placeholder: Self {
    Self(
      progressPublisher: unimplemented("You have to provide mocks for used methods"),
      accountDetailsPublisher: unimplemented("You have to provide mocks for used methods"),
      processPayload: unimplemented("You have to provide mocks for used methods"),
      completeTransfer: unimplemented("You have to provide mocks for used methods"),
      avatarPublisher: unimplemented("You have to provide mocks for used methods"),
      cancelTransfer: unimplemented("You have to provide mocks for used methods"),
      featureUnload: unimplemented("You have to provide mocks for used methods")
    )
  }
  #endif
}

private func processQRCodePayload(
  _ rawPayload: String,
  in state: AccountTransferState
) -> Result<AccountTransferState, TheErrorLegacy> {
  // If state is completed (transferFinished) then we don't expect any next page
  guard let expectedPage: Int = state.nextScanningPage
  else {
    return .failure(
      .canceled
        .appending(context: "account-transfer-scanning-unexpected-page")
        .appending(logMessage: "Processing unexpected page - ignored")
    )
  }

  switch decodeQRCodePart(rawPayload, expectedPage: expectedPage) {
  case let .success(part):
    return updated(state: state, with: part)
  case let .failure(error):
    return .failure(error)
  }
}

private func decodeQRCodePart(
  _ rawPayload: String,
  expectedPage: Int
) -> Result<AccountTransferScanningPart, TheErrorLegacy> {
  switch AccountTransferScanningPart.from(qrCode: rawPayload) {
  case let .success(part):
    // Verify if decoded page number is the same as expected
    if part.page == expectedPage {
      /* continue */
    }
    else if part.page == expectedPage - 1 {
      // if we still get previous page we ignore it
      return .failure(
        .canceled
          .appending(
            context: "account-transfer-scanning-repeated-page"
          )
          .appending(
            logMessage: "Repeated QRCode page number"
          )
      )
    }
    else {
      return .failure(
        .accountTransferScanningError(
          context: "decoding-invalid-page"
        )
        .appending(
          logMessage: "Invalid QRCode page"
        )
      )
    }
    return .success(part)
  case let .failure(error):
    return .failure(error)
  }
}

private func updated(
  state: AccountTransferState,
  with part: AccountTransferScanningPart
) -> Result<AccountTransferState, TheErrorLegacy> {
  var state: AccountTransferState = state  // make state mutable in scope
  state.scanningParts.append(part)

  switch part.page {
  case 0:
    switch AccountTransferConfiguration.from(part) {
    case let .success(configuration):
      state.configuration = configuration
      return .success(state)
    case let .failure(error):
      return .failure(error)
    }

  case _:
    if state.nextScanningPage == nil {
      guard let hash = state.configuration?.hash, !hash.isEmpty
      else {
        return .failure(
          .accountTransferScanningError(context: "missing-configuration-or-hash")
            .appending(logMessage: "Missing verification hash")
        )
      }
      switch AccountTransferAccount.from(
        Array(state.scanningParts[1..<state.scanningParts.count]),
        verificationHash: hash
      ) {
      case let .success(account):
        state.account = account
        return .success(state)
      case let .failure(error):
        return .failure(error)
      }
    }
    else {
      return .success(state)
    }
  }
}

private func requestNextPage(
  for state: AccountTransferState,
  using networkClient: NetworkClient
) -> AnyPublisher<Never, TheErrorLegacy> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<Never, TheErrorLegacy>(
      error: .accountTransferScanningError(context: "next-page-request-missing-configuration")
        .appending(logMessage: "Missing account transfer configuration")
    )
    .eraseToAnyPublisher()
  }
  return networkClient
    .accountTransferUpdate
    .make(
      using: AccountTransferUpdateRequestVariable(
        domain: configuration.domain,
        authenticationToken: configuration.authenticationToken,
        transferID: configuration.transferID,
        currentPage: state.nextScanningPage
          ?? state.lastScanningPage
          ?? state.configurationScanningPage,
        status: state.scanningFinished ? .complete : .inProgress,
        requestUserProfile: false
      )
    )
    .mapErrorsToLegacy()
    .ignoreOutput()
    .mapError { $0.appending(context: "next-page-request") }
    .eraseToAnyPublisher()
}

private func requestNextPageWithUserProfile(
  for state: AccountTransferState,
  using networkClient: NetworkClient
) -> AnyPublisher<AccountTransferUpdateResponseBody.User, TheErrorLegacy> {
  guard let configuration: AccountTransferConfiguration = state.configuration
  else {
    return Fail<AccountTransferUpdateResponseBody.User, TheErrorLegacy>(
      error: .accountTransferScanningError(context: "next-page-request-missing-configuration")
        .appending(logMessage: "Missing account transfer configuration")
    )
    .eraseToAnyPublisher()
  }
  return networkClient
    .accountTransferUpdate
    .make(
      using: AccountTransferUpdateRequestVariable(
        domain: configuration.domain,
        authenticationToken: configuration.authenticationToken,
        transferID: configuration.transferID,
        currentPage: state.nextScanningPage
          ?? state.lastScanningPage
          ?? state.configurationScanningPage,
        status: state.scanningFinished ? .complete : .inProgress,
        requestUserProfile: true
      )
    )
    .mapErrorsToLegacy()
    .map { response -> AnyPublisher<AccountTransferUpdateResponseBody.User, TheErrorLegacy> in
      if let user: AccountTransferUpdateResponseBody.User = response.body.user {
        return Just(user)
          .setFailureType(to: TheErrorLegacy.self)
          .eraseToAnyPublisher()
      }
      else {
        return Fail<AccountTransferUpdateResponseBody.User, TheErrorLegacy>(
          error: .accountTransferScanningError(context: "next-page-request-missing-user-profile")
            .appending(logMessage: "Missing user profile data")
        )
        .eraseToAnyPublisher()
      }
    }
    .switchToLatest()
    .mapError { $0.appending(context: "next-page-request") }
    .eraseToAnyPublisher()
}

private func requestCancelation(
  with configuration: AccountTransferConfiguration,
  lastPage: Int,
  using networkClient: NetworkClient,
  causedByError error: TheErrorLegacy? = nil
) -> AnyPublisher<Never, TheErrorLegacy> {
  let responsePublisher: AnyPublisher<Void, TheErrorLegacy> = networkClient
    .accountTransferUpdate
    .make(
      using: AccountTransferUpdateRequestVariable(
        domain: configuration.domain,
        authenticationToken: configuration.authenticationToken,
        transferID: configuration.transferID,
        currentPage: lastPage,
        status: error == nil ? .cancel : .error,
        requestUserProfile: false
      )
    )
    .mapErrorsToLegacy()
    .mapToVoid()
    .eraseToAnyPublisher()
  if let error: TheErrorLegacy = error {
    return
      responsePublisher
      .flatMap { _ in Fail<Void, TheErrorLegacy>(error: error) }
      .ignoreOutput()
      .eraseToAnyPublisher()
  }
  else {
    return
      responsePublisher
      .ignoreOutput()
      .mapError { error in
        error.appending(context: "account-transfer-scanning-cancelation-request")
      }
      .eraseToAnyPublisher()
  }
}

extension AccountTransfer {

  public enum Progress {

    case configuration
    case scanningProgress(Double)
    case scanningFinished
  }
}
