import AppKit
import SwiftUI
import UniformTypeIdentifiers

private enum SettingsSection: String, CaseIterable, Identifiable {
    case overview
    case edges
    case corners
    case middleClick
    case diagnostics

    var id: String { rawValue }
    var title: String { slidrL("nav_\(rawValue)") }
    var icon: String {
        switch self {
        case .overview: return "heart.text.square"
        case .edges: return "rectangle.and.hand.point.up.left"
        case .corners: return "square.grid.2x2"
        case .middleClick: return "computermouse"
        case .diagnostics: return "stethoscope"
        }
    }
}

struct SlidrSettingsView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var permissionManager: PermissionManager
    @ObservedObject var pipelineStatus: InputPipelineStatus
    @ObservedObject var gestureTestController: GestureTestController
    @State private var selection: SettingsSection? = .overview
    @State private var launchAtLoginError: String?
    @State private var appSelectionError: String?
    @State private var showResetConfirmation = false
    @State private var diagnosticPreview: DiagnosticPreview?
    @State private var showCompatibility = false
    @State private var showPermissionRecovery = false

    private let healthResolver = AppHealthResolver()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ViewThatFits(in: .horizontal) {
                sectionPicker(showsTitles: true)
                sectionPicker(showsTitles: false)
            }
            .padding(.horizontal, 24)
            .padding(.top, 16)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    banners
                    detailView
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onChange(of: selection) { _ in gestureTestController.stop() }
        .onDisappear { gestureTestController.stop() }
        .sheet(item: $diagnosticPreview) { preview in
            DiagnosticPreviewSheet(text: preview.text) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(preview.text, forType: .string)
                diagnosticPreview = nil
            } cancel: {
                diagnosticPreview = nil
            }
        }
        .confirmationDialog(
            slidrL("reset_settings_title"),
            isPresented: $showResetConfirmation
        ) {
            Button(slidrL("reset_settings_confirm"), role: .destructive) {
                gestureTestController.stop()
                store.restoreDefaults()
            }
            Button(slidrL("cancel"), role: .cancel) {}
        } message: {
            Text(slidrL("reset_settings_message"))
        }
    }

    private func sectionPicker(showsTitles: Bool) -> some View {
        Picker("", selection: $selection) {
            ForEach(SettingsSection.allCases) { section in
                Group {
                    if showsTitles {
                        Text(section.title)
                    } else {
                        Image(systemName: section.icon)
                    }
                }
                .help(section.title)
                .tag(Optional(section))
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .fixedSize()
    }

    private var needsOnboarding: Bool {
        store.settings.experience.onboardingVersion < ExperienceSettings.currentOnboardingVersion
    }

    @ViewBuilder private var banners: some View {
        if !store.settings.experience.hasSeenV04Welcome {
            BannerView(
                text: slidrL("v04_welcome_banner"),
                actionTitle: slidrL("got_it")
            ) {
                var updated = store.settings
                updated.experience.hasSeenV04Welcome = true
                store.save(updated)
            }
        }
        if let diagnostic = store.lastLoadDiagnostic {
            BannerView(
                text: slidrL("settings_restored_banner"),
                actionTitle: slidrL("view_diagnostics")
            ) {
                selection = .diagnostics
                store.dismissLoadDiagnostic()
            }
            .accessibilityHint(diagnostic)
        }
        if store.lastSaveDiagnostic != nil {
            BannerView(text: slidrL("settings_save_error"))
        }
        if let launchAtLoginError {
            BannerView(text: launchAtLoginError)
        }
        if let appSelectionError {
            BannerView(text: appSelectionError)
        }
    }

    @ViewBuilder private var detailView: some View {
        switch selection ?? .overview {
        case .overview: overview
        case .edges: edgeSettings
        case .corners: cornerSettings
        case .middleClick: middleClickSettings
        case .diagnostics: diagnostics
        }
    }

    private var currentHealth: AppHealthState {
        healthResolver.resolve(settings: store.settings, permission: permissionManager.snapshot, pipeline: pipelineStatus)
    }

    private var overview: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("nav_overview", subtitleKey: "overview_subtitle")
            HealthCard(health: currentHealth, action: performHealthAction)

            GroupBox(slidrL("overview_general")) {
                VStack(alignment: .leading, spacing: 12) {
                    Toggle(slidrL("enable_app_toggle"), isOn: binding(\.isAppEnabled))
                    Divider()
                    HStack {
                        Text(slidrL("recent_touch"))
                        Spacer()
                        Text(lastFrameText).foregroundStyle(.secondary)
                    }
                }.padding(8)
            }

            DisclosureGroup(slidrL("compatibility_notes"), isExpanded: $showCompatibility) {
                Text(slidrL("physical_trackpad_experimental_warning"))
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
            }
        }
    }

    private var edgeSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("nav_edges", subtitleKey: "edges_subtitle")
            VStack(alignment: .leading, spacing: 18) {
                TrackpadDiagram(settings: store.settings)
                    .frame(width: 250, height: 190)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(slidrL("trackpad_mapping_diagram"))
                VStack(alignment: .leading, spacing: 14) {
                    sideEdgePicker("left_edge", keyPath: \.edgeAssignments.left)
                    sideEdgePicker("right_edge", keyPath: \.edgeAssignments.right)
                    topEdgePicker
                }
                .frame(maxWidth: .infinity)
            }
            if duplicateSideAssignment {
                Label(slidrL("duplicate_edge_hint"), systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            labeledSlider(
                slidrL("edge_width"),
                value: binding(\.gesture.edgeWidthPercent),
                range: GestureSettings.edgeWidthPercentRange,
                isPercent: true
            )
            GroupBox(slidrL("edge_step_distances")) {
                VStack(alignment: .leading, spacing: 12) {
                    labeledSlider(
                        slidrL("left_edge_step_distance"),
                        value: binding(\.gesture.leftPhysicalStepDistance),
                        range: GestureSettings.physicalStepDistanceRange,
                        isPercent: true
                    )
                    labeledSlider(
                        slidrL("right_edge_step_distance"),
                        value: binding(\.gesture.rightPhysicalStepDistance),
                        range: GestureSettings.physicalStepDistanceRange,
                        isPercent: true
                    )
                    labeledSlider(
                        slidrL("top_edge_step_distance"),
                        value: binding(\.gesture.topPhysicalStepDistance),
                        range: GestureSettings.physicalStepDistanceRange,
                        isPercent: true
                    )
                    Text(slidrL("edge_step_distance_help"))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(8)
            }
            GestureTestPanel(controller: gestureTestController, kind: .edge)
        }
    }

    private var cornerSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("nav_corners", subtitleKey: "corners_subtitle")
            VStack(alignment: .leading, spacing: 18) {
                CornerTrackpadDiagram(bindings: store.settings.cornerAppBindings)
                    .frame(width: 250, height: 190)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(slidrL("corner_mapping_diagram"))
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(TrackpadCorner.allCases, id: \.self) { corner in
                        cornerBindingRow(corner)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            labeledSlider(
                slidrL("corner_trigger_percent"),
                value: binding(\.gesture.cornerTriggerPercent),
                range: GestureSettings.cornerTriggerPercentRange,
                isPercent: true
            )
            Text(slidrL("corner_trigger_percent_help"))
                .font(.callout)
                .foregroundStyle(.secondary)
            labeledSlider(
                slidrL("corner_movement_tolerance"),
                value: binding(\.gesture.cornerMovementTolerancePercent),
                range: GestureSettings.cornerMovementTolerancePercentRange,
                isPercent: true,
                step: 0.01
            )
            Text(slidrL("corner_movement_tolerance_help"))
                .font(.callout)
                .foregroundStyle(.secondary)
            labeledSlider(
                slidrL("corner_double_tap_interval"),
                value: binding(\.gesture.cornerDoubleTapIntervalSeconds),
                range: GestureSettings.cornerDoubleTapIntervalRange,
                isPercent: false,
                step: 0.05
            )
            Text(slidrL("corner_double_tap_interval_help"))
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(slidrL("corner_double_tap_help"))
                .font(.callout)
                .foregroundStyle(.secondary)
            GestureTestPanel(controller: gestureTestController, kind: .corner)
        }
    }

    private var middleClickSettings: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("nav_middleClick", subtitleKey: "middle_click_subtitle")
            GroupBox {
                VStack(alignment: .leading, spacing: 14) {
                    Toggle(slidrL("middle_click_enable"), isOn: binding(\.middleClick.isEnabled))
                    Toggle(slidrL("middle_click_tap_enable"), isOn: binding(\.middleClick.tapEnabled))
                        .disabled(!store.settings.middleClick.isEnabled)
                    Picker(slidrL("middle_click_finger_count"), selection: binding(\.middleClick.fingerCount)) {
                        ForEach(MiddleClickSettings.supportedFingerCounts, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .disabled(!store.settings.middleClick.isEnabled)
                    Text(slidrL("middle_click_exact_count_help"))
                        .font(.callout).foregroundStyle(.secondary)
                    middleClickWarning
                }.padding(8)
            }
            GestureTestPanel(controller: gestureTestController, kind: .middleClick)
                .disabled(!store.settings.middleClick.isEnabled || !store.settings.middleClick.tapEnabled)
        }
    }

    private var diagnostics: some View {
        VStack(alignment: .leading, spacing: 18) {
            pageTitle("nav_diagnostics", subtitleKey: "diagnostics_subtitle")
            GroupBox(slidrL("diagnostic_status")) {
                VStack(spacing: 10) {
                    diagnosticRow("diagnostic_overall", slidrL(currentHealth.localizationKey))
                    diagnosticRow("accessibility", localizedPermission(permissionManager.snapshot.accessibility))
                    diagnosticRow("diagnostic_framework", localizedOptional(pipelineStatus.frameworkAvailable))
                    diagnosticRow("diagnostic_device", localizedOptional(pipelineStatus.deviceAvailable))
                    diagnosticRow("touch_monitor_status", localizedTouch(pipelineStatus.touchMonitor))
                    diagnosticRow("event_tap_status", eventTapDisplay)
                    diagnosticRow("recent_touch", lastFrameText)
                    diagnosticRow("diagnostic_last_failure", pipelineStatus.lastFailureReason ?? slidrL("none"))
                    diagnosticRow("diagnostic_version", versionText)
                    diagnosticRow("diagnostic_system", systemText)
                }.padding(8)
            }
            HStack {
                Button(slidrL("recheck")) { permissionManager.currentSnapshot() }
                Button(slidrL("copy_diagnostics")) { diagnosticPreview = DiagnosticPreview(text: diagnosticSummary) }
                Spacer()
            }
            DisclosureGroup(slidrL("permission_recovery_title"), isExpanded: $showPermissionRecovery) {
                Text(slidrL("permission_recovery_guidance"))
                    .font(.callout).foregroundStyle(.secondary).padding(.top, 8)
            }
            Divider()
            Button(slidrL("restore_defaults"), role: .destructive) { showResetConfirmation = true }
        }
    }

    @ViewBuilder private var middleClickWarning: some View {
        if store.settings.middleClick.fingerCount == 2 {
            Label(slidrL("middle_click_two_finger_warning"), systemImage: "exclamationmark.triangle.fill")
                .font(.callout).foregroundStyle(.orange)
        } else if store.settings.middleClick.fingerCount == 3 {
            Text(slidrL("middle_click_three_finger_drag_guidance"))
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    private func performHealthAction() {
        switch currentHealth {
        case .disabledByUser:
            var updated = store.settings; updated.isAppEnabled = true; store.save(updated)
        case .noGesturesConfigured:
            selection = .edges
        case .permissionRequired:
            permissionManager.promptForAccessibility()
        case .setupRequired:
            break
        case .hardwareUnavailable, .degraded, .starting, .recovering:
            permissionManager.currentSnapshot(); selection = .diagnostics
        case .ready:
            break
        }
    }

    private func pageTitle(_ titleKey: String, subtitleKey: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(slidrL(titleKey)).font(.largeTitle.bold())
            Text(slidrL(subtitleKey)).foregroundStyle(.secondary)
        }
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(get: { store.settings[keyPath: keyPath] }, set: { value in
            var updated = store.settings
            updated[keyPath: keyPath] = value
            store.save(updated)
        })
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(get: { store.settings.launchAtLogin }, set: { value in
            do {
                try permissionManager.setLaunchAtLogin(value)
                var updated = store.settings; updated.launchAtLogin = value; store.save(updated)
                launchAtLoginError = nil
            } catch {
                launchAtLoginError = String(format: slidrL("launch_at_login_error"), error.localizedDescription)
            }
        })
    }

    private func sideEdgePicker(_ labelKey: String, keyPath: WritableKeyPath<AppSettings, SideEdgeAction>) -> some View {
        Picker(slidrL(labelKey), selection: binding(keyPath)) {
            ForEach(SideEdgeAction.allCases, id: \.self) { action in
                Text(slidrL("side_action_\(action.rawValue)")).tag(action)
            }
        }
    }

    private func cornerBindingRow(_ corner: TrackpadCorner) -> some View {
        let binding = store.settings.cornerAppBindings[corner]
        return HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(slidrL(corner.localizationKey))
                    .font(.headline)
                Text(binding?.displayName ?? slidrL("corner_not_configured"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer()
            Button(slidrL(binding == nil ? "corner_choose_app" : "corner_change_app")) {
                chooseApplication(for: corner)
            }
            if binding != nil {
                Button(slidrL("corner_clear"), role: .destructive) {
                    clearApplication(for: corner)
                }
            }
        }
    }

    private func chooseApplication(for corner: TrackpadCorner) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.application]
        panel.allowsMultipleSelection = false
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.prompt = slidrL("corner_app_picker_prompt")
        panel.message = slidrL("corner_app_picker_message")
        if let path = store.settings.cornerAppBindings[corner]?.applicationPath {
            panel.directoryURL = URL(fileURLWithPath: path).deletingLastPathComponent()
        } else {
            panel.directoryURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
        }

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard url.pathExtension.lowercased() == "app",
              let bundle = Bundle(url: url),
              let bundleIdentifier = bundle.bundleIdentifier,
              !bundleIdentifier.isEmpty else {
            appSelectionError = slidrL("corner_app_picker_error")
            return
        }

        let displayName = (bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String)
            ?? (bundle.object(forInfoDictionaryKey: "CFBundleName") as? String)
            ?? url.deletingPathExtension().lastPathComponent
        var updated = store.settings
        updated.cornerAppBindings[corner] = ApplicationBinding(
            bundleIdentifier: bundleIdentifier,
            displayName: displayName,
            applicationPath: url.path
        )
        store.save(updated)
        appSelectionError = nil
    }

    private func clearApplication(for corner: TrackpadCorner) {
        var updated = store.settings
        updated.cornerAppBindings[corner] = nil
        store.save(updated)
        appSelectionError = nil
    }

    private var topEdgePicker: some View {
        VStack(alignment: .leading, spacing: 6) {
            Picker(slidrL("top_edge"), selection: binding(\.edgeAssignments.top)) {
                ForEach(TopEdgeAction.allCases, id: \.self) { action in
                    Text(slidrL("top_action_\(action.rawValue)")).tag(action)
                }
            }
            Toggle(
                slidrL("browser_tab_wraps_around"),
                isOn: binding(\.browserTabWrapsAround)
            )
            .disabled(store.settings.edgeAssignments.top != .browserTabs)
            Text(slidrL("browser_tab_wraps_around_help"))
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var duplicateSideAssignment: Bool {
        store.settings.edgeAssignments.left != .none && store.settings.edgeAssignments.left == store.settings.edgeAssignments.right
    }

    private func labeledSlider(
        _ title: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        isPercent: Bool,
        step: Double = 0.01
    ) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(sliderValue(value.wrappedValue, isPercent: isPercent))
                    .foregroundStyle(.secondary)
            }
            Slider(value: value, in: range, step: step)
        }
    }

    private func sliderValue(_ value: Double, isPercent: Bool) -> String {
        if isPercent {
            return value.formatted(.percent.precision(.fractionLength(0)))
        }
        return String(format: slidrL("seconds_value"), value)
    }

    private func diagnosticRow(_ key: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(slidrL(key))
            Spacer()
            Text(value).foregroundStyle(.secondary).multilineTextAlignment(.trailing).textSelection(.enabled)
        }
    }

    private func localizedPermission(_ state: PermissionState) -> String { slidrL(state.rawValue) }
    private func localizedOptional(_ value: Bool?) -> String {
        guard let value else { return slidrL("unknown") }
        return slidrL(value ? "available" : "unavailable")
    }
    private func localizedTouch(_ state: TouchMonitorRuntimeState) -> String { slidrL("pipeline_\(state.rawValue)") }
    private var eventTapDisplay: String {
        guard store.settings.middleClick.isEnabled else { return slidrL("not_enabled") }
        switch pipelineStatus.eventTap {
        case .stopped: return slidrL("pipeline_stopped")
        case .starting: return slidrL("pipeline_starting")
        case .running: return slidrL("pipeline_running")
        case .recoveryRequiresPipelineRestart: return slidrL("pipeline_restarting")
        case .degraded: return slidrL("pipeline_degraded")
        }
    }
    private var lastFrameText: String {
        guard let age = pipelineStatus.lastFrameAge else { return slidrL("no_recent_touch") }
        return String(format: slidrL("seconds_ago"), Int(age))
    }
    private var versionText: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "local"
        return "\(version) (\(build))"
    }
    private var systemText: String { "macOS \(ProcessInfo.processInfo.operatingSystemVersionString) · \(architecture)" }
    private var architecture: String {
#if arch(arm64)
        return "arm64"
#else
        return "x86_64"
#endif
    }
    private var diagnosticSummary: String {
        [
            "Slidr Free diagnostics",
            "health=\(currentHealth.rawValue)",
            "accessibility=\(permissionManager.snapshot.accessibility.rawValue)",
            "framework=\(pipelineStatus.frameworkAvailable.map(String.init) ?? "unknown")",
            "device=\(pipelineStatus.deviceAvailable.map(String.init) ?? "unknown")",
            "touchMonitor=\(pipelineStatus.touchMonitor.rawValue)",
            "physicalClickListener=\(store.settings.middleClick.isEnabled ? String(describing: pipelineStatus.eventTap) : "notEnabled")",
            "lastFrameAgeSeconds=\(pipelineStatus.lastFrameAge.map { String(Int($0)) } ?? "none")",
            "lastFailure=\(pipelineStatus.lastFailureReason ?? "none")",
            "version=\(versionText)",
            "system=\(systemText)"
        ].joined(separator: "\n")
    }
}

