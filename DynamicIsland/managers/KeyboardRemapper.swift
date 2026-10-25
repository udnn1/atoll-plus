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
import Combine
import Defaults
import IOKit

@MainActor
final class KeyboardRemapper {
    static let shared = KeyboardRemapper()

    private static let mapping: [(UInt64, UInt64)] = [
        (0x7000000E3, 0x7000000E0),
        (0x7000000E0, 0x7000000E3),
        (0x7000000E7, 0x7000000E6),
        (0x7000000E6, 0x7000000E7)
    ]

    private var notificationPort: IONotificationPortRef?
    private var iterator: io_iterator_t = 0
    private var pendingApply: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        Defaults.publisher(.enableKeyboardRemap).sink { [weak self] change in
            Task { @MainActor in
                if change.newValue { self?.apply() } else { self?.clear() }
            }
        }.store(in: &cancellables)

        let center = NSWorkspace.shared.notificationCenter
        center.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] _ in
            Task { @MainActor in self?.scheduleApply() }
        }.store(in: &cancellables)
        center.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification).sink { [weak self] _ in
            Task { @MainActor in self?.scheduleApply() }
        }.store(in: &cancellables)

        installDeviceWatcher()
    }

    private func installDeviceWatcher() {
        guard let port = IONotificationPortCreate(kIOMainPortDefault) else { return }
        notificationPort = port
        CFRunLoopAddSource(CFRunLoopGetMain(), IONotificationPortGetRunLoopSource(port).takeUnretainedValue(), .defaultMode)
        let callback: IOServiceMatchingCallback = { _, iterator in
            KeyboardRemapper.drain(iterator)
            Task { @MainActor in KeyboardRemapper.shared.scheduleApply() }
        }
        IOServiceAddMatchingNotification(port, kIOFirstMatchNotification, IOServiceMatching("IOHIDEventService"), callback, nil, &iterator)
        Self.drain(iterator)
    }

    nonisolated private static func drain(_ iterator: io_iterator_t) {
        var service = IOIteratorNext(iterator)
        while service != 0 {
            IOObjectRelease(service)
            service = IOIteratorNext(iterator)
        }
    }

    private func scheduleApply() {
        guard Defaults[.enableKeyboardRemap] else { return }
        pendingApply?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.apply() }
        }
        pendingApply = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func apply() {
        guard Defaults[.enableKeyboardRemap] else { return }
        let entries = Self.mapping.map {
            "{\"HIDKeyboardModifierMappingSrc\":\($0.0),\"HIDKeyboardModifierMappingDst\":\($0.1)}"
        }.joined(separator: ",")
        runHidutil("{\"CapsLockDelayOverride\":0,\"UserKeyMapping\":[\(entries)]}")
    }

    private func clear() {
        runHidutil("{\"UserKeyMapping\":[]}")
    }

    private func runHidutil(_ json: String) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = ["property", "--set", json]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }
}
