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
import SwiftUI

struct KeyRemapPair: Codable, Hashable, Identifiable, Defaults.Serializable {
    var id = UUID()
    var from: UInt64
    var to: UInt64

    static let defaults: [KeyRemapPair] = [
        KeyRemapPair(from: RemappableKey.leftCommand.usage, to: RemappableKey.leftControl.usage),
        KeyRemapPair(from: RemappableKey.leftControl.usage, to: RemappableKey.leftCommand.usage),
        KeyRemapPair(from: RemappableKey.rightCommand.usage, to: RemappableKey.rightOption.usage),
        KeyRemapPair(from: RemappableKey.rightOption.usage, to: RemappableKey.rightCommand.usage)
    ]
}

enum RemappableKey: CaseIterable, Identifiable {
    case leftControl, leftShift, leftOption, leftCommand
    case rightControl, rightShift, rightOption, rightCommand
    case capsLock, escape, tab, returnKey, delete, grave, section, fn

    var id: UInt64 { usage }

    var usage: UInt64 {
        switch self {
        case .leftControl: return 0x7000000E0
        case .leftShift: return 0x7000000E1
        case .leftOption: return 0x7000000E2
        case .leftCommand: return 0x7000000E3
        case .rightControl: return 0x7000000E4
        case .rightShift: return 0x7000000E5
        case .rightOption: return 0x7000000E6
        case .rightCommand: return 0x7000000E7
        case .capsLock: return 0x700000039
        case .escape: return 0x700000029
        case .tab: return 0x70000002B
        case .returnKey: return 0x700000028
        case .delete: return 0x70000002A
        case .grave: return 0x700000035
        case .section: return 0x700000064
        case .fn: return 0xFF00000003
        }
    }

    var title: String {
        switch self {
        case .leftControl: return "Lewy Control"
        case .leftShift: return "Lewy Shift"
        case .leftOption: return "Lewy Option"
        case .leftCommand: return "Lewy Command"
        case .rightControl: return "Prawy Control"
        case .rightShift: return "Prawy Shift"
        case .rightOption: return "Prawy Option"
        case .rightCommand: return "Prawy Command"
        case .capsLock: return "Caps Lock"
        case .escape: return "Escape"
        case .tab: return "Tab"
        case .returnKey: return "Return"
        case .delete: return "Delete"
        case .grave: return "` (obok 1)"
        case .section: return "§ (ISO)"
        case .fn: return "Fn / Globe"
        }
    }

    static func title(for usage: UInt64) -> String {
        allCases.first(where: { $0.usage == usage })?.title ?? String(format: "0x%llX", usage)
    }
}

@MainActor
final class KeyboardRemapper {
    static let shared = KeyboardRemapper()

    private var notificationPort: IONotificationPortRef?
    private var iterator: io_iterator_t = 0
    private var pendingApply: DispatchWorkItem?
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        Defaults.publisher(keys: .enableKeyboardRemap, .keyboardRemapPairs, .capsLockNoDelay).sink { [weak self] _ in
            Task { @MainActor in self?.apply() }
        }.store(in: &cancellables)

        let center = NSWorkspace.shared.notificationCenter
        center.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] _ in
            Task { @MainActor in self?.scheduleApply() }
        }.store(in: &cancellables)
        center.publisher(for: NSWorkspace.sessionDidBecomeActiveNotification).sink { [weak self] _ in
            Task { @MainActor in self?.scheduleApply() }
        }.store(in: &cancellables)

        installDeviceWatcher()
        apply()
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
        pendingApply?.cancel()
        let item = DispatchWorkItem { [weak self] in
            Task { @MainActor in self?.apply() }
        }
        pendingApply = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: item)
    }

    private func apply() {
        let enabled = Defaults[.enableKeyboardRemap]
        let pairs = enabled ? Defaults[.keyboardRemapPairs].filter { $0.from != $0.to } : []
        let entries = pairs.map {
            "{\"HIDKeyboardModifierMappingSrc\":\($0.from),\"HIDKeyboardModifierMappingDst\":\($0.to)}"
        }.joined(separator: ",")
        var json = "{\"UserKeyMapping\":[\(entries)]"
        if enabled && Defaults[.capsLockNoDelay] {
            json += ",\"CapsLockDelayOverride\":0"
        }
        json += "}"
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/hidutil")
        task.arguments = ["property", "--set", json]
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        try? task.run()
    }
}

struct KeyboardRemapSettingsView: View {
    @Default(.enableKeyboardRemap) private var enabled
    @Default(.keyboardRemapPairs) private var pairs
    @Default(.capsLockNoDelay) private var capsNoDelay

    var body: some View {
        Form {
            Section {
                Toggle("Mapowanie klawiszy", isOn: $enabled)
                Toggle("Caps Lock bez opóźnienia", isOn: $capsNoDelay)
                    .disabled(!enabled)
            } footer: {
                Text("Działa przez systemowe narzędzie hidutil, bez przechwytywania klawiatury. Mapowanie jest przywracane po podłączeniu klawiatury i wybudzeniu Maca. Po wyłączeniu „Caps Lock bez opóźnienia” systemowe opóźnienie wraca po ponownym zalogowaniu.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Zamiany klawiszy") {
                ForEach($pairs) { $pair in
                    HStack(spacing: 10) {
                        keyPicker(selection: $pair.from)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.secondary)
                        keyPicker(selection: $pair.to)
                        Button {
                            pairs.removeAll { $0.id == pair.id }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                        .help("Usuń zamianę")
                    }
                    .disabled(!enabled)
                }
                if pairs.isEmpty {
                    Text("Brak zamian.")
                        .foregroundStyle(.secondary)
                }
                HStack {
                    Button("Dodaj zamianę") {
                        pairs.append(KeyRemapPair(from: RemappableKey.capsLock.usage, to: RemappableKey.escape.usage))
                    }
                    Spacer()
                    Button("Przywróć domyślne") {
                        pairs = KeyRemapPair.defaults
                        capsNoDelay = true
                    }
                }
                .disabled(!enabled)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("Klawiatura")
    }

    private func keyPicker(selection: Binding<UInt64>) -> some View {
        Picker("", selection: selection) {
            ForEach(RemappableKey.allCases) { key in
                Text(key.title).tag(key.usage)
            }
            if !RemappableKey.allCases.contains(where: { $0.usage == selection.wrappedValue }) {
                Text(RemappableKey.title(for: selection.wrappedValue)).tag(selection.wrappedValue)
            }
        }
        .labelsHidden()
        .frame(maxWidth: .infinity)
    }
}
