import AppKit
import Foundation

final class TrackpadHaptics: @unchecked Sendable {
    static let shared = TrackpadHaptics()

    enum Pattern: Int32 {
        case step = 2
        case confirm = 4
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
            if actuate(target, pattern.rawValue, 0, 0, 0) == 0 {
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