private struct HealthCard: View {
    let health: AppHealthState
    let action: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(tint).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 5) {
                Text(slidrL(health.localizationKey)).font(.headline)
                Text(slidrL("health_impact_\(health.rawValue)")).foregroundStyle(.secondary)
            }
            Spacer()
            if let key = health.actionLocalizationKey { Button(slidrL(key), action: action) }
        }
        .padding(16)
        .background(tint.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }

    private var icon: String {
        switch health {
        case .ready: return "checkmark.circle.fill"
        case .disabledByUser: return "pause.circle.fill"
        case .noGesturesConfigured: return "slider.horizontal.3"
        case .starting, .recovering: return "arrow.triangle.2.circlepath"
        default: return "exclamationmark.triangle.fill"
        }
    }
    private var tint: Color { health == .ready ? .green : (health == .disabledByUser ? .secondary : .orange) }
}

private struct BannerView: View {
    let text: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil
    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.circle.fill").accessibilityHidden(true)
            Text(text)
            Spacer()
            if let actionTitle, let action { Button(actionTitle, action: action) }
        }
        .padding(10).background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct GestureTestPanel: View {
    @ObservedObject var controller: GestureTestController
    let kind: GestureTestKind
    var body: some View {
        GroupBox(slidrL("gesture_test_title")) {
            VStack(alignment: .leading, spacing: 10) {
                Text(slidrL(helpLocalizationKey))
                    .font(.callout).foregroundStyle(.secondary)
                HStack {
                    if controller.kind == kind {
                        Button(slidrL("stop_test")) { controller.stop() }
                        Text(String(format: slidrL("test_seconds_remaining"), controller.secondsRemaining))
                            .foregroundStyle(.secondary)
                    } else {
                        Button(slidrL("start_safe_test")) { controller.start(kind) }
                    }
                    Spacer()
                    if let feedback = controller.feedback { Label(feedback, systemImage: controller.didRecognizeGesture ? "checkmark.circle.fill" : "waveform").foregroundStyle(controller.didRecognizeGesture ? .green : .secondary) }
                }
            }.padding(8)
        }
    }

    private var helpLocalizationKey: String {
        switch kind {
        case .edge: return "gesture_test_edge_help"
        case .corner: return "gesture_test_corner_help"
        case .middleClick: return "gesture_test_middle_help"
        }
    }
}

