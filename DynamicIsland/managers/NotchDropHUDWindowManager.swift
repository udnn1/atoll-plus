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

#if os(macOS)
import AppKit
import SwiftUI
import SkyLightWindow
import Defaults

@MainActor
final class NotchDropHUDWindowManager {
    static let shared = NotchDropHUDWindowManager()

    private var windows: [String: DropWindow] = [:]
    private var hideWorkItem: DispatchWorkItem?
    private let collapseDuration: TimeInterval = 0.45

    private init() {}

    nonisolated static var isActive: Bool {
        Defaults[.enableSystemHUD] && Defaults[.enableNotchDropHUD]
    }

    nonisolated static func handles(_ type: SneakContentType) -> Bool {
        guard isActive else { return false }
        switch type {
        case .volume, .brightness, .backlight:
            return true
        default:
            return false
        }
    }

    func show(type: SneakContentType, value: CGFloat, icon: String = "", onScreen targetScreen: NSScreen? = nil) {
        guard Self.handles(type) else { return }

        let screens = resolveScreens(targetScreen)
        guard !screens.isEmpty else { return }

        let targetKeys = Set(screens.map(\.localizedName))
        for (key, window) in windows where !targetKeys.contains(key) {
            collapse(window)
        }

        for screen in screens {
            let window = ensureWindow(for: screen)
            window.state.type = type
            window.state.value = min(max(value, 0), 1)
            window.state.icon = icon

            if !window.nsWindow.isVisible || !window.state.isExpanded {
                window.nsWindow.orderFrontRegardless()
                DispatchQueue.main.async {
                    window.state.isExpanded = true
                }
            }
        }

        scheduleHide(after: Defaults[.notchDropHUDDuration])
    }

    func triggerBump() {
        guard Self.isActive else { return }
        for window in windows.values where window.state.isExpanded {
            window.state.stretch = 0.05
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09) {
                window.state.stretch = 0
            }
        }
    }

    func hideAllImmediately() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        for window in windows.values {
            window.state.isExpanded = false
            window.nsWindow.orderOut(nil)
        }
    }

    private func resolveScreens(_ targetScreen: NSScreen?) -> [NSScreen] {
        if let targetScreen { return [targetScreen] }
        if Defaults[.showOnAllDisplays] { return NSScreen.screens }
        let preferred = DynamicIslandViewCoordinator.shared.selectedScreen
        if let match = NSScreen.screens.first(where: { $0.localizedName == preferred }) {
            return [match]
        }
        return NSScreen.main.map { [$0] } ?? []
    }

    private func ensureWindow(for screen: NSScreen) -> DropWindow {
        let key = screen.localizedName
        let notchSize = getClosedNotchSize(screen: key)
        let frame = frame(for: screen, notchSize: notchSize)

        if let existing = windows[key], existing.state.notchSize == notchSize {
            if existing.nsWindow.frame != frame {
                existing.nsWindow.setFrame(frame, display: false)
            }
            return existing
        }

        windows[key]?.nsWindow.orderOut(nil)

        let state = NotchDropHUDState(notchSize: notchSize)
        let hostingView = NSHostingView(rootView: NotchDropHUDView(state: state))

        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = true
        window.level = .mainMenu + 4
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle, .fullScreenAuxiliary]
        window.contentView = hostingView

        SkyLightOperator.shared.delegateWindow(window)

        let drop = DropWindow(nsWindow: window, state: state)
        windows[key] = drop
        return drop
    }

    private func frame(for screen: NSScreen, notchSize: CGSize) -> NSRect {
        let size = NotchDropHUDMetrics.windowSize(for: notchSize)
        return NSRect(
            x: screen.frame.midX - size.width / 2,
            y: screen.frame.maxY - size.height,
            width: size.width,
            height: size.height
        )
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                for window in self.windows.values {
                    self.collapse(window)
                }
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func collapse(_ window: DropWindow) {
        guard window.state.isExpanded else { return }
        window.state.isExpanded = false
        DispatchQueue.main.asyncAfter(deadline: .now() + collapseDuration) {
            guard !window.state.isExpanded else { return }
            window.nsWindow.orderOut(nil)
        }
    }

    private struct DropWindow {
        let nsWindow: NSWindow
        let state: NotchDropHUDState
    }
}
#endif
