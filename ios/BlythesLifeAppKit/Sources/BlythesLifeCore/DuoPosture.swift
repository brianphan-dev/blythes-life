import CoreGraphics
import Foundation
import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

/// Physical fold axis of a hinged display.
public enum HingeAxis: String, Codable, Sendable, Equatable, Hashable {
    case vertical
    case horizontal
}

/// Cross-platform representation of `UIHinge.Status` so posture resolution is 100% unit-testable on macOS and iOS.
public enum HingeHardwareStatus: String, Codable, Sendable, Equatable, Hashable {
    case unknown
    case closed
    case partiallyOpen
    case fullyOpen
}

/// Cross-platform size class abstraction (since `SwiftUI.UserInterfaceSizeClass` is unavailable on macOS).
public enum LayoutSizeClass: String, Codable, Sendable, Equatable, Hashable {
    case compact
    case regular
}

/// Resolved adaptive device posture across iPhone, iPhone Duo, and iPad.
public enum DevicePosture: Sendable, Equatable {
    case compactPhone
    case duoFolded
    case duoUnfolded(hingeRect: CGRect, axis: HingeAxis)
    case duoTabletop(hingeRect: CGRect)
    case iPadRegular
}

/// Developer / simulator posture preview override so every hardware state can be verified in standard simulators.
public enum PosturePreviewOverride: String, CaseIterable, Codable, Sendable, Identifiable, Hashable {
    case automatic
    case iPhone
    case duoFolded
    case duoUnfolded
    case duoTabletop
    case iPad

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .automatic: "Automatic"
        case .iPhone: "iPhone"
        case .duoFolded: "iPhone Duo · Folded"
        case .duoUnfolded: "iPhone Duo · Unfolded"
        case .duoTabletop: "iPhone Duo · Tabletop"
        case .iPad: "iPad"
        }
    }

    public var shortTitle: String {
        switch self {
        case .automatic: "Auto"
        case .iPhone: "iPhone"
        case .duoFolded: "Folded"
        case .duoUnfolded: "Unfolded"
        case .duoTabletop: "Tabletop"
        case .iPad: "iPad"
        }
    }
}

/// Complete layout state distributed via `@Environment(\.duoLayout)`.
public struct DuoLayoutState: Sendable, Equatable {
    public var posture: DevicePosture
    public var hingeRect: CGRect?
    public var hingeAngleRadians: Double?
    public var containerSize: CGSize

    public init(
        posture: DevicePosture = .compactPhone,
        hingeRect: CGRect? = nil,
        hingeAngleRadians: Double? = nil,
        containerSize: CGSize = .zero
    ) {
        self.posture = posture
        self.hingeRect = hingeRect
        self.hingeAngleRadians = hingeAngleRadians
        self.containerSize = containerSize
    }

    public var isUnfoldedDuo: Bool {
        if case .duoUnfolded = posture { return true }
        return false
    }

    public var isTabletop: Bool {
        if case .duoTabletop = posture { return true }
        return false
    }

    public var isFoldedDuo: Bool {
        posture == .duoFolded
    }

    public var isPad: Bool {
        posture == .iPadRegular
    }

    /// Tabletop nightstand mode always forces true-black night palette to protect sleep.
    public var shouldForceNightMode: Bool {
        isTabletop
    }

    /// Two-column adaptive split layouts apply on unfolded iPhone Duo and regular-width iPad.
    public var usesSplitLayout: Bool {
        isUnfoldedDuo || isPad
    }

    public var hingeAxis: HingeAxis? {
        switch posture {
        case .duoUnfolded(_, let axis):
            return axis
        case .duoTabletop:
            return .horizontal
        case .compactPhone, .duoFolded, .iPadRegular:
            return nil
        }
    }

    /// Leading pane width excluding a vertical hinge safe zone when available.
    public var leadingPaneWidth: CGFloat? {
        guard case .duoUnfolded(let rect, .vertical) = posture, containerSize.width > 0 else {
            return nil
        }
        return max(0, rect.minX)
    }

    /// Trailing pane width excluding a vertical hinge safe zone when available.
    public var trailingPaneWidth: CGFloat? {
        guard case .duoUnfolded(let rect, .vertical) = posture, containerSize.width > 0 else {
            return nil
        }
        return max(0, containerSize.width - rect.maxX)
    }

