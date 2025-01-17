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

import UIComponents
import XCTest

@testable import Features

/// Base class for preparing unit tests of features.
@MainActor
open class LoadableFeatureTestCase<Feature>: AsyncTestCase
where Feature: LoadableFeature {

  open class var testedImplementationScope: any FeaturesScope.Type {
    RootFeaturesScope.self
  }

  open class var testedImplementation: FeatureLoader? {
    .none
  }

  open class func testedImplementationRegister(
    _ registry: inout FeaturesRegistry
  ) {
    fatalError("You have to override either `testedImplementation` or `testedImplementationRegister`")
  }

  public private(set) var mockExecutionControl: AsyncExecutor.MockExecutionControl!
  private var features: TestFeaturesContainer!
  private var instance: Feature!
  private var contextIdentifier: AnyHashable!
  public private(set) var cancellables: Cancellables!

  private lazy var testedImplementation: FeatureLoader = {
    if let implementation: FeatureLoader = Self.testedImplementation {
      return implementation
    }
    else {
      var registry: FeaturesRegistry = .init()
      Self.testedImplementationRegister(&registry)
      if let loader: FeatureLoader = registry.featureLoader(
        for: Feature.self,
        in: Self.testedImplementationScope
      ) {
        return loader
      }
      else {
        return .init(
          identifier: Feature.identifier,
          cache: false,
          load: { _, _, _ in
            throw
              FeatureUndefined
              .error(
                "Tested feature is not defined, most likely its loader is using custom Scope, please define required scope by overriding `testedImplementationScope`",
                featureName: "\(Feature.self)"
              )
          }
        )
      }
    }
  }()

  open func prepare() throws {
    // to override
  }

  // prevent overriding
  public final override func setUp() async throws {
    try await super.setUp()

    self.mockExecutionControl = .init()
    self.features = .init()
    self.features
      .patch(
        \OSDiagnostics.self,
        with: OSDiagnostics.disabled
      )

    self.features
      .patch(
        \AsyncExecutor.self,
        with: .mock(self.mockExecutionControl)
      )
    self.cancellables = .init()
    do {
      try self.prepare()
    }
    catch {
      XCTFail("\(error)")
    }
  }

  open func cleanup() throws {
    // to override
  }

  // prevent overriding
  public final override func tearDown() async throws {
    do {
      try self.cleanup()
    }
    catch {
      XCTFail("\(error)")
    }
    self.mockExecutionControl = .none
    self.features = .none
    self.instance = .none
    self.contextIdentifier = .none
    self.cancellables = .none
    try await super.tearDown()
  }

  // prevent overriding
  public final override func setUp() {
    super.setUp()
  }

  // prevent overriding
  public final override func setUpWithError() throws {
    try super.setUpWithError()
  }

  // prevent overriding
  public final override func tearDown() {
    super.tearDown()
  }
}

extension LoadableFeatureTestCase {

  @available(*, deprecated, message: "UIController should be migrated to a proper feature")
  public final func testController<Controller: UIController>(
    _ type: Controller.Type = Controller.self,
    context: Controller.Context
  ) throws -> Controller {
    var features: Features = self.features
    return try Controller.instance(
      in: context,
      with: &features,
      cancellables: cancellables
    )
  }

  @available(*, deprecated, message: "UIController should be migrated to a proper feature")
  public final func testController<Controller: UIController>(
    _ type: Controller.Type = Controller.self
  ) throws -> Controller
  where Controller.Context == Void {
    var features: Features = self.features
    return try Controller.instance(
      in: Void(),
      with: &features,
      cancellables: cancellables
    )
  }

  public final func testedInstance(
    context: Feature.Context
  ) throws -> Feature {
    if let instance: Feature = self.instance {
      precondition(
        self.contextIdentifier == context.identifier,
        "Cannot use more than one context in a single test."
      )
      return instance
    }
    else {
      let instance: Feature = try self.testedImplementation.load(self.features, context, self.cancellables) as! Feature
      self.instance = instance
      self.contextIdentifier = context.identifier
      return instance
    }
  }

  public final func testedInstance() throws -> Feature
  where Feature.Context == ContextlessFeatureContext {
    try self.testedInstance(
      context: ContextlessFeatureContext.instance
    )
  }

  public func set<Scope>(
    _ scope: Scope.Type,
    context: Scope.Context
  ) where Scope: FeaturesScope {
    self.features
      .set(
        scope,
        context: context
      )
  }

  public func set<Scope>(
    _ scope: Scope.Type
  ) where Scope: FeaturesScope, Scope.Context == Void {
    self.features
      .set(scope)
  }

