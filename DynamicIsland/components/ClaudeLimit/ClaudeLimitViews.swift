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

import AppKit
import ApplicationServices
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
    @ObservedObject private var menuBarLayout = MenuBarLayout.shared
    @Default(.claudeLimitMetric) private var metric
    @Default(.claudeLimitShowRing) private var showRing

    private enum Placement { case left, right, hidden }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3)) { _ in
            let ringSize = max(16, vm.effectiveClosedNotchHeight - 6)
            let sideWidth = ringSize + 20
            let notched = isNotchScreen
            let placement = notched ? resolvePlacement(sideWidth: sideWidth) : .left
            let offset: CGFloat? = notched ? (placement == .left ? -sideWidth / 2 : placement == .right ? sideWidth / 2 : 0) : nil
            HStack(spacing: 0) {
                if placement == .left {
                    side(isRing: true, ringSize: ringSize, width: sideWidth, alignment: .trailing)
                } else if !notched {
                    side(isRing: false, ringSize: ringSize, width: sideWidth, alignment: .leading)
                }

                Rectangle()
                    .fill(Color.black)
                    .frame(width: vm.closedNotchSize.width)

                if placement == .right {
                    side(isRing: true, ringSize: ringSize, width: sideWidth, alignment: .leading)
                } else if !notched {
                    side(isRing: false, ringSize: ringSize, width: sideWidth, alignment: .trailing)
                }
            }
            .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
            .onAppear { service.activityOffset = offset }
            .onChange(of: offset) { _, value in service.activityOffset = value }
        }
        .onDisappear { service.activityOffset = nil }
    }

    private var isNotchScreen: Bool {
        let name = vm.screen ?? DynamicIslandViewCoordinator.shared.selectedScreen
        return (NSScreen.screens.first(where: { $0.localizedName == name })?.safeAreaInsets.top ?? 0) > 0
    }

    @ViewBuilder
    private func side(isRing: Bool, ringSize: CGFloat, width: CGFloat, alignment: Alignment) -> some View {
        if isRing {
            ClaudeLimitRing(pct: service.displayedPct(metric: metric), showRing: showRing, size: ringSize)
                .padding(alignment == .trailing ? .trailing : .leading, 4)
                .frame(width: width, alignment: alignment)
                .contentShape(Rectangle())
                .onHover { hovering in
                    guard hovering, vm.notchState == .closed else { return }
                    DynamicIslandViewCoordinator.shared.currentView = .llmUsage
                    vm.open()
                }
                .transition(.opacity)
        } else {
            Color.clear.frame(width: width)
        }
    }

    private func resolvePlacement(sideWidth: CGFloat) -> Placement {
        let name = vm.screen ?? DynamicIslandViewCoordinator.shared.selectedScreen
        guard let screen = NSScreen.screens.first(where: { $0.localizedName == name }),
              screen.safeAreaInsets.top > 0 else { return .left }
        let gap = MenuBarLayout.clearanceGap
        let notchLeft = screen.frame.midX - vm.closedNotchSize.width / 2
        let notchRight = screen.frame.midX + vm.closedNotchSize.width / 2
        if let menusRightEdge = menuBarLayout.appMenusRightEdge, menusRightEdge + gap > notchLeft - sideWidth {
            if let statusLeft = Self.statusItemsLeftEdge(on: screen), statusLeft - gap < notchRight + sideWidth {
                return .hidden
            }
            return .right
        }
        return .left
    }

    private static func statusItemsLeftEdge(on screen: NSScreen) -> CGFloat? {
        ClaudeLimitStatusBarProbe.shared.requestRefresh()
        return ClaudeLimitStatusBarProbe.shared.leftEdge(minX: screen.frame.midX, maxX: screen.frame.maxX)
    }
}

final class ClaudeLimitStatusBarProbe: @unchecked Sendable {
    static let shared = ClaudeLimitStatusBarProbe()

    private let lock = NSLock()
    private var positions: [CGFloat] = []
    private var lastScan = Date.distantPast
    private var inFlight = false

    func leftEdge(minX: CGFloat, maxX: CGFloat) -> CGFloat? {
        lock.lock()
        defer { lock.unlock() }
        return positions.filter { $0 >= minX && $0 < maxX }.min()
    }

    func requestRefresh() {
        lock.lock()
        guard !inFlight, Date().timeIntervalSince(lastScan) > 2.5 else {
            lock.unlock()
            return
        }
        inFlight = true
        lock.unlock()
        Task.detached(priority: .utility) {
            let found = Self.scan()
            self.lock.lock()
            self.positions = found
            self.lastScan = Date()
            self.inFlight = false
            self.lock.unlock()
        }
    }

    private static func scan() -> [CGFloat] {
        guard AXIsProcessTrusted() else { return [] }
        var xs: [CGFloat] = []
        for app in NSWorkspace.shared.runningApplications where app.activationPolicy != .prohibited || app.bundleIdentifier == "com.apple.controlcenter" || app.bundleIdentifier == "com.apple.systemuiserver" {
            let element = AXUIElementCreateApplication(app.processIdentifier)
            AXUIElementSetMessagingTimeout(element, 0.05)
            var extras: CFTypeRef?
            guard AXUIElementCopyAttributeValue(element, "AXExtrasMenuBar" as CFString, &extras) == .success,
                  let bar = extras, CFGetTypeID(bar) == AXUIElementGetTypeID() else { continue }
            let barElement = bar as! AXUIElement
            AXUIElementSetMessagingTimeout(barElement, 0.05)
            var children: CFTypeRef?
            guard AXUIElementCopyAttributeValue(barElement, kAXChildrenAttribute as CFString, &children) == .success,
                  let items = children as? [AXUIElement] else { continue }
            for item in items {
                AXUIElementSetMessagingTimeout(item, 0.05)
                var value: CFTypeRef?
                guard AXUIElementCopyAttributeValue(item, kAXPositionAttribute as CFString, &value) == .success,
                      let v = value, CFGetTypeID(v) == AXValueGetTypeID() else { continue }
                var point = CGPoint.zero
                if AXValueGetValue(v as! AXValue, .cgPoint, &point) { xs.append(point.x) }
            }
        }
        return xs
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
