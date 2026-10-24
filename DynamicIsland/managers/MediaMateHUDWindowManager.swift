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
final class MediaMateHUDWindowManager {
    static let shared = MediaMateHUDWindowManager()

    private var windows: [WindowKey: HUDWindow] = [:]
    private var hideWorkItem: DispatchWorkItem?
    private let fadeOutDuration: TimeInterval = 0.3

    private init() {}

    nonisolated static var isActive: Bool {
        Defaults[.enableSystemHUD] && Defaults[.enableMediaMateHUD]
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

        let orientation = MediaMateHUDOrientation.forType(type)
        let targetKeys = Set(screens.map { WindowKey(screen: $0.localizedName, orientation: orientation) })
        for (key, window) in windows where !targetKeys.contains(key) {
            fadeOut(window)
        }

        for screen in screens {
            let window = ensureWindow(for: screen, orientation: orientation)
            window.state.type = type
            window.state.value = min(max(value, 0), 1)
            window.state.icon = icon

            if !window.state.isVisible {
                window.nsWindow.orderFrontRegardless()
                DispatchQueue.main.async {
                    window.state.isVisible = true
                }
            }
        }

        scheduleHide(after: Defaults[.mediaMateHUDDuration])
    }

    func triggerBump(direction: Int) {
        guard Self.isActive else { return }
        for window in windows.values where window.state.isVisible {
            if direction > 0 {
                window.state.lengthStretch = 1.07
                window.state.thicknessStretch = 0.94
            } else {
                window.state.lengthStretch = 0.93
                window.state.thicknessStretch = 0.84
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
                window.state.lengthStretch = 1
                window.state.thicknessStretch = 1
            }
        }
        scheduleHide(after: Defaults[.mediaMateHUDDuration])
    }

    func hideAllImmediately() {
        hideWorkItem?.cancel()
        hideWorkItem = nil
        for window in windows.values {
            window.state.isVisible = false
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

    private func ensureWindow(for screen: NSScreen, orientation: MediaMateHUDOrientation) -> HUDWindow {
        let key = WindowKey(screen: screen.localizedName, orientation: orientation)
        let frame = frame(for: screen, orientation: orientation)

        if let existing = windows[key] {
            if existing.nsWindow.frame != frame {
                existing.nsWindow.setFrame(frame, display: false)
            }
            return existing
        }

        let state = MediaMateHUDState(orientation: orientation)
        let hostingView = NSHostingView(rootView: MediaMateHUDView(state: state))

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

        let hudWindow = HUDWindow(nsWindow: window, state: state)
        windows[key] = hudWindow
        return hudWindow
    }

    private func frame(for screen: NSScreen, orientation: MediaMateHUDOrientation) -> NSRect {
        let size = MediaMateHUDMetrics.windowSize(for: orientation)
        let padding = MediaMateHUDMetrics.windowPadding
        let margin = MediaMateHUDMetrics.edgeMargin
        let visible = screen.visibleFrame
        let x = visible.maxX - margin - size.width + padding

        switch orientation {
        case .vertical:
            return NSRect(x: x, y: screen.frame.midY - size.height / 2, width: size.width, height: size.height)
        case .horizontal:
            let y = visible.maxY - margin - size.height + padding
            return NSRect(x: x, y: y, width: size.width, height: size.height)
        }
    }

    private func scheduleHide(after delay: TimeInterval) {
        hideWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor in
                guard let self else { return }
                for window in self.windows.values {
                    self.fadeOut(window)
                }
            }
        }
        hideWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: workItem)
    }

    private func fadeOut(_ window: HUDWindow) {
        guard window.state.isVisible else { return }
        window.state.isVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + fadeOutDuration) {
            guard !window.state.isVisible else { return }
            window.nsWindow.orderOut(nil)
        }
    }

    private struct WindowKey: Hashable {
        let screen: String
        let orientation: MediaMateHUDOrientation
    }

    private struct HUDWindow {
        let nsWindow: NSWindow
        let state: MediaMateHUDState
    }
}
#endif
