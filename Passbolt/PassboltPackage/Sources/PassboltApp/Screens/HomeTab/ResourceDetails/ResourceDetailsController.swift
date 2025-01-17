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
import OSFeatures
import Resources
import SessionData
import UIComponents

internal struct ResourceDetailsController {

  internal var resourceDetailsWithConfigPublisher: @MainActor () -> AnyPublisher<ResourceDetailsWithConfig, Error>
  internal var toggleDecrypt: @MainActor (ResourceFieldNameDSV) -> AnyPublisher<String?, Error>
  internal var presentResourceMenu: @MainActor () -> Void
  internal var presentResourceShare: @MainActor (Resource.ID) -> Void
  internal var presentResourceEdit: @MainActor (Resource.ID) -> Void
  internal var resourceSharePresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceEditPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var presentDeleteResourceAlert: @MainActor (Resource.ID) -> Void
  internal var resourceMenuPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeleteAlertPresentationPublisher: @MainActor () -> AnyPublisher<Resource.ID, Never>
  internal var resourceDeletionPublisher: @MainActor (Resource.ID) -> AnyPublisher<Void, Error>
  internal var copyFieldValue: @MainActor (ResourceFieldNameDSV) -> AnyPublisher<Void, Error>
}

extension ResourceDetailsController {

  internal struct ResourceDetailsWithConfig: Equatable {

    internal var resourceDetails: ResourceDetailsDSV
    internal var revealPasswordEnabled: Bool
  }
}

extension ResourceDetailsController: UIController {

  internal typealias Context = Resource.ID

