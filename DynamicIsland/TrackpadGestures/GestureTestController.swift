import AppKit
import Combine
import Foundation

enum GestureTestKind: Equatable {
    case edge
    case corner
    case middleClick
}

final class GestureTestController: ObservableObject {
    @Published private(set) var kind: GestureTestKind?
    @Published private(set) var feedback: String?
    @Published private(set) var didRecognizeGesture = false
    @Published private(set) var secondsRemaining = 0

    var isTesting: Bool { kind != nil }
    var onStateChange: (() -> Void)?

    private var timer: Timer?
    private var deadline: Date?
    private var sawTouchFrame = false
    private var sawAssignedEdge = false
    private var sawCorner = false
    private var lastObservedEdgeKey: String?

    func start(_ kind: GestureTestKind) {
        stop()
        self.kind = kind
        feedback = slidrL("gesture_test_waiting")
        didRecognizeGesture = false
        sawTouchFrame = false
        sawAssignedEdge = false
        sawCorner = false
        lastObservedEdgeKey = nil
        deadline = Date().addingTimeInterval(15)
        secondsRemaining = 15
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        onStateChange?()
    }

    func stop() {
        let wasTesting = isTesting
        timer?.invalidate()
        timer = nil
        deadline = nil
        kind = nil
        secondsRemaining = 0
        if wasTesting { onStateChange?() }
    }

    @discardableResult
    func intercept(_ gesture: RecognizedGesture) -> Bool {
        guard let kind else { return false }
        let matches: Bool
        switch (kind, gesture) {
        case (.edge, .brightness), (.edge, .volume), (.edge, .browserTab),
             (.corner, .cornerDoubleTap), (.middleClick, .middleClickTap):
            matches = true
        default:
            matches = false
        }
        guard matches else { return true }
        feedback = localizedFeedback(for: gesture)
        didRecognizeGesture = true
        NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
        return true
    }

    func observe(_ event: NormalizedInputEvent, settings: AppSettings) {
        guard isTesting else { return }
        guard case .physicalTouchFrame(let touches, _) = event, !touches.isEmpty else { return }
        sawTouchFrame = true
        guard touches.count == 1 else { return }
        let touch = touches[0]
        if kind == .corner {
            sawCorner = sawCorner || TrackpadCorner.hit(
                for: touch,
                widthPercent: settings.gesture.cornerTriggerPercent
            ) != nil
            return
        }
        guard kind == .edge else { return }
        let width = settings.gesture.edgeWidthPercent
        if touch.x <= width, settings.edgeAssignments.left != .none {
            sawAssignedEdge = true
            lastObservedEdgeKey = "left_edge"
        } else if touch.x >= 1 - width, settings.edgeAssignments.right != .none {
            sawAssignedEdge = true
            lastObservedEdgeKey = "right_edge"
        } else if touch.y >= 1 - width, settings.edgeAssignments.top != .none {
            sawAssignedEdge = true
            lastObservedEdgeKey = "top_edge"
        }
    }

    private func tick() {
        guard let deadline else { return }
        secondsRemaining = max(0, Int(ceil(deadline.timeIntervalSinceNow)))
        if secondsRemaining == 0 { expire() }
    }

    func expire() {
        guard isTesting else { return }
        if !didRecognizeGesture {
            if !sawTouchFrame {
                feedback = slidrL("gesture_test_timeout_no_frames")
            } else if kind == .edge && !sawAssignedEdge {
                feedback = slidrL("gesture_test_timeout_no_edge")
            } else if kind == .corner && !sawCorner {
                feedback = slidrL("gesture_test_timeout_no_corner")
            } else {
                feedback = slidrL("gesture_test_timeout_threshold")
            }
        }
        stop()
    }

    private func localizedFeedback(for gesture: RecognizedGesture) -> String {
        switch gesture {
        case .brightness(let direction, _):
            return String(
                format: slidrL("gesture_test_brightness"),
                localizedObservedEdge,
                direction == .increase ? "+1" : "−1"
            )
        case .volume(let direction, _):
            return String(
                format: slidrL("gesture_test_volume"),
                localizedObservedEdge,
                direction == .increase ? "+1" : "−1"
            )
        case .browserTab(let direction):
            return slidrL(direction == .next ? "gesture_test_next_tab" : "gesture_test_previous_tab")
        case .cornerDoubleTap(let corner):
            return String(
                format: slidrL("gesture_test_corner"),
                slidrL(corner.localizationKey)
            )
        case .middleClickTap:
            return slidrL("gesture_test_middle_click")
        }
    }

    private var localizedObservedEdge: String {
        slidrL(lastObservedEdgeKey ?? "assigned_edge")
    }
}

private extension TrackpadCorner {
    var localizationKey: String {
        switch self {
        case .topLeft: return "corner_top_left"
        case .topRight: return "corner_top_right"
        case .bottomLeft: return "corner_bottom_left"
        case .bottomRight: return "corner_bottom_right"
        }
    }
}
