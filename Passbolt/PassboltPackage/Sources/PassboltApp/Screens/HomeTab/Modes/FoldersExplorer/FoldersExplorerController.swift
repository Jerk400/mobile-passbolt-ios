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
import SharedUIComponents
import UIComponents

@MainActor
internal struct FoldersExplorerController {

  internal let viewState: ObservableValue<ViewState>
  internal var refreshIfNeeded: @MainActor () async -> Void
  internal var presentFolderContent: @MainActor (ResourceFolderListItemDSV) -> Void
  internal var presentResourceCreationFrom: @MainActor (ResourceFolder.ID?) -> Void
  internal var presentResourceDetails: @MainActor (Resource.ID) -> Void
  internal var presentResourceMenu: @MainActor (Resource.ID) async -> Void
  internal var presentHomePresentationMenu: @MainActor () async -> Void
  internal var presentAccountMenu: @MainActor () async -> Void
}

extension FoldersExplorerController: ComponentController {

  internal typealias ControlledView = FoldersExplorerView
  internal typealias NavigationContext = ResourceFolderListItemDSV?

  internal static func instance(
    context: NavigationContext,
    navigation: ComponentNavigation<NavigationContext>,
    with features: FeatureFactory,
    cancellables: Cancellables
  ) async throws -> Self {
    let diagnostics: Diagnostics = try await features.instance()
    let accountSettings: AccountSettings = try await features.instance()
    let resources: Resources = try await features.instance()
    let sessionData: AccountSessionData = try await features.instance()
    let folders: ResourceFolders = try await features.instance()

    let viewState: ObservableValue<ViewState>

    if let folder: ResourceFolderListItemDSV = context {
      viewState = .init(
        initial: .init(
          title: .raw(folder.name),
          folderID: folder.id,
          folderShared: folder.shared,
          // temporarily disable create in shared folders
          canCreateResources: !folder.shared && folder.permissionType != .read  // write / owned
        )
      )
    }
    else {
      viewState = .init(
        initial: .init(
          title: .localized(key: "home.presentation.mode.folders.explorer.title"),
          folderShared: false,
          canCreateResources: true
        )
      )
    }

    // get the the user avatar image
    cancellables.executeOnMainActor {
      // ignore errors on getting avatar
      viewState.userAvatarImage =
        try? await accountSettings
        .currentAccountAvatarPublisher()
        .asAsyncValue()
    }

    // refresh the list based on filters data
    cancellables.executeOnMainActor {
      let filterSequence: AnyAsyncSequence<ResourceFoldersFilter> =
        viewState
        .valuePublisher
        .map { filter in
          ResourceFoldersFilter(
            sorting: .nameAlphabetically,
            text: filter.searchText,
            folderID: context?.id,
            flattenContent: !filter.searchText.isEmpty,
            permissions: .init()
          )
        }
        .asAnyAsyncSequence()

      try await folders
        .filteredFolderContent(filterSequence)
        .forLatest { content in
          viewState.withValue { state in
            state.directFolders = content
              .subfolders
              .filter { $0.parentFolderID == context?.id }
            state.nestedFolders = content
              .subfolders
              .filter { $0.parentFolderID != context?.id }
            state.directResources = content
              .resources
              .filter { $0.parentFolderID == context?.id }
            state.nestedResources = content
              .resources
              .filter { $0.parentFolderID != context?.id }
          }
        }
    }

    @MainActor func refreshIfNeeded() async {
      // TODO: [MOB-255] check if current folder was not deleted
      do {
        try await sessionData
          .refreshIfNeeded()
      }
      catch {
        diagnostics.log(error)
        viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
      }
    }

    @MainActor func presentFolderContent(_ folder: ResourceFolderListItemDSV) {
      cancellables.executeOnMainActor {
        await navigation.push(
          FoldersExplorerView.self,
          in: folder
        )
      }
    }

    @MainActor func presentResourceCreationFrom(
      folderID: ResourceFolder.ID?
    ) {
      presentResourceEditingForm(for: .new(in: folderID))
    }

    @MainActor func presentResourceEditingForm(
      for context: ResourceEditController.EditingContext
    ) {
      cancellables.executeOnMainActor {
        await navigation.push(
          ResourceEditViewController.self,
          in: (
            context,
            completion: { _ in
              viewState.snackBarMessage = .info(
                .localized(
                  key: "resource.form.new.password.created"
                )
              )
            }
          )
        )
      }
    }

    @MainActor func presentResourceDetails(_ resourceID: Resource.ID) {
      cancellables.executeOnMainActor {
        await navigation.push(
          ResourceDetailsViewController.self,
          in: resourceID
        )
      }
    }

    @MainActor func presentResourceMenu(_ resourceID: Resource.ID) async {
      await navigation.presentSheetMenu(
        ResourceMenuViewController.self,
        in: (
          resourceID: resourceID,
          showEdit: { (resourceID: Resource.ID) in
            cancellables.executeOnMainActor {
              await navigation
                .dismiss(
                  SheetMenuViewController<ResourceMenuViewController>.self,
                  completion: {
                    presentResourceEditingForm(for: .existing(resourceID))
                  }
                )
            }
          },
          showDeleteAlert: { (resourceID: Resource.ID) in
            cancellables.executeOnMainActor {
              await navigation
                .dismiss(
                  SheetMenuViewController<ResourceMenuViewController>.self
                )
              await navigation.present(
                ResourceDeleteAlert.self,
                in: {
                  Task {
                    do {
                      try await resources
                        .deleteResource(resourceID)
                        .asAsyncValue()
                    }
                    catch {
                      viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
                    }
                  }
                }
              )
            }
          }
        )
      )
    }

    @MainActor func presentHomePresentationMenu() async {
      await navigation.presentSheet(
        HomePresentationMenuView.self,
        in: .foldersExplorer
      )
    }

    @MainActor func presentAccountMenu() async {
      do {
        let accountWithProfile: AccountWithProfile =
          try await accountSettings
          .currentAccountProfilePublisher()
          .asAsyncValue()

        await navigation.presentSheet(
          AccountMenuViewController.self,
          in: (
            accountWithProfile: accountWithProfile,
            navigation: navigation.asContextlessNavigation()
          )
        )
      }
      catch {
        viewState.snackBarMessage = .error(error.asTheError().displayableMessage)
      }
    }

    return Self(
      viewState: viewState,
      refreshIfNeeded: refreshIfNeeded,
      presentFolderContent: presentFolderContent(_:),
      presentResourceCreationFrom: presentResourceCreationFrom,
      presentResourceDetails: presentResourceDetails(_:),
      presentResourceMenu: presentResourceMenu(_:),
      presentHomePresentationMenu: presentHomePresentationMenu,
      presentAccountMenu: presentAccountMenu
    )
  }
}