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

import Commons
import Crypto
import Features
import class Foundation.JSONEncoder
import class Foundation.JSONDecoder
import struct Foundation.Data
import NetworkClient

#warning("PAS-154: Write tests")
public struct SignIn {
  
  public var signIn: (
    _ userID: Account.UserID,
    _ domain: String,
    _ armoredKey: ArmoredPrivateKey,
    _ passphrase: Passphrase
    ) -> AnyPublisher<SessionTokens, TheError>
}

extension SignIn: Feature {

  public typealias Environment = (
    uuidGenerator: UUIDGenerator,
    time: Time,
    pgp: PGP,
    signatureVerification: SignatureVerfication
  )

  public static func environmentScope(
    _ rootEnvironment: RootEnvironment
  ) -> Environment {
    (
      rootEnvironment.uuidGenerator,
      rootEnvironment.time,
      rootEnvironment.pgp,
      rootEnvironment.signatureVerification
    )
  }

  public static func load(
    in environment: Environment,
    using features: FeatureFactory,
    cancellables: Cancellables
  ) -> SignIn {
    let networkClient: NetworkClient = features.instance()
    let diagnostics: Diagnostics = features.instance()
    
    func signIn(
      userID: Account.UserID,
      domain: String,
      armoredKey: ArmoredPrivateKey,
      passphrase: Passphrase
    ) -> AnyPublisher<SessionTokens, TheError> {
      let encoder: JSONEncoder = .init()
      let decoder: JSONDecoder = .init()
      
      #warning("PAS-154 - determine what is 'version'")
      let challenge: LoginRequestChallenge = .init(
        version: "1.0.0",
        token: environment.uuidGenerator().uuidString,
        domain: domain,
        expiration: environment.time.timestamp() + 120 // 120s is verification token's lifetime
      )
      
      let serverPgpPublicKey: AnyPublisher<ArmoredPublicKey, TheError> =
        networkClient.serverPgpPublicKeyRequest.make(using: ())
        .map { (response: ServerPgpPublicKeyResponse) -> ArmoredPublicKey in
          ArmoredPublicKey(rawValue: response.body.keyData)
        }
        .eraseToAnyPublisher()
      
      let jwtStep: AnyPublisher<String, TheError> = serverPgpPublicKey
        .map { (publicKey: ArmoredPublicKey) -> AnyPublisher<ArmoredMessage, TheError> in
          let encoded: Data
          
          do {
            encoded = try encoder.encode(challenge)
          } catch {
            return Fail<ArmoredMessage, TheError>(
              error: .signInError(underlyingError: error)
            )
            .eraseToAnyPublisher()
          }
          
          guard let encodedChallenge: String = .init(bytes: encoded, encoding: .utf8) else {
            return Fail<ArmoredMessage, TheError>(
              error: .signInError().appending(logMessage: "JWT: Failed to encode challenge")
            )
            .eraseToAnyPublisher()
          }

          let encryptedAndSigned: String
          
          switch environment.pgp.encryptAndSign(encodedChallenge, passphrase, armoredKey, publicKey) {
          // swiftlint:disable:next explicit_type_interface
          case let .success(result):
            encryptedAndSigned = result
          
          // swiftlint:disable:next explicit_type_interface
          case let .failure(error):
            return Fail(error: error.appending(logMessage: "Failed to encrypt and sign"))
              .eraseToAnyPublisher()
          }

          return Just<ArmoredMessage>(.init(rawValue: encryptedAndSigned))
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map { (challenge: ArmoredMessage) -> AnyPublisher<LoginResponse, TheError> in
          networkClient.loginRequest.make(
            using: .init(
              userID: userID.rawValue,
              challenge: challenge
            )
          )
        }
        .switchToLatest()
        .map { response -> String in
          response.body.challenge
        }
        .eraseToAnyPublisher()
      
      let rsaPublicKeyStep: AnyPublisher<String, TheError> =
        networkClient.serverRsaPublicKeyRequest.make(using: ())
        .map(\.body.keyData)
        .eraseToAnyPublisher()
      
      let decryptedToken: AnyPublisher<Tokens, TheError> = Publishers.Zip(jwtStep, serverPgpPublicKey)
        .map { encryptedTokenPayload, publicKey -> AnyPublisher<String, TheError> in
          let decrypted: String
          
          switch environment.pgp.decryptAndVerify(encryptedTokenPayload, passphrase, armoredKey, publicKey) {
          // swiftlint:disable:next explicit_type_interface
          case let .success(result):
            decrypted = result
            
          // swiftlint:disable:next explicit_type_interface
          case let .failure(error):
            return Fail<String, TheError>(
              error: error.appending(logMessage: "Unable to decrypt and verify")
            )
            .eraseToAnyPublisher()
          }
          
          return Just<String>(decrypted)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .map { token -> AnyPublisher<Tokens, TheError> in
          let tokenData: Data = token.data(using: .utf8) ?? Data()
          let tokens: Tokens
          
          do {
            tokens = try decoder.decode(Tokens.self, from: tokenData)
          } catch {
            return Fail<Tokens, TheError>.init(
              error: .signInError(underlyingError: error)
            )
            .eraseToAnyPublisher()
          }
          
          return Just<Tokens>(tokens)
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    
      return Publishers.Zip(rsaPublicKeyStep, decryptedToken)
        .map { (publicKey: String, decryptedToken: Tokens) -> AnyPublisher<SessionTokens, TheError> in
          
          let accessToken: JWT
          switch JWT.from(rawValue: decryptedToken.accessToken) {
          // swiftlint:disable:next explicit_type_interface
          case let .success(jwt):
            accessToken = jwt
            
          // swiftlint:disable:next explicit_type_interface
          case let .failure(error):
            return Fail<SessionTokens, TheError>(
              error: .signInError(underlyingError: error).appending(logMessage: "Failed to prepare for signature verification")
            )
            .eraseToAnyPublisher()
          }
          
          guard challenge.token == decryptedToken.verificationToken,
            challenge.expiration > environment.time.timestamp(),
            let key: Data = Data(base64Encoded: publicKey.stripArmoredFormat()),
            let signature: Data = accessToken.signature.base64DecodeFromURLEncoded(),
            let signedData: Data = accessToken.signedPayload.data(using: .utf8)
          else {
            return Fail<SessionTokens, TheError>(
              error: .signInError().appending(logMessage: "Failed to prepare for signature verification")
            )
            .eraseToAnyPublisher()
          }
          
          switch environment.signatureVerification.verify(signedData, signature, key) {
          case .success:
            return Just(
              SessionTokens(accessToken: accessToken, refreshToken: decryptedToken.refreshToken)
            )
            .setFailureType(to: TheError.self)
            .eraseToAnyPublisher()
            
          // swiftlint:disable:next explicit_type_interface
          case let .failure(error):
            return Fail<SessionTokens, TheError>(
              error: error.appending(logMessage: "Signature verification failed")
            )
            .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .collectErrorLog(using: diagnostics)
        .eraseToAnyPublisher()
    }
    
    return Self(signIn: signIn)
  }
}

#if DEBUG
extension SignIn {
  
  public static var placeholder: SignIn {
    Self(signIn: Commons.placeholder("You have to provide mocks for used methods"))
  }
}
#endif