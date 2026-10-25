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
    @ObservedObject private var service = ClaudeLimitService.shared
    @Default(.claudeLimitMetric) private var metric
    @Default(.claudeLimitShowRing) private var showRing
    var showsCapsLock = false
    var capsLockColor: Color = .white

    var body: some View {
        NotchSingleWingActivity(reportsRingRange: true, itemCount: showsCapsLock ? 2 : 1) { size, isLeft in
            HStack(spacing: 4) {
                if showsCapsLock && isLeft { capsIcon(size: size) }
                Color.clear.frame(width: size, height: size).claudeRingAnchor()
                if showsCapsLock && !isLeft { capsIcon(size: size) }
            }
        }
        .animation(.spring(response: 0.38, dampingFraction: 0.82), value: showsCapsLock)
    }

    private func capsIcon(size: CGFloat) -> some View {
        Image(systemName: "capslock.fill")
            .font(.system(size: size * 0.7, weight: .semibold))
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(capsLockColor)
            .frame(width: size, height: size)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
    }
}

struct NotchSingleWingActivity<Content: View>: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var service = ClaudeLimitService.shared
    @ObservedObject private var menuBarLayout = MenuBarLayout.shared
    var reportsRingRange = false
    var itemCount = 1
    @ViewBuilder let content: (CGFloat, Bool) -> Content
    @State private var ownerID = UUID()

    private enum Placement { case left, right, hidden }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 3)) { _ in
            let ringSize = max(16, vm.effectiveClosedNotchHeight - 6)
            let shapePadding = cornerRadiusInsets.closed.bottom
            let physical = physicalNotchWidth
            if let physical {
                let wing = max(16, vm.effectiveClosedNotchHeight - 12)
                let itemsWidth = wing * CGFloat(itemCount) + 4 * CGFloat(itemCount - 1)
                let ringSide = shapePadding + 2 + itemsWidth
                let placement = resolvePlacement(extension: 2 + itemsWidth + shapePadding, physicalWidth: physical)
                let offset: CGFloat = placement == .left ? -ringSide / 2 : placement == .right ? ringSide / 2 : 0
                let range = ringRange(placement: placement, physicalWidth: physical, extent: itemCount > 1 ? 4 + wing : 2 + wing + shapePadding)
                HStack(spacing: 0) {
                    if placement == .left {
                        ringView(size: wing, isLeft: true)
                            .padding(.trailing, shapePadding + 2)
                            .frame(width: ringSide, alignment: .trailing)
                    }
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: max(physical - 2 * shapePadding, 20))
                    if placement == .right {
                        ringView(size: wing, isLeft: false)
                            .padding(.leading, shapePadding + 2)
                            .frame(width: ringSide, alignment: .leading)
                    }
                }
                .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
                .animation(.smooth(duration: 0.25), value: placement)
                .onAppear {
                    service.setActivityOffset(offset, owner: ownerID)
                    if reportsRingRange { service.ringScreenRange = range }
                }
                .onChange(of: offset) { _, value in service.setActivityOffset(value, owner: ownerID) }
                .onChange(of: placement) { _, _ in if reportsRingRange { service.ringScreenRange = range } }
            } else {
                let wing = max(16, vm.effectiveClosedNotchHeight - 12)
                let itemsWidth = wing * CGFloat(itemCount) + 4 * CGFloat(itemCount - 1)
                HStack(spacing: 0) {
                    ringView(size: wing, isLeft: true)
                        .frame(width: itemsWidth, alignment: .center)
                    Rectangle()
                        .fill(Color.black)
                        .frame(width: vm.closedNotchSize.width)
                    Color.clear.frame(width: itemsWidth)
                }
                .frame(height: vm.effectiveClosedNotchHeight, alignment: .center)
                .onAppear {
                    service.setActivityOffset(nil, owner: ownerID)
                    if reportsRingRange, let screen = currentScreen {
                        let edge = screen.frame.midX - vm.closedNotchSize.width / 2
                        service.ringScreenRange = (edge - wing - cornerRadiusInsets.closed.bottom)...edge
                    }
                }
            }
        }
        .onDisappear {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) { service.clearActivityOffset(owner: ownerID) }
            if reportsRingRange { service.ringScreenRange = nil }
        }
    }

    private var currentScreen: NSScreen? {
        let name = vm.screen ?? DynamicIslandViewCoordinator.shared.selectedScreen
        return NSScreen.screens.first(where: { $0.localizedName == name })
    }

    private var physicalNotchWidth: CGFloat? {
        guard let screen = currentScreen, screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea?.width,
              let right = screen.auxiliaryTopRightArea?.width else { return nil }
        return screen.frame.width - left - right
    }

    private func ringView(size: CGFloat, isLeft: Bool) -> some View {
        content(size, isLeft)
    }

    private func ringRange(placement: Placement, physicalWidth: CGFloat, extent: CGFloat) -> ClosedRange<CGFloat>? {
        guard let screen = currentScreen else { return nil }
        let left = screen.frame.midX - physicalWidth / 2
        let right = screen.frame.midX + physicalWidth / 2
        switch placement {
        case .left: return (left - extent)...left
        case .right: return right...(right + extent)
        case .hidden: return nil
        }
    }

    private func resolvePlacement(extension wing: CGFloat, physicalWidth: CGFloat) -> Placement {
        guard let screen = currentScreen else { return .left }
        let gap = MenuBarLayout.clearanceGap
        let notchLeft = screen.frame.midX - physicalWidth / 2
        let notchRight = screen.frame.midX + physicalWidth / 2
        if let menusRightEdge = menuBarLayout.appMenusRightEdge, menusRightEdge + gap > notchLeft - wing {
            if let statusLeft = Self.statusItemsLeftEdge(on: screen), statusLeft - gap < notchRight + wing {
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

struct ClaudeCompanionWing<Content: View>: View {
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var service = ClaudeLimitService.shared
    @ObservedObject private var menuBarLayout = MenuBarLayout.shared
    @Default(.claudeLimitMetric) private var metric
    @Default(.claudeLimitShowRing) private var showRing
    let active: Bool
    @ViewBuilder let content: () -> Content
    @State private var ownerID = UUID()
    @State private var contentWidth: CGFloat = 0

    var body: some View {
        if active {
            let ringWidth = ClaudeRingSlot.width(closedHeight: vm.effectiveClosedNotchHeight)
            let notched = physicalNotchWidth != nil
            let onRight = notched && menusReachNotch
            let offset: CGFloat = notched ? (onRight ? ringWidth / 2 : -ringWidth / 2) : 0
            content()
            .environment(\.claudeRingSide, onRight ? .trailing : .leading)
            .background(GeometryReader { geo in
                Color.clear
                    .onAppear { contentWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, value in contentWidth = value }
            })
            .onAppear { publish(offset: offset, onRight: onRight, ringWidth: ringWidth) }
            .onChange(of: offset) { _, value in publish(offset: value, onRight: onRight, ringWidth: ringWidth) }
            .onChange(of: contentWidth) { _, _ in publish(offset: offset, onRight: onRight, ringWidth: ringWidth) }
            .onDisappear {
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) { service.clearActivityOffset(owner: ownerID) }
                service.ringScreenRange = nil
            }
        } else {
            content()
        }
    }

    private func publish(offset: CGFloat, onRight: Bool, ringWidth: CGFloat) {
        service.setActivityOffset(physicalNotchWidth != nil ? offset : nil, owner: ownerID)
        guard let screen = currentScreen else { return }
        let half = (physicalNotchWidth ?? vm.closedNotchSize.width) / 2
        let notchLeft = screen.frame.midX - half
        let notchRight = screen.frame.midX + half
        service.ringScreenRange = onRight ? notchRight...(notchRight + ringWidth + 4) : (notchLeft - ringWidth - 4)...notchLeft
    }

    private var currentScreen: NSScreen? {
        let name = vm.screen ?? DynamicIslandViewCoordinator.shared.selectedScreen
        return NSScreen.screens.first(where: { $0.localizedName == name })
    }

    private var physicalNotchWidth: CGFloat? {
        guard let screen = currentScreen, screen.safeAreaInsets.top > 0,
              let left = screen.auxiliaryTopLeftArea?.width,
              let right = screen.auxiliaryTopRightArea?.width else { return nil }
        return screen.frame.width - left - right
    }

    private var menusReachNotch: Bool {
        guard let screen = currentScreen, let physical = physicalNotchWidth,
              let menus = menuBarLayout.appMenusRightEdge else { return false }
        return menus + MenuBarLayout.clearanceGap > screen.frame.midX - physical / 2 - 60
    }
}

enum ClaudeRingSide {
    case none
    case leading
    case trailing
}

private struct ClaudeRingSideKey: EnvironmentKey {
    static let defaultValue = ClaudeRingSide.none
}

extension EnvironmentValues {
    var claudeRingSide: ClaudeRingSide {
        get { self[ClaudeRingSideKey.self] }
        set { self[ClaudeRingSideKey.self] = newValue }
    }
}

enum ClaudeRingSlot {
    static func ringSize(closedHeight: CGFloat) -> CGFloat {
        max(16, closedHeight - 12)
    }

    static func width(closedHeight: CGFloat) -> CGFloat {
        ringSize(closedHeight: closedHeight) + 6
    }
}

private struct ClaudeRingSlotModifier: ViewModifier {
    @Environment(\.claudeRingSide) private var side
    @EnvironmentObject var vm: DynamicIslandViewModel
    @ObservedObject private var service = ClaudeLimitService.shared
    @Default(.claudeLimitMetric) private var metric
    @Default(.claudeLimitShowRing) private var showRing

    func body(content: Content) -> some View {
        HStack(spacing: 0) {
            if side == .leading { slot }
            content
            if side == .trailing { slot }
        }
    }

    private var slot: some View {
        let size = ClaudeRingSlot.ringSize(closedHeight: vm.effectiveClosedNotchHeight)
        return Color.clear
            .frame(width: ClaudeRingSlot.width(closedHeight: vm.effectiveClosedNotchHeight))
            .overlay(alignment: side == .leading ? .trailing : .leading) {
                Color.clear.frame(width: size, height: size).claudeRingAnchor()
            }
    }
}

extension View {
    func claudeRingSlot() -> some View {
        modifier(ClaudeRingSlotModifier())
    }
}

struct ClaudeRingExtraWidthReader {
    static func extra(side: ClaudeRingSide, closedHeight: CGFloat) -> CGFloat {
        side == .none ? 0 : ClaudeRingSlot.width(closedHeight: closedHeight)
    }
}

struct ClaudeRingAnchorKey: PreferenceKey {
    static var defaultValue: Anchor<CGRect>? = nil
    static func reduce(value: inout Anchor<CGRect>?, nextValue: () -> Anchor<CGRect>?) {
        value = value ?? nextValue()
    }
}

extension View {
    func claudeRingAnchor() -> some View {
        anchorPreference(key: ClaudeRingAnchorKey.self, value: .bounds) { $0 }
    }

    func claudeRingOverlay(enabled: Bool) -> some View {
        overlayPreferenceValue(ClaudeRingAnchorKey.self) { anchor in
            ClaudeRingOverlayLayer(anchor: enabled ? anchor : nil)
        }
    }
}

private struct ClaudeRingOverlayLayer: View {
    let anchor: Anchor<CGRect>?
    @ObservedObject private var service = ClaudeLimitService.shared
    @Default(.claudeLimitMetric) private var metric
    @Default(.claudeLimitShowRing) private var showRing
    @State private var lastFrame: CGRect = .zero

    var body: some View {
        GeometryReader { geo in
            let frame = anchor.map { geo[$0] } ?? lastFrame
            ClaudeLimitRing(pct: service.displayedPct(metric: metric), showRing: showRing, size: max(frame.height, 1))
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX, y: frame.midY)
                .opacity(anchor == nil ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: anchor == nil)
                .onChange(of: frame) { _, value in if anchor != nil { lastFrame = value } }
                .onAppear { if anchor != nil { lastFrame = frame } }
        }
        .allowsHitTesting(false)
    }
}
