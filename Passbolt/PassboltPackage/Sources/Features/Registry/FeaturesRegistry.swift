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

public struct FeaturesRegistry {

  private var statics: Dictionary<FeatureIdentifier, StaticFeature> = .init()
  private var scopes: Dictionary<FeaturesScopeIdentifier, Dictionary<FeatureIdentifier, FeatureLoader>> = .init()
}

extension FeaturesRegistry {

  public mutating func use<Feature>(
    _ feature: Feature
  ) where Feature: StaticFeature {
    self.statics[feature.identifier] = feature
  }

  public mutating func use<Scope>(
    _ loader: FeatureLoader,
    in scope: Scope.Type
  ) where Scope: FeaturesScope {
    var loaders: Dictionary<FeatureIdentifier, FeatureLoader> = self.scopes[scope.identifier] ?? .init()
    loaders[loader.identifier] = loader
    self.scopes[scope.identifier] = loaders
  }

  public mutating func use(
    _ loader: FeatureLoader
  ) {
    var loaders: Dictionary<FeatureIdentifier, FeatureLoader> = self.scopes[RootFeaturesScope.identifier] ?? .init()
    loaders[loader.identifier] = loader
    self.scopes[RootFeaturesScope.identifier] = loaders
  }
}

extension FeaturesRegistry {

  internal func staticFeatures() -> Dictionary<FeatureIdentifier, StaticFeature> {
    self.statics
  }

  internal func featureLoaders<Scope>(
    for scope: Scope.Type
  ) -> Dictionary<FeatureIdentifier, FeatureLoader>
  where Scope: FeaturesScope {
    self.scopes[scope.identifier] ?? .init()
  }

  #if DEBUG  // for tests only
  internal func featureLoader<Feature>(
    for feature: Feature.Type,
    in scope: any FeaturesScope.Type
  ) -> FeatureLoader?
  where Feature: LoadableFeature {
    self.scopes[scope.identifier]?[Feature.identifier]
  }
  #endif
}