    /// Top pane height above a horizontal hinge crease (tabletop or landscape horizontal split).
    public var topPaneHeight: CGFloat? {
        guard let rect = hingeRect, hingeAxis == .horizontal, containerSize.height > 0 else {
            return nil
        }
        return max(0, rect.minY)
    }

    /// Bottom pane height below a horizontal hinge crease (tabletop controls deck).
    public var bottomPaneHeight: CGFloat? {
        guard let rect = hingeRect, hingeAxis == .horizontal, containerSize.height > 0 else {
            return nil
        }
        return max(0, containerSize.height - rect.maxY)
    }
}

/// Pure deterministic resolver translating container geometry, size class, hardware hinge state, and preview overrides into `DuoLayoutState`.
public enum DuoPostureResolver: Sendable {
    /// Tabletop angle window in radians (~40° to ~152°).
    public static let tabletopAngleRange: ClosedRange<Double> = 0.70 ... 2.65
    private static let syntheticHingeThickness: CGFloat = 20

    public static func resolve(
        containerSize: CGSize,
        horizontalSizeClass: LayoutSizeClass?,
        hingeStatus: HingeHardwareStatus?,
        hingeAngle: Double?,
        divisionRect: CGRect?,
        override: PosturePreviewOverride = .automatic
    ) -> DuoLayoutState {
        let validDivision = normalizedDivisionRect(divisionRect)

        switch override {
        case .iPhone:
            return DuoLayoutState(
                posture: .compactPhone,
                hingeRect: nil,
                hingeAngleRadians: nil,
                containerSize: containerSize
            )

        case .duoFolded:
            return DuoLayoutState(
                posture: .duoFolded,
                hingeRect: nil,
                hingeAngleRadians: 0,
                containerSize: containerSize
            )

        case .duoUnfolded:
            let rect = validDivision ?? syntheticVerticalHinge(in: containerSize)
            return DuoLayoutState(
                posture: .duoUnfolded(hingeRect: rect, axis: .vertical),
                hingeRect: rect,
                hingeAngleRadians: .pi,
                containerSize: containerSize
            )

        case .duoTabletop:
            let rect = validDivision ?? syntheticHorizontalHinge(in: containerSize)
            return DuoLayoutState(
                posture: .duoTabletop(hingeRect: rect),
                hingeRect: rect,
                hingeAngleRadians: .pi / 2,
                containerSize: containerSize
            )

        case .iPad:
            return DuoLayoutState(
                posture: .iPadRegular,
                hingeRect: nil,
                hingeAngleRadians: nil,
                containerSize: containerSize
            )

        case .automatic:
            return resolveAutomatic(
                containerSize: containerSize,
                horizontalSizeClass: horizontalSizeClass,
                hingeStatus: hingeStatus,
                hingeAngle: hingeAngle,
                divisionRect: validDivision
            )
        }
    }