private struct TrackpadDiagram: View {
    let settings: AppSettings
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width, h = proxy.size.height
            ZStack {
                RoundedRectangle(cornerRadius: 18).fill(Color.secondary.opacity(0.08))
                RoundedRectangle(cornerRadius: 18).stroke(Color.secondary.opacity(0.4), lineWidth: 2)
                Rectangle().fill(Color.accentColor.opacity(0.16)).frame(width: w * settings.gesture.edgeWidthPercent).frame(maxWidth: .infinity, alignment: .leading)
                Rectangle().fill(Color.accentColor.opacity(0.16)).frame(width: w * settings.gesture.edgeWidthPercent).frame(maxWidth: .infinity, alignment: .trailing)
                Rectangle().fill(Color.accentColor.opacity(0.16)).frame(height: h * settings.gesture.edgeWidthPercent).frame(maxHeight: .infinity, alignment: .top)
                HStack {
                    edgeLabel(sideText(settings.edgeAssignments.left), arrow: "arrow.up.and.down")
                    Spacer()
                    edgeLabel(sideText(settings.edgeAssignments.right), arrow: "arrow.up.and.down")
                }.padding(12)
                VStack { edgeLabel(topText(settings.edgeAssignments.top), arrow: "arrow.left.and.right"); Spacer() }.padding(12)
            }.clipShape(RoundedRectangle(cornerRadius: 18))
        }
    }
    private func edgeLabel(_ text: String, arrow: String) -> some View { VStack { Image(systemName: arrow); Text(text).font(.caption.bold()) } }
    private func sideText(_ action: SideEdgeAction) -> String { slidrL("side_action_\(action.rawValue)") }
    private func topText(_ action: TopEdgeAction) -> String { slidrL("top_action_\(action.rawValue)") }
}

