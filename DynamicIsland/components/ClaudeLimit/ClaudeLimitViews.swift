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
import Defaults

extension ClaudeLimitService {
    func displayedPct(metric: String) -> Double? {
        guard let usage else { return nil }
        return metric == "seven" ? usage.seven : usage.five
    }
}

struct ClaudeLimitLiveActivity: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var service = ClaudeLimitService.shared
    @Default(.claudeLimitMetric) private var metric
    @Default(.claudeLimitShowRing) private var showRing

    var body: some View {
        let ringSize = max(16, vm.effectiveClosedNotchHeight - 6)
        let sideWidth = ringSize + 10
        HStack(spacing: 0) {
            ClaudeLimitRing(pct: service.displayedPct(metric: metric), showRing: showRing, size: ringSize)
                .frame(width: sideWidth, alignment: .leading)

            Rectangle()
                .fill(Color.black)
                .frame(width: vm.closedNotchSize.width)

            Color.clear
                .frame(width: sideWidth)
        }
        .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
    }
}

struct ClaudeLimitDetailsView: View {
    @ObservedObject private var service = ClaudeLimitService.shared
    @Default(.claudeLimitMetric) private var metric
    @Default(.claudeLimitShowRing) private var showRing

    var body: some View {
        HStack(alignment: .center, spacing: 22) {
            ClaudeLimitRing(pct: service.displayedPct(metric: metric), showRing: showRing, size: 96)

            VStack(alignment: .leading, spacing: 5) {
                Text(fiveLine).font(.system(size: 15, weight: .semibold))
                Text(sevenLine).font(.system(size: 13))
                Text(resetLine).font(.system(size: 13))
                Divider().overlay(Color.white.opacity(0.15)).padding(.vertical, 2)
                Text(lastLine).font(.system(size: 11)).foregroundStyle(.secondary)
                Text(nextLine).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            .foregroundStyle(.white)

            Spacer(minLength: 0)

            VStack(alignment: .trailing, spacing: 8) {
                Button("Odśwież teraz") { service.refreshNow() }
                    .buttonStyle(.bordered)
                Toggle("Pierścień postępu", isOn: $showRing)
                    .toggleStyle(.checkbox)
                Picker("", selection: $metric) {
                    Text("Limit 5h").tag("five")
                    Text("Limit 7d").tag("seven")
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 150)
            }
            .font(.system(size: 11))
        }
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
    }

    private var fiveLine: String {
        guard let usage = service.usage else { return "Brak danych" }
        return "Limit 5h: \(ClaudeLimitService.format(usage.five))%"
    }

    private var sevenLine: String {
        guard let usage = service.usage, let seven = usage.seven else { return "Limit 7d: -" }
        return "Limit 7d: \(ClaudeLimitService.format(seven))%"
    }

    private var resetLine: String {
        let text = ClaudeLimitService.resetText(service.usage?.fiveReset)
        return text.isEmpty ? "Reset 5h: -" : "Reset 5h: \(text)"
    }

    private var lastLine: String {
        guard let lastGood = service.lastGood else { return "Ostatni odczyt: -" }
        return "Ostatni odczyt: \(ClaudeLimitService.clock(Date(timeIntervalSince1970: lastGood.t)))"
    }

    private var nextLine: String {
        "Następny odczyt: ~\(ClaudeLimitService.clock(service.nextAt))"
    }
}