    private static func resolveAutomatic(
        containerSize: CGSize,
        horizontalSizeClass: LayoutSizeClass?,
        hingeStatus: HingeHardwareStatus?,
        hingeAngle: Double?,
        divisionRect: CGRect?
    ) -> DuoLayoutState {
        if let hingeStatus {
            switch hingeStatus {
            case .closed:
                return DuoLayoutState(
                    posture: .duoFolded,
                    hingeRect: nil,
                    hingeAngleRadians: hingeAngle ?? 0,
                    containerSize: containerSize
                )

            case .partiallyOpen:
                if let rect = divisionRect {
                    let axis = axis(for: rect)
                    if axis == .vertical {
                        return DuoLayoutState(
                            posture: .duoUnfolded(hingeRect: rect, axis: .vertical),
                            hingeRect: rect,
                            hingeAngleRadians: hingeAngle,
                            containerSize: containerSize
                        )
                    } else {
                        return DuoLayoutState(
                            posture: .duoTabletop(hingeRect: rect),
                            hingeRect: rect,
                            hingeAngleRadians: hingeAngle,
                            containerSize: containerSize
                        )
                    }
                } else {
                    let rect = syntheticHorizontalHinge(in: containerSize)
                    return DuoLayoutState(
                        posture: .duoTabletop(hingeRect: rect),
                        hingeRect: rect,
                        hingeAngleRadians: hingeAngle ?? (.pi / 2),
                        containerSize: containerSize
                    )
                }

            case .fullyOpen:
                let rect = divisionRect ?? syntheticVerticalHinge(in: containerSize)
                let detectedAxis = divisionRect.map(axis(for:)) ?? .vertical
                return DuoLayoutState(
                    posture: .duoUnfolded(hingeRect: rect, axis: detectedAxis),
                    hingeRect: rect,
                    hingeAngleRadians: hingeAngle ?? .pi,
                    containerSize: containerSize
                )

            case .unknown:
                break
            }
        }

        // Division region active even when hinge status is unavailable/unknown (e.g. simulator or early layout pass).
        if let rect = divisionRect {
            let detectedAxis = axis(for: rect)
            if detectedAxis == .horizontal, let hingeAngle, tabletopAngleRange.contains(hingeAngle) {
                return DuoLayoutState(
                    posture: .duoTabletop(hingeRect: rect),
                    hingeRect: rect,
                    hingeAngleRadians: hingeAngle,
                    containerSize: containerSize
                )
            }
            return DuoLayoutState(
                posture: .duoUnfolded(hingeRect: rect, axis: detectedAxis),
                hingeRect: rect,
                hingeAngleRadians: hingeAngle,
                containerSize: containerSize
            )
        }

        // Standard non-hinged Apple devices: distinguish iPad regular from landscape iPhone Pro Max.
        let minDimension = min(containerSize.width, containerSize.height)
        if horizontalSizeClass == .regular && (containerSize == .zero || minDimension >= 600) {
            return DuoLayoutState(
                posture: .iPadRegular,
                hingeRect: nil,
                hingeAngleRadians: nil,
                containerSize: containerSize
            )
        }

        return DuoLayoutState(
            posture: .compactPhone,
            hingeRect: nil,
            hingeAngleRadians: nil,
            containerSize: containerSize
        )
    }

    private static func normalizedDivisionRect(_ rect: CGRect?) -> CGRect? {
        guard let rect, !rect.isNull, !rect.isInfinite, rect.width > 0, rect.height > 0 else {
            return nil
        }
        return rect
    }

    private static func axis(for rect: CGRect) -> HingeAxis {
        rect.width >= rect.height ? .horizontal : .vertical
    }

    private static func syntheticVerticalHinge(in size: CGSize) -> CGRect {
        let width = max(size.width, syntheticHingeThickness)
        let height = max(size.height, 1)
        return CGRect(
            x: max(0, (width - syntheticHingeThickness) / 2),
            y: 0,
            width: syntheticHingeThickness,
            height: height
        )
    }

    private static func syntheticHorizontalHinge(in size: CGSize) -> CGRect {
        let width = max(size.width, 1)
        let height = max(size.height, syntheticHingeThickness)
        return CGRect(
            x: 0,
            y: max(0, (height - syntheticHingeThickness) / 2),
            width: width,
            height: syntheticHingeThickness
        )
    }
}

#if os(iOS) || os(visionOS) || os(tvOS) || os(watchOS)
public extension LayoutSizeClass {
    init?(_ swiftUI: UserInterfaceSizeClass?) {
        switch swiftUI {
        case .compact: self = .compact
        case .regular: self = .regular
        case .none: return nil
        @unknown default: return nil
        }
    }
}

public extension DuoPostureResolver {
    static func resolve(
        containerSize: CGSize,
        horizontalSizeClass: UserInterfaceSizeClass?,
        hingeStatus: HingeHardwareStatus?,
        hingeAngle: Double?,
        divisionRect: CGRect?,
        override: PosturePreviewOverride = .automatic
    ) -> DuoLayoutState {
        resolve(
            containerSize: containerSize,
            horizontalSizeClass: LayoutSizeClass(horizontalSizeClass),
            hingeStatus: hingeStatus,
            hingeAngle: hingeAngle,
            divisionRect: divisionRect,
            override: override
        )
    }
}
#endif

// MARK: - SwiftUI Environment

private struct DuoLayoutEnvironmentKey: EnvironmentKey {
    static let defaultValue = DuoLayoutState()
}