private struct CornerTrackpadDiagram: View {
    let bindings: CornerAppBindings

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.secondary.opacity(0.08))
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.secondary.opacity(0.4), lineWidth: 2)
            ForEach(TrackpadCorner.allCases, id: \.self) { corner in
                marker(for: corner)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: corner.alignment)
                    .padding(14)
            }
        }
    }

    private func marker(for corner: TrackpadCorner) -> some View {
        let binding = bindings[corner]
        return VStack(spacing: 3) {
            Image(systemName: binding == nil ? "plus.circle" : "app.fill")
                .foregroundStyle(binding == nil ? Color.secondary : Color.accentColor)
            Text(binding?.displayName ?? slidrL(corner.localizationKey))
                .font(.caption2.bold())
                .lineLimit(1)
                .frame(maxWidth: 92)
        }
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

    var alignment: Alignment {
        switch self {
        case .topLeft: return .topLeading
        case .topRight: return .topTrailing
        case .bottomLeft: return .bottomLeading
        case .bottomRight: return .bottomTrailing
        }
    }
}

private struct DiagnosticPreviewSheet: View {
    let text: String
    let copy: () -> Void
    let cancel: () -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(slidrL("diagnostic_preview_title")).font(.title2.bold())
            Text(slidrL("diagnostic_privacy_note")).foregroundStyle(.secondary)
            ScrollView { Text(text).font(.system(.body, design: .monospaced)).textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading) }
                .padding(10).background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            HStack { Spacer(); Button(slidrL("cancel"), action: cancel); Button(slidrL("copy"), action: copy).keyboardShortcut(.defaultAction) }
        }.padding(22).frame(width: 560, height: 420)
    }
}

private struct DiagnosticPreview: Identifiable {
    let id = UUID()
    let text: String
}
