import AppKit
import SwiftUI
import Combine

@MainActor
final class SlidrTrackpadController {
    static let shared = SlidrTrackpadController()

    let settingsStore = SettingsStore()
    let permissionManager = PermissionManager()
    let pipelineStatus = InputPipelineStatus()
    let gestureTestController = GestureTestController()

    private lazy var gestureDispatchRouter = GestureDispatchRouter(preview: gestureTestController)
    private var cancellables = Set<AnyCancellable>()
    private let systemControl = SystemControl()
    private let terminationWaiter = PipelineTerminationWaiter(timeout: 2)
    private var started = false

    private lazy var pipelineFactory = ProductionInputPipelineFactory(
        actionHandler: { [weak self] gesture in self?.dispatch(gesture: gesture) },
        inputObserver: { [weak self] event, settings in self?.gestureTestController.observe(event, settings: settings) }
    )
    private lazy var pipelineCoordinator = InputPipelineCoordinator(
        factory: pipelineFactory,
        status: pipelineStatus,
        refreshPermission: { PermissionManager.currentSnapshot().accessibility },
        schedule: { delay, work in DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work) }
    )

    private init() {}

    func start() {
        guard !started else { return }
        started = true

        gestureTestController.onStateChange = { [weak self] in
            self?.updateInputPipeline(refreshPermission: false)
        }

        settingsStore.$settings.sink { [weak self] _ in
            self?.updateInputPipeline(refreshPermission: false)
        }.store(in: &cancellables)

        permissionManager.$snapshot.dropFirst().sink { [weak self] _ in
            if self?.permissionManager.snapshot.accessibility != .granted {
                self?.gestureTestController.stop()
            }
            self?.updateInputPipeline(refreshPermission: false)
        }.store(in: &cancellables)

        NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification).sink { [weak self] _ in
            self?.updateInputPipeline(refreshPermission: true)
        }.store(in: &cancellables)

        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.willSleepNotification).sink { [weak self] _ in
            self?.gestureTestController.stop()
            self?.pipelineCoordinator.willSleep()
        }.store(in: &cancellables)
        NSWorkspace.shared.notificationCenter.publisher(for: NSWorkspace.didWakeNotification).sink { [weak self] _ in
            self?.pipelineCoordinator.didWake()
        }.store(in: &cancellables)

        updateInputPipeline(refreshPermission: false)
    }

    func stop() {
        guard started else { return }
        gestureTestController.stop()
        let stopped = terminationWaiter.waitForStop { [pipelineCoordinator] completion in
            pipelineCoordinator.terminate(completion: completion)
        }
        if !stopped {
            pipelineStatus.update(failure: "Input pipeline stop timed out during termination.")
        }
    }

    private func updateInputPipeline(refreshPermission: Bool) {
        let snapshot = refreshPermission ? permissionManager.currentSnapshot() : permissionManager.snapshot
        pipelineCoordinator.update(
            settings: settingsStore.settings,
            permission: snapshot.accessibility,
            previewMode: gestureTestController.isTesting
        )
    }

    private func dispatch(gesture: RecognizedGesture) {
        let actions = gestureDispatchRouter.actions(for: gesture, settings: settingsStore.settings)
        actions.forEach(execute(action:))
    }

    private func execute(action: SystemAction) {
        let result: SystemActionResult
        switch action {
        case .adjustVolume(let delta): result = systemControl.adjustVolume(delta: delta)
        case .adjustBrightness(let delta): result = systemControl.adjustBrightness(delta: delta)
        case .switchBrowserTab(let direction):
            result = systemControl.switchBrowserTab(
                direction: direction,
                wrapsAround: settingsStore.settings.browserTabWrapsAround
            )
        case .toggleApplication(let binding): result = systemControl.activateOrMinimizeApplication(binding)
        case .middleClick: result = systemControl.middleClick()
        }
        guard case .success = result else { return }
        switch action {
        case .adjustVolume, .adjustBrightness, .switchBrowserTab:
            NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .now)
        case .toggleApplication:
            NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        case .middleClick:
            break
        }
    }
}

struct TrackpadGesturesSettingsPane: View {
    private let controller = SlidrTrackpadController.shared

    var body: some View {
        SlidrSettingsView(
            store: controller.settingsStore,
            permissionManager: controller.permissionManager,
            pipelineStatus: controller.pipelineStatus,
            gestureTestController: controller.gestureTestController
        )
    }
}