public extension EnvironmentValues {
    var duoLayout: DuoLayoutState {
        get { self[DuoLayoutEnvironmentKey.self] }
        set { self[DuoLayoutEnvironmentKey.self] = newValue }
    }
}

// MARK: - iOS 27.1+ Real iPhone Duo Hardware Bridge

#if canImport(UIKit)
public struct DuoHardwareSnapshot: Sendable, Equatable {
    public var hingeStatus: HingeHardwareStatus?
    public var hingeAngleRadians: Double?
    public var divisionRect: CGRect?

    public init(
        hingeStatus: HingeHardwareStatus? = nil,
        hingeAngleRadians: Double? = nil,
        divisionRect: CGRect? = nil
    ) {
        self.hingeStatus = hingeStatus
        self.hingeAngleRadians = hingeAngleRadians
        self.divisionRect = divisionRect
    }
}

/// Transparent UIKit probe that attaches `UIHingeInteraction` and queries `view.reservedRegions(kind: .division)` on iOS 27.1+.
public struct DuoHardwareObserverView: UIViewRepresentable {
    public var onUpdate: @MainActor (DuoHardwareSnapshot) -> Void

    public init(onUpdate: @escaping @MainActor (DuoHardwareSnapshot) -> Void) {
        self.onUpdate = onUpdate
    }

    public func makeUIView(context: Context) -> DuoHardwareProbeView {
        let view = DuoHardwareProbeView()
        view.onUpdate = onUpdate
        return view
    }

    public func updateUIView(_ uiView: DuoHardwareProbeView, context: Context) {
        uiView.onUpdate = onUpdate
        uiView.refreshDivisionRegion()
    }
}

@MainActor
public final class DuoHardwareProbeView: UIView {
    var onUpdate: (@MainActor (DuoHardwareSnapshot) -> Void)?

    private var hingeInteractionBox: AnyObject?
    private var currentSnapshot = DuoHardwareSnapshot()
    private var lastPublishedSnapshot: DuoHardwareSnapshot?

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        isUserInteractionEnabled = false
        backgroundColor = .clear

        if #available(iOS 27.1, tvOS 27.1, visionOS 27.1, *) {
            let interaction = UIHingeInteraction { [weak self] _, update in
                guard let self else { return }
                self.handleHingeUpdate(update.hinge)
            }
            addInteraction(interaction)
            hingeInteractionBox = interaction
        }
    }

    public override func layoutSubviews() {
        super.layoutSubviews()
        refreshDivisionRegion()
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        refreshDivisionRegion()
    }

    func refreshDivisionRegion() {
        if #available(iOS 27.1, tvOS 27.1, visionOS 27.1, *) {
            let regions = reservedRegions(kind: .division)
            let activeFrame = regions.first(where: { $0.isActive && !$0.frame.isEmpty })?.frame
            if currentSnapshot.divisionRect != activeFrame {
                currentSnapshot.divisionRect = activeFrame
                publishIfChanged()
            }
        }
    }

    @available(iOS 27.1, tvOS 27.1, visionOS 27.1, *)
    private func handleHingeUpdate(_ hinge: UIHinge?) {
        if let hinge {
            currentSnapshot.hingeStatus = Self.mapStatus(hinge.status)
            currentSnapshot.hingeAngleRadians = Double(hinge.angle)
        } else {
            currentSnapshot.hingeStatus = nil
            currentSnapshot.hingeAngleRadians = nil
        }
        refreshDivisionRegion()
        publishIfChanged()
    }

    @available(iOS 27.1, tvOS 27.1, visionOS 27.1, *)
    private static func mapStatus(_ status: UIHinge.Status) -> HingeHardwareStatus {
        switch status {
        case .unknown: .unknown
        case .closed: .closed
        case .partiallyOpen: .partiallyOpen
        case .fullyOpen: .fullyOpen
        @unknown default: .unknown
        }
    }

    private func publishIfChanged() {
        guard currentSnapshot != lastPublishedSnapshot else { return }
        lastPublishedSnapshot = currentSnapshot
        let snapshot = currentSnapshot
        let callback = onUpdate
        Task { @MainActor in
            callback?(snapshot)
        }
    }
}
#endif