  internal static func instance(
    in context: Context,
    with features: inout Features,
    cancellables: Cancellables
  ) throws -> Self {
    features =
      features
      .branch(
        scope: ResourceDetailsScope.self,
        context: context
      )
    let features: Features = features

    let sessionConfiguration: SessionConfiguration = try features.sessionConfiguration()

    let diagnostics: OSDiagnostics = features.instance()
    let resources: Resources = try features.instance()
    let pasteboard: OSPasteboard = features.instance()
    var revealedFields: Set<ResourceFieldNameDSV> = .init()

    let resourceMenuPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceSharePresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceEditPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()
    let resourceDeleteAlertPresentationSubject: PassthroughSubject<Resource.ID, Never> = .init()

    let currentDetailsSubject: CurrentValueSubject<ResourceDetailsWithConfig?, Error> = .init(nil)

    resources.resourceDetailsPublisher(context)
      .asyncMap { resourceDetails in
        var resourceDetails: ResourceDetailsDSV = resourceDetails
        resourceDetails.fields = resourceDetails.fields.sorted(by: { $0.name < $1.name })

        return .init(
          resourceDetails: resourceDetails,
          revealPasswordEnabled: sessionConfiguration.passwordPreviewEnabled
        )
      }
      .sink(
        receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }

          currentDetailsSubject.send(completion: .failure(error))
          diagnostics.log(error: error)
        },
        receiveValue: { resourceDetails in
          currentDetailsSubject.send(resourceDetails)
        }
      )
      .store(in: cancellables)

    func resourceDetailsWithConfigPublisher() -> AnyPublisher<ResourceDetailsWithConfig, Error> {
      currentDetailsSubject
        .filterMapOptional()
        .removeDuplicates()
        .handleEvents(receiveCompletion: { completion in
          guard case let .failure(error) = completion
          else { return }
          diagnostics.log(error: error)
        })
        .eraseToAnyPublisher()
    }

    func toggleDecrypt(fieldName: ResourceFieldNameDSV) -> AnyPublisher<String?, Error> {
      if revealedFields.contains(fieldName) {
        return Just(nil)
          .eraseErrorType()
          .handleEvents(receiveOutput: { _ in
            revealedFields.remove(fieldName)
          })
          .eraseToAnyPublisher()
      }
      else {
        return cancellables.executeAsyncWithPublisher {
          resources
            .loadResourceSecret(context)
            .map { resourceSecret -> String in
              resourceSecret[dynamicMember: fieldName.rawValue] ?? ""
            }
            .handleEvents(receiveOutput: { _ in
              revealedFields.insert(fieldName)
            })
        }
        .switchToLatest()
        .eraseToAnyPublisher()
      }
    }

    func presentResourceMenu() {
      resourceMenuPresentationSubject.send(context)
    }

    func resourceMenuPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceMenuPresentationSubject.eraseToAnyPublisher()
    }

    func copyURLAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let field: ResourceFieldDSV = detailsWithConfig?.resourceDetails
              .fields
              .first(where: { $0.name == .uri })
          else {
            return Fail<Void, Error>(error: InvalidResourceData.error())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeAsyncWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just("")
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else {
                    return Fail(error: InvalidResourceSecret.error())
                      .eraseToAnyPublisher()
                  }
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { value in
                  pasteboard.put(value)
                })
                .mapToVoid()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.url {
            return Just(Void())
              .eraseErrorType()
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: MissingResourceData.error())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyPasswordAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let field: ResourceFieldDSV = detailsWithConfig?.resourceDetails
              .fields
              .first(where: { $0.name == .password })
          else {
            return Fail<Void, Error>(error: InvalidResourceData.error())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeAsyncWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just("")
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else {
                    return Fail(error: InvalidResourceSecret.error())
                      .eraseToAnyPublisher()
                  }
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { value in
                  pasteboard.put(value)
                })
                .mapToVoid()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
          }
          else {
            return Fail(error: MissingResourceData.error())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyUsernameAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let field: ResourceFieldDSV = detailsWithConfig?.resourceDetails
              .fields
              .first(where: { $0.name == .username })
          else {
            return Fail<Void, Error>(error: InvalidResourceData.error())
              .eraseToAnyPublisher()
          }

          if field.encrypted {
            return cancellables.executeAsyncWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: field.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !field.required {
                    return Just("")
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else {
                    return Fail(error: InvalidResourceSecret.error())
                      .eraseToAnyPublisher()
                  }
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { value in
                  pasteboard.put(value)
                })
                .mapToVoid()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.username {
            return Just(Void())
              .eraseErrorType()
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: InvalidResourceData.error())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyDescriptionAction() -> AnyPublisher<Void, Error> {
      currentDetailsSubject
        .first()
        .map { detailsWithConfig -> AnyPublisher<Void, Error> in
          guard
            let resourceDetails = detailsWithConfig?.resourceDetails,
            let property: ResourceFieldDSV = detailsWithConfig?.resourceDetails
              .fields
              .first(where: { $0.name == .description })
          else {
            return Fail<Void, Error>(error: InvalidResourceData.error())
              .eraseToAnyPublisher()
          }

          if property.encrypted {
            return cancellables.executeAsyncWithPublisher {
              resources
                .loadResourceSecret(resourceDetails.id)
                .map { resourceSecret -> AnyPublisher<String, Error> in
                  if let secret: String = resourceSecret[dynamicMember: property.name.rawValue] {
                    return Just(secret)
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else if !property.required {
                    return Just("")
                      .eraseErrorType()
                      .eraseToAnyPublisher()
                  }
                  else {
                    return Fail(error: InvalidResourceSecret.error())
                      .eraseToAnyPublisher()
                  }
                }
                .switchToLatest()
                .handleEvents(receiveOutput: { value in
                  pasteboard.put(value)
                })
                .mapToVoid()
            }
            .switchToLatest()
            .eraseToAnyPublisher()
          }
          else if let value: String = resourceDetails.description {
            return Just(Void())
              .eraseErrorType()
              .handleEvents(receiveOutput: { _ in
                pasteboard.put(value)
              })
              .eraseToAnyPublisher()
          }
          else {
            return Fail(error: InvalidResourceData.error())
              .eraseToAnyPublisher()
          }
        }
        .switchToLatest()
        .eraseToAnyPublisher()
    }

    func copyField(
      _ fieldName: ResourceFieldNameDSV
    ) -> AnyPublisher<Void, Error> {
      switch fieldName {
      case .uri:
        return copyURLAction()

      case .password:
        return copyPasswordAction()

      case .username:
        return copyUsernameAction()

      case .description:
        return copyDescriptionAction()

      case _:
        assertionFailure("Unhandled resource field - \(fieldName)")
        return Fail(error: InvalidResourceData.error())
          .eraseToAnyPublisher()
      }
    }

    func presentResourceShare(
      resourceID: Resource.ID
    ) {
      resourceSharePresentationSubject.send(resourceID)
    }

    func resourceSharePresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceSharePresentationSubject.eraseToAnyPublisher()
    }

    func presentResourceEdit(resourceID: Resource.ID) {
      resourceEditPresentationSubject.send(resourceID)
    }

    func resourceEditPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceEditPresentationSubject.eraseToAnyPublisher()
    }

    func presentDeleteResourceAlert(resourceID: Resource.ID) {
      resourceDeleteAlertPresentationSubject.send(resourceID)
    }

    func resourceDeleteAlertPresentationPublisher() -> AnyPublisher<Resource.ID, Never> {
      resourceDeleteAlertPresentationSubject.eraseToAnyPublisher()
    }

    func resourceDeletionPublisher(resourceID: Resource.ID) -> AnyPublisher<Void, Error> {
      cancellables.executeAsyncWithPublisher {
        resources.deleteResource(resourceID)
      }
      .switchToLatest()
      .eraseToAnyPublisher()
    }

    return Self(
      resourceDetailsWithConfigPublisher: resourceDetailsWithConfigPublisher,
      toggleDecrypt: toggleDecrypt(fieldName:),
      presentResourceMenu: presentResourceMenu,
      presentResourceShare: presentResourceShare(resourceID:),
      presentResourceEdit: presentResourceEdit(resourceID:),
      resourceSharePresentationPublisher: resourceSharePresentationPublisher,
      resourceEditPresentationPublisher: resourceEditPresentationPublisher,
      presentDeleteResourceAlert: presentDeleteResourceAlert(resourceID:),
      resourceMenuPresentationPublisher: resourceMenuPresentationPublisher,
      resourceDeleteAlertPresentationPublisher: resourceDeleteAlertPresentationPublisher,
      resourceDeletionPublisher: resourceDeletionPublisher(resourceID:),
      copyFieldValue: copyField(_:)
    )
  }
}
