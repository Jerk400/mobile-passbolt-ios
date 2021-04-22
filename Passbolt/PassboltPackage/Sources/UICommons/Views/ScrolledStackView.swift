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
import UIKit

open class ScrolledStackView: UIScrollView {
  
  private let stackView: StackView = .init()
  
  public required init() {
    super.init(frame: .zero)
    setup()
  }
  
  @available(*, unavailable)
  public required init?(coder: NSCoder) {
    unreachable("\(Self.self).\(#function) should not be used")
  }
  
  public var axis: NSLayoutConstraint.Axis {
    get { stackView.axis }
    set {
      precondition(
        stackView.arrangedSubviews.isEmpty,
        "Axis change in non empty \(Self.self) is not supported"
      )
      stackView.axis = newValue
    }
  }
  
  public var spacing: CGFloat {
    get { stackView.spacing }
    set { stackView.spacing = newValue }
  }
  
  override public var contentInset: UIEdgeInsets {
    get { stackView.layoutMargins }
    set { stackView.layoutMargins = newValue }
  }
  
  public var isLayoutMarginsRelativeArrangement: Bool {
    get { stackView.isLayoutMarginsRelativeArrangement }
    set { stackView.isLayoutMarginsRelativeArrangement = newValue }
  }
  
  public func append(_ view: UIView) {
    stackView.addArrangedSubview(view)
  }
  
  public func insert(_ view: UIView, at index: Int) {
    stackView.insertArrangedSubview(view, at: index)
  }
  
  public func appendSpace(of size: CGFloat) {
    stackView.appendSpace(of: size)
  }
  
  public func appendFiller(minSize: CGFloat = 0) {
    stackView.appendFiller(minSize: minSize)
  }
  
  public func removeAllArrangedSubviews() {
    stackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
  }
  
  private func setup() {
    showsVerticalScrollIndicator = false
    showsHorizontalScrollIndicator = false
    insetsLayoutMarginsFromSafeArea = true
    
    stackView.axis = .vertical
    stackView.alignment = .fill
    stackView.distribution = .fill
    stackView.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      stackView.topAnchor.constraint(equalTo: topAnchor),
      stackView.leftAnchor.constraint(equalTo: leftAnchor),
      stackView.rightAnchor.constraint(equalTo: rightAnchor),
      stackView.bottomAnchor.constraint(equalTo: bottomAnchor),
      stackView.widthAnchor.constraint(equalTo: widthAnchor),
      {
        let constraint: NSLayoutConstraint = stackView.heightAnchor
          .constraint(equalTo: safeAreaLayoutGuide.heightAnchor)
        constraint.priority = .defaultLow
        return constraint
      }()
    ])
  }
}