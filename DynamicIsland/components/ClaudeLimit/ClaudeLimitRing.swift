/*
 * Atoll (DynamicIsland)
 * Copyright (C) 2024-2026 Atoll Contributors
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program. If not, see <https://www.gnu.org/licenses/>.
 */

import SwiftUI

struct ClaudeLimitRing: View {
    let pct: Double?
    var showRing: Bool = true
    var size: CGFloat

    private var color: Color { Color(nsColor: ClaudeLimitService.levelColor(pct)) }
    private var label: String { ClaudeLimitService.format(pct) }

    var body: some View {
        let unit = size / 64
        let width = 7 * unit
        let margin = 2 * unit
        let inner = size - 2 * (margin + width) - 5 * unit
        ZStack {
            if showRing {
                Circle()
                    .inset(by: margin + width / 2)
                    .stroke(Color(white: 128 / 255).opacity(110 / 255), lineWidth: width)
                if let pct, pct > 0 {
                    Circle()
                        .inset(by: margin + width / 2)
                        .trim(from: 0, to: min(pct, 100) / 100)
                        .stroke(color, style: StrokeStyle(lineWidth: width, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                Text(label)
                    .font(.system(size: 40 * unit, weight: .semibold).width(.condensed))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(width: inner, height: inner * 0.72)
            } else {
                Text(label)
                    .font(.system(size: 72 * unit, weight: .semibold).width(.condensed))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.2)
                    .frame(width: size - 2 * unit, height: size - 2 * unit)
            }
        }
        .frame(width: size, height: size)
        .animation(.smooth(duration: 0.4), value: pct)
    }
}
