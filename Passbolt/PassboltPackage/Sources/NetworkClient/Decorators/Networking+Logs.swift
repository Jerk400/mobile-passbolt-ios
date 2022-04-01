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

#if DEBUG
extension Networking {

  public func withLogs(using diagnostics: Diagnostics) -> Self {
    Self(
      execute: { request, useCache in
        let trackingID: String = diagnostics.uniqueID()
        let timeMeasurement: Diagnostics.TimeMeasurement = diagnostics.measurePerformance("Network request")
        diagnostics.debugLog("Executing request <\(trackingID)> (useCache: \(useCache)):\n\(request)\n---")
        do {
          let response = try await self.execute(request, useCache)
          diagnostics.debugLog("Received <\(trackingID)>:\n\(response)\n---")
          timeMeasurement.end()
          return response
        }
        catch {
          diagnostics.debugLog("Received <\(trackingID)>:\n\(error)\n---")
          timeMeasurement.end()
          throw error
        }
      },
      clearCache: self.clearCache
    )
  }
}
#endif