  public func usePlaceholder<Feature>(
    for _: Feature.Type,
    context: Feature.Context
  ) where Feature: LoadableFeature {
    self.features
      .usePlaceholder(
        for: Feature.self,
        context: context
      )
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: LoadableFeature, Feature.Context == ContextlessFeatureContext {
    self.features
      .usePlaceholder(for: Feature.self)
  }

  public func usePlaceholder<Feature>(
    for featureType: Feature.Type
  ) where Feature: StaticFeature {
    self.features
      .usePlaceholder(for: Feature.self)
  }

  public final func set<Value>(
    variable keyPath: KeyPath<TestVariables, TestVariables.VariableName>,
    of type: Value.Type = Value.self,
    to value: Optional<Value>
  ) {
    self.variables.set(
      keyPath,
      of: Optional<Value>.self,
      to: value
    )
  }

  public final func variable<Value>(
    _ keyPath: KeyPath<TestVariables, TestVariables.VariableName>,
    of type: Value.Type = Value.self
  ) -> Value {
    self.variables.get(
      keyPath,
      of: Value.self
    )
  }

  public private(set) nonisolated final var executed: @Sendable () -> Void {
    get {
      self.variables.get(
        \.executed,
        of: (@Sendable () -> Void).self
      )
    }
    set {
      self.variables.set(
        \.executed,
        of: (@Sendable () -> Void).self,
        to: newValue
      )
    }
  }

  @Sendable public nonisolated func executed<Value>(
    returning value: Value
  ) -> Value {
    self.executed()
    return value
  }

  @Sendable public nonisolated func executed<Value>(
    throwing error: Error
  ) throws -> Value {
    self.executed()
    throw error
  }

  @Sendable public nonisolated func executed<Value>(
    with result: Result<Value, Error>
  ) throws -> Value {
    self.executed()
    return try result.get()
  }

  @Sendable public nonisolated func executed<Value>(
    using value: Value
  ) {
    self.executed()
    self.variables.set(
      \.executedUsing,
      of: Value.self,
      to: value
    )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature,
    context: MockFeature.Context
  ) where MockFeature: LoadableFeature {
    guard case .none = self.instance
    else { fatalError("Cannot modify features after creating tested feature instance") }
    self.features
      .patch(
        \MockFeature.self,
        context: context,
        with: instance
      )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: LoadableFeature, MockFeature.Context == ContextlessFeatureContext {
    self.features
      .patch(
        \MockFeature.self,
        with: instance
      )
  }

  public final func use<MockFeature>(
    _ instance: MockFeature
  ) where MockFeature: StaticFeature {
    guard case .none = self.instance
    else { fatalError("Cannot modify features after creating tested feature instance") }
    self.features
      .patch(
        \MockFeature.self,
        with: instance
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    context: MockFeature.Context,
    with value: Value
  ) where MockFeature: LoadableFeature {
    guard case .none = self.instance
    else { fatalError("Cannot patch feature after creating tested feature instance") }
    self.features
      .patch(
        keyPath,
        context: context,
        with: value
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: LoadableFeature, MockFeature.Context == ContextlessFeatureContext {
    self.features
      .patch(
        keyPath,
        with: value
      )
  }

  public func patch<MockFeature, Value>(
    _ keyPath: WritableKeyPath<MockFeature, Value>,
    with value: Value
  ) where MockFeature: StaticFeature {
    guard case .none = self.instance
    else { fatalError("Cannot patch feature after creating tested feature instance") }
    self.features
      .patch(
        keyPath,
        with: value
      )
  }
}

extension LoadableFeatureTestCase {

  public func withTestedInstance(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Void
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstance(
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstance(
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Void
  ) {
    self.asyncTest(
      timeout: timeout,
      file: file,
      line: line
    ) {
      try await test(
        self.testedInstance(context: context)
      )
    }
  }

  public func withTestedInstanceExecuted<Value, Parameter>(
    using parameter: Parameter,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) where Feature.Context == ContextlessFeatureContext, Parameter: Equatable {
    withTestedInstanceExecuted(
      using: parameter,
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceExecuted<Value, Parameter>(
    using expectedParameter: Parameter,
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) where Parameter: Equatable {
    self.asyncTestExecuted(
      count: 1,
      timeout: timeout,
      file: file,
      line: line
    ) { (executed: @escaping @Sendable () -> Void) in
      assert(
        !self.variables.contains(\.executed, of: (@Sendable () -> Void).self),
        "Cannot execute concurrently"
      )
      self.executed = executed
      _ = try await test(
        self.testedInstance(context: context)
      )
      let parameter: Parameter = await self.variable(\.executedUsing)
      XCTAssertEqual(
        parameter,
        expectedParameter,
        "Execution parameter \(parameter as Any) does not match expected (\(expectedParameter)).",
        file: file,
        line: line
      )
      self.variables.clear(\.executed)
      self.variables.clear(\.executedUsing)
    }
  }

  public func withTestedInstanceExecuted<Value>(
    count: UInt = 1,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstanceExecuted(
      count: count,
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceExecuted<Value>(
    count: UInt = 1,
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) {
    self.asyncTestExecuted(
      count: count,
      timeout: timeout,
      file: file,
      line: line
    ) { (executed: @escaping @Sendable () -> Void) in
      assert(
        !self.variables.contains(\.executed, of: (@Sendable () -> Void).self),
        "Cannot execute concurrently"
      )
      self.executed = executed
      _ = try await test(
        self.testedInstance(context: context)
      )
      self.variables.clear(\.executed)
    }
  }

  public func withTestedInstanceNotExecuted<Value>(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstanceNotExecuted(
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceNotExecuted<Value>(
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) {
    self.asyncTestExecuted(
      count: 0,
      timeout: timeout,
      file: file,
      line: line
    ) { (executed: @escaping @Sendable () -> Void) in
      assert(
        !self.variables.contains(\.executed, of: (@Sendable () -> Void).self),
        "Cannot execute concurrently"
      )
      self.executed = executed
      _ = try await test(
        self.testedInstance(context: context)
      )
      self.variables.clear(\.executed)
    }
  }

  public func withTestedInstanceReturnsEqual<Value>(
    _ expectedResult: Value,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value?
  ) where Feature.Context == ContextlessFeatureContext, Value: Equatable {
    withTestedInstanceReturnsEqual(
      expectedResult,
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceReturnsEqual<Value>(
    _ expectedResult: Value,
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value?
  ) where Value: Equatable {
    self.asyncTestReturnsEqual(
      expectedResult,
      timeout: timeout,
      file: file,
      line: line
    ) {
      try await test(
        self.testedInstance(context: context)
      )
    }
  }

  public func withTestedInstanceResultEqual<Value>(
    _ expectedResult: Value,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any
  ) where Feature.Context == ContextlessFeatureContext, Value: Equatable {
    withTestedInstanceResultEqual(
      expectedResult,
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceResultEqual<Value>(
    _ expectedResult: Value,
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any
  ) where Value: Equatable {
    self.asyncTestReturnsEqual(
      expectedResult,
      timeout: timeout,
      file: file,
      line: line
    ) {
      assert(
        !self.variables.contains(\.result, of: (@Sendable () -> Void).self),
        "Cannot execute concurrently or set result before test"
      )
      _ = try await test(
        self.testedInstance(context: context)
      )
      defer { self.variables.clear(\.result) }
      return self.result
    }
  }

  public func withTestedInstanceResultNone(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstanceResultNone(
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceResultNone(
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any
  ) {
    self.asyncTestReturnsNone(
      timeout: timeout,
      file: file,
      line: line
    ) {
      assert(
        !self.variables.contains(\.result, of: (@Sendable () -> Void).self),
        "Cannot execute concurrently or set result before test"
      )
      _ = try await test(
        self.testedInstance(context: context)
      )
      defer { self.variables.clear(\.result) }
      return self.result
    }
  }

  public func withTestedInstanceResultSome(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstanceResultSome(
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceResultSome(
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any
  ) {
    self.asyncTestReturnsSome(
      timeout: timeout,
      file: file,
      line: line
    ) {
      assert(
        !self.variables.contains(\.result, of: (@Sendable () -> Void).self),
        "Cannot execute concurrently or set result before test"
      )
      _ = try await test(
        self.testedInstance(context: context)
      )
      defer { self.variables.clear(\.result) }
      return self.result
    }
  }

  public func withTestedInstanceReturnsSome(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any?
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstanceReturnsSome(
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceReturnsSome(
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any?
  ) {
    self.asyncTestReturnsSome(
      timeout: timeout,
      file: file,
      line: line
    ) {
      try await test(
        self.testedInstance(context: context)
      )
    }
  }

  public func withTestedInstanceReturnsNone(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any?
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstanceReturnsNone(
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceReturnsNone(
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Any?
  ) {
    self.asyncTestReturnsNone(
      timeout: timeout,
      file: file,
      line: line
    ) {
      try await test(
        self.testedInstance(context: context)
      )
    }
  }

  public func withTestedInstanceNotThrows<Value>(
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) where Feature.Context == ContextlessFeatureContext {
    withTestedInstanceNotThrows(
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceNotThrows<Value>(
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) {
    self.asyncTestNotThrows(
      timeout: timeout,
      file: file,
      line: line
    ) {
      try await test(
        self.testedInstance(context: context)
      )
    }
  }

  public func withTestedInstanceThrows<Value, Failure>(
    _ failureType: Failure.Type,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) where Feature.Context == ContextlessFeatureContext, Failure: Error {
    withTestedInstanceThrows(
      failureType,
      context: ContextlessFeatureContext.instance,
      timeout: timeout,
      file: file,
      line: line,
      test: test
    )
  }

  public func withTestedInstanceThrows<Value, Failure>(
    _ failureType: Failure.Type,
    context: Feature.Context,
    timeout: TimeInterval = 0.3,
    file: StaticString = #file,
    line: UInt = #line,
    test: @escaping @Sendable (Feature) async throws -> Value
  ) where Failure: Error {
    self.asyncTestThrows(
      failureType,
      timeout: timeout,
      file: file,
      line: line
    ) {
      try await test(
        self.testedInstance(context: context)
      )
    }
  }
}
