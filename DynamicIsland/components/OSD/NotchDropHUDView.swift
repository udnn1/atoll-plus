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
import SwiftUI
import Defaults

@MainActor
final class NotchDropHUDState: ObservableObject {
    @Published var type: SneakContentType = .volume
    @Published var value: CGFloat = 0
    @Published var icon: String = ""
    @Published var isExpanded = false
    @Published var stretch: CGFloat = 0

    let notchSize: CGSize

    init(notchSize: CGSize) {
        self.notchSize = notchSize
    }

    var isMuted: Bool {
        type == .volume && value <= 0.001
    }
}

enum NotchDropHUDMetrics {
    static let contentHeight: CGFloat = 34
    static let sideExtension: CGFloat = 62
    static let minimumExpandedWidth: CGFloat = 300
    static let stretchRoom: CGFloat = 48
    static let shadowRoom: CGFloat = 24

    static func expandedSize(for notch: CGSize) -> CGSize {
        CGSize(
            width: max(notch.width + sideExtension * 2, minimumExpandedWidth),
            height: notch.height + contentHeight
        )
    }

    static func windowSize(for notch: CGSize) -> CGSize {
        let expanded = expandedSize(for: notch)
        return CGSize(width: expanded.width + stretchRoom, height: expanded.height + shadowRoom)
    }
}

struct NotchDropHUDView: View {
    @ObservedObject var state: NotchDropHUDState
    @Default(.notchDropHUDShowPercentage) private var showPercentage
    @Default(.notchDropHUDUseAccentColor) private var useAccentColor

    private let expandSpring = Animation.spring(response: 0.42, dampingFraction: 0.7)
    private let collapseSpring = Animation.spring(response: 0.34, dampingFraction: 0.92)
    private let fillSpring = Animation.spring(response: 0.26, dampingFraction: 0.8)

    private var expandedSize: CGSize {
        NotchDropHUDMetrics.expandedSize(for: state.notchSize)
    }

    private var shapeSize: CGSize {
        state.isExpanded ? expandedSize : state.notchSize
    }

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(
                topCornerRadius: state.isExpanded ? 10 : 6,
                bottomCornerRadius: state.isExpanded ? 20 : 14
            )
            .fill(Color.black)
            .frame(width: shapeSize.width, height: shapeSize.height)
            .shadow(color: .black.opacity(state.isExpanded ? 0.35 : 0), radius: 8, y: 3)

            content
                .frame(width: expandedSize.width - 20, height: NotchDropHUDMetrics.contentHeight)
                .padding(.top, state.notchSize.height)
                .opacity(state.isExpanded ? 1 : 0)
                .blur(radius: state.isExpanded ? 0 : 6)
                .scaleEffect(state.isExpanded ? 1 : 0.7, anchor: .top)
                .offset(y: state.isExpanded ? 0 : -10)
                .animation(
                    state.isExpanded ? expandSpring.delay(0.07) : .easeIn(duration: 0.12),
                    value: state.isExpanded
                )
        }
        .scaleEffect(x: 1 + state.stretch, y: 1 - state.stretch * 0.5, anchor: .top)
        .animation(state.isExpanded ? expandSpring : collapseSpring, value: state.isExpanded)
        .animation(.interpolatingSpring(stiffness: 420, damping: 14), value: state.stretch)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .allowsHitTesting(false)
    }

    private var content: some View {
        HStack(spacing: 12) {
            Image(systemName: symbolName, variableValue: symbolVariableValue)
                .font(.system(size: 15, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
                .symbolEffect(.bounce, value: state.isMuted)
                .frame(width: 22)

            bar

            if showPercentage {
                HUDNumericLabel(
                    value: state.value,
                    font: .system(size: 12, weight: .semibold, design: .rounded),
                    color: .white.opacity(0.85),
                    alignment: .trailing,
                    width: 30,
                    minimumDigits: 1
                )
            }
        }
        .padding(.horizontal, 22)
    }

    private var bar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.18))
                Capsule()
                    .fill(fillColor)
                    .frame(width: max(state.value > 0 ? 6 : 0, geo.size.width * min(max(state.value, 0), 1)))
                    .shadow(color: fillColor.opacity(0.5), radius: state.isMuted ? 0 : 4)
            }
            .frame(height: 6)
            .frame(maxHeight: .infinity, alignment: .center)
            .animation(fillSpring, value: state.value)
        }
        .frame(height: 6)
    }

    private var fillColor: Color {
        if state.isMuted { return .white.opacity(0.35) }
        return useAccentColor ? .accentColor : .white
    }

    private var symbolName: String {
        if !state.icon.isEmpty { return state.icon }
        switch state.type {
        case .volume:
            return state.isMuted ? "speaker.slash.fill" : "speaker.wave.3.fill"
        case .brightness:
            return "sun.max.fill"
        case .backlight:
            return "light.max"
        default:
            return "circle.fill"
        }
    }

    private var symbolVariableValue: Double? {
        guard state.icon.isEmpty, !state.isMuted else { return nil }
        switch state.type {
        case .volume, .brightness:
            return Double(state.value)
        default:
            return nil
        }
    }
}
#endif
