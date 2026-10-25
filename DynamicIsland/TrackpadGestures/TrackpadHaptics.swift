import AppKit
import Foundation
import SwiftUI

final class TrackpadHaptics: @unchecked Sendable {
    static let shared = TrackpadHaptics()

    enum Pattern {
        case step
        case confirm
    }

    static let strengthKey = "trackpadHapticStrength"
    static let strengthRange = 1...6

    static var strength: Int {
        let stored = UserDefaults.standard.integer(forKey: strengthKey)
        return strengthRange.contains(stored) ? stored : 2
    }

    private func actuationID(for pattern: Pattern) -> Int32 {
        let base = Self.strength
        switch pattern {
        case .step: return Int32(base)
        case .confirm: return Int32(min(base + 2, Self.strengthRange.upperBound))
        }
    }

    private typealias DeviceCreateDefault = @convention(c) () -> OpaquePointer?
    private typealias DeviceGetID = @convention(c) (OpaquePointer, UnsafeMutablePointer<UInt64>) -> Int32
    private typealias ActuatorCreate = @convention(c) (UInt64) -> OpaquePointer?
    private typealias ActuatorOpen = @convention(c) (OpaquePointer) -> Int32
    private typealias ActuatorIsOpen = @convention(c) (OpaquePointer) -> Bool
    private typealias ActuatorActuate = @convention(c) (OpaquePointer, Int32, UInt32, Float, Float) -> Int32

    private let lock = NSLock()
    private var handle: UnsafeMutableRawPointer?
    private var actuator: OpaquePointer?
    private var failures = 0

    private var createDefault: DeviceCreateDefault?
    private var getID: DeviceGetID?
    private var create: ActuatorCreate?
    private var open: ActuatorOpen?
    private var isOpen: ActuatorIsOpen?
    private var actuate: ActuatorActuate?

    private init() {
        handle = dlopen("/System/Library/PrivateFrameworks/MultitouchSupport.framework/MultitouchSupport", RTLD_NOW)
        guard let handle else { return }
        createDefault = symbol("MTDeviceCreateDefault", handle)
        getID = symbol("MTDeviceGetDeviceID", handle)
        create = symbol("MTActuatorCreateFromDeviceID", handle)
        open = symbol("MTActuatorOpen", handle)
        isOpen = symbol("MTActuatorIsOpen", handle)
        actuate = symbol("MTActuatorActuate", handle)
        NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: nil) { [weak self] _ in
            self?.reset()
        }
    }

    private func symbol<T>(_ name: String, _ handle: UnsafeMutableRawPointer) -> T? {
        guard let pointer = dlsym(handle, name) else { return nil }
        return unsafeBitCast(pointer, to: T.self)
    }

    func reset() {
        lock.lock()
        actuator = nil
        failures = 0
        lock.unlock()
    }

    private func preparedActuator() -> OpaquePointer? {
        if let actuator { return actuator }
        guard let createDefault, let getID, let create, let open,
              let device = createDefault() else { return nil }
        var deviceID: UInt64 = 0
        guard getID(device, &deviceID) == 0, deviceID != 0,
              let created = create(deviceID), open(created) == 0 else { return nil }
        actuator = created
        return created
    }

    func perform(_ pattern: Pattern) {
        lock.lock()
        var done = false
        if let actuate, let target = preparedActuator() {
            if let isOpen, let open, !isOpen(target) { _ = open(target) }
            if actuate(target, actuationID(for: pattern), 0, 0, 0) == 0 {
                failures = 0
                done = true
            } else {
                failures += 1
                if failures >= 5 {
                    actuator = nil
                    failures = 0
                }
            }
        }
        lock.unlock()
        guard !done else { return }
        DispatchQueue.main.async {
            NSHapticFeedbackManager.defaultPerformer.perform(pattern == .step ? .levelChange : .alignment, performanceTime: .now)
        }
    }
}

struct HapticStrengthRow: View {
    @AppStorage(TrackpadHaptics.strengthKey) private var strength = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Siła haptyki")
                Spacer()
                Text("\(strength) / \(TrackpadHaptics.strengthRange.upperBound)")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Button("Wypróbuj") { TrackpadHaptics.shared.perform(.step) }
            }
            Slider(
                value: Binding(get: { Double(strength) }, set: { strength = Int($0.rounded()) }),
                in: Double(TrackpadHaptics.strengthRange.lowerBound)...Double(TrackpadHaptics.strengthRange.upperBound),
                step: 1
            )
            .onChange(of: strength) { _, _ in TrackpadHaptics.shared.perform(.step) }
            Text("Siła tyknięcia przy każdym kroku głośności, jasności i karty. Otwarcie aplikacji z rogu daje tyknięcie o 2 poziomy mocniejsze.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
