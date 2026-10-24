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

enum MediaMateHUDOrientation {
    case vertical
    case horizontal

    static func forType(_ type: SneakContentType) -> MediaMateHUDOrientation {
        type == .volume ? .vertical : .horizontal
    }
}

@MainActor
final class MediaMateHUDState: ObservableObject {
    @Published var type: SneakContentType = .volume
    @Published var value: CGFloat = 0
    @Published var icon: String = ""
    @Published var isVisible = false
    @Published var lengthStretch: CGFloat = 1
    @Published var thicknessStretch: CGFloat = 1

    let orientation: MediaMateHUDOrientation

    init(orientation: MediaMateHUDOrientation) {
        self.orientation = orientation
    }

    var isMuted: Bool {
        type == .volume && value <= 0.001
    }
}

enum MediaMateHUDMetrics {
    static let length: CGFloat = 200
    static let thickness: CGFloat = 54
    static let cornerRadius: CGFloat = 15
    static let edgeMargin: CGFloat = 14
    static let windowPadding: CGFloat = 36

    static func hudSize(for orientation: MediaMateHUDOrientation) -> CGSize {
        switch orientation {
        case .vertical:
            return CGSize(width: thickness, height: length)
        case .horizontal:
            return CGSize(width: length * 1.45, height: thickness * 0.88)
        }
    }

    static func windowSize(for orientation: MediaMateHUDOrientation) -> CGSize {
        let size = hudSize(for: orientation)
        return CGSize(width: size.width + windowPadding * 2, height: size.height + windowPadding * 2)
    }
}

struct MediaMateHUDView: View {
    @ObservedObject var state: MediaMateHUDState
    @Default(.mediaMateHUDUseAccentColor) private var useAccentColor

    private let fillSpring = Animation.spring(response: 0.3, dampingFraction: 0.82)
    private let appearSpring = Animation.spring(response: 0.38, dampingFraction: 0.78)
    private let stretchSpring = Animation.interpolatingSpring(stiffness: 380, damping: 13)

    private var size: CGSize {
        MediaMateHUDMetrics.hudSize(for: state.orientation)
    }

    private var isVertical: Bool {
        state.orientation == .vertical
    }

    private var clampedValue: CGFloat {
        min(max(state.value, 0), 1)
    }

    var body: some View {
        ZStack(alignment: isVertical ? .bottom : .leading) {
            track
            fill
            iconLayer
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: MediaMateHUDMetrics.cornerRadius, style: .continuous))
        .shadow(color: .black.opacity(0.28), radius: 10, y: 4)
        .scaleEffect(
            x: isVertical ? state.thicknessStretch : state.lengthStretch,
            y: isVertical ? state.lengthStretch : state.thicknessStretch,
            anchor: stretchAnchor
        )
        .animation(stretchSpring, value: state.lengthStretch)
        .animation(stretchSpring, value: state.thicknessStretch)
        .scaleEffect(state.isVisible ? 1 : 0.86)
        .blur(radius: state.isVisible ? 0 : 12)
        .opacity(state.isVisible ? 1 : 0)
        .animation(state.isVisible ? appearSpring : .easeIn(duration: 0.22), value: state.isVisible)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    private var stretchAnchor: UnitPoint {
        isVertical ? .bottom : .leading
    }

    private var track: some View {
        ZStack {
            Rectangle().fill(.ultraThinMaterial)
            Rectangle().fill(Color.black.opacity(0.55))
        }
        .environment(\.colorScheme, .dark)
    }

    private var fill: some View {
        Rectangle()
            .fill(fillColor)
            .frame(
                width: isVertical ? size.width : size.width * clampedValue,
                height: isVertical ? size.height * clampedValue : size.height
            )
            .animation(fillSpring, value: clampedValue)
    }

    private var iconLayer: some View {
        ZStack {
            iconImage
                .foregroundStyle(Color.white.opacity(0.7))
            iconImage
                .foregroundStyle(Color(white: 0.42))
                .mask(alignment: isVertical ? .bottom : .leading) {
                    Rectangle()
                        .frame(
                            width: isVertical ? iconBoxSize : iconBoxSize * iconCoverage,
                            height: isVertical ? iconBoxSize * iconCoverage : iconBoxSize
                        )
                        .animation(fillSpring, value: clampedValue)
                }
        }
        .frame(width: iconBoxSize, height: iconBoxSize)
        .padding(isVertical ? .bottom : .leading, iconInset)
    }

    private var iconBoxSize: CGFloat { 26 }

    private var iconInset: CGFloat {
        isVertical ? 12 : 14
    }

    private var iconCoverage: CGFloat {
        let length = isVertical ? size.height : size.width
        let filled = length * clampedValue - iconInset
        return min(max(filled / iconBoxSize, 0), 1)
    }

    private var iconImage: some View {
        Image(systemName: symbolName, variableValue: symbolVariableValue)
            .font(.system(size: 17, weight: .medium))
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.bounce, value: state.isMuted)
            .frame(width: iconBoxSize, height: iconBoxSize)
    }

    private var fillColor: Color {
        useAccentColor ? .accentColor : Color(white: 0.93)
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
        guard state.icon.isEmpty, !state.isMuted, state.type == .volume else { return nil }
        return Double(clampedValue)
    }
}
#endif
