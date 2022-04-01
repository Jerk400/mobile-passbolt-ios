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
import UIKit

extension UIFont {

  internal static let registerInter: Void = {
    func registerFont(fileName: String) {
      guard
        let pathForResourceString = Bundle.module.path(forResource: fileName, ofType: "otf"),
        let fontData = NSData(contentsOfFile: pathForResourceString),
        let dataProvider = CGDataProvider(data: fontData),
        let fontRef = CGFont(dataProvider)
      else { return }

      CTFontManagerRegisterGraphicsFont(fontRef, nil)
    }
    registerFont(fileName: "Inter Black")
    registerFont(fileName: "Inter Bold")
    registerFont(fileName: "Inter Semi Bold")
    registerFont(fileName: "Inter Light")
    registerFont(fileName: "Inter Extra Light")
    registerFont(fileName: "Inter Medium")
    registerFont(fileName: "Inter Regular")
    registerFont(fileName: "Inter Thin")
    registerFont(fileName: "Inter Light Italic")
    registerFont(fileName: "Inter Italic")
  }()

  public static func inter(
    ofSize fontSize: CGFloat,
    weight: UIFont.Weight = .regular
  ) -> UIFont {
    UIFont.registerFontsIfNeeded()
    let font: UIFont?
    switch weight {
    case .black:
      font = UIFont(
        name: "Inter Black",
        size: fontSize
      )

    case .bold:
      font = UIFont(
        name: "Inter Bold",
        size: fontSize
      )

    case .semibold:
      font = UIFont(
        name: "Inter Semi Bold",
        size: fontSize
      )

    case .light:
      font = UIFont(
        name: "Inter Light",
        size: fontSize
      )

    case .ultraLight:
      font = UIFont(
        name: "Inter Extra Light",
        size: fontSize
      )

    case .medium:
      font = UIFont(
        name: "Inter Medium",
        size: fontSize
      )

    case .regular:
      font = UIFont(
        name: "Inter Regular",
        size: fontSize
      )

    case .thin:
      font = UIFont(
        name: "Inter Thin",
        size: fontSize
      )

    case _:
      assertionFailure("Unsupported font weight: \(weight)")
      font = nil
    }

    return font
      ?? .systemFont(
        ofSize: fontSize,
        weight: weight
      )
  }

  public static func interItalic(
    ofSize fontSize: CGFloat,
    weight: UIFont.Weight = .regular
  ) -> UIFont {
    registerFontsIfNeeded()
    let font: UIFont?
    switch weight {
    case .light:
      font = UIFont(
        name: "Inter LightItalic",
        size: fontSize
      )

    case .regular:
      font = UIFont(
        name: "Inter Italic",
        size: fontSize
      )

    case _:
      assertionFailure("Unsupported font weight: \(weight)")
      font = nil
    }

    return font
      ?? .italicSystemFont(
        ofSize: fontSize
      )
  }
}
