import UIKit

enum PiPEdge: Equatable {
    case left, right

    var inwardDirection: CGFloat { self == .left ? 1 : -1 }
}

enum PiPPlacement: Equatable {
    case corner(PiPCorner)
    case tucked(edge: PiPEdge, centerY: CGFloat)
}

/// Keeps gesture intent independent of animation and window ownership.
struct PiPGeometry {
    var bounds: CGRect
    var insets: UIEdgeInsets
    var safeAreaInsets: UIEdgeInsets = .zero

    static let tabSize = CGSize(width: 32, height: 64)

    var visibleBounds: CGRect { bounds.inset(by: insets) }

    func fittedSize(_ size: CGSize) -> CGSize {
        let factor = min(1, max(1, visibleBounds.width) / size.width,
                         max(1, visibleBounds.height) / size.height)
        return CGSize(width: size.width * factor, height: size.height * factor)
    }

    func frame(for corner: PiPCorner, size: CGSize) -> CGRect {
        let size = fittedSize(size)
        return CGRect(origin: corner.stickyPoint(forFrame: CGRect(origin: .zero, size: size),
                                                inBounds: bounds, withInsets: insets), size: size)
    }

    func nearestCorner(to frame: CGRect, velocity: CGPoint = .zero) -> PiPCorner {
        let projectedOrigin = CGPoint(x: frame.minX + velocity.x * 0.25,
                                      y: frame.minY + velocity.y * 0.25)
        return PiPCorner.allCases.min {
            self.frame(for: $0, size: frame.size).origin.distanceSquared(toPoint: projectedOrigin)
                < self.frame(for: $1, size: frame.size).origin.distanceSquared(toPoint: projectedOrigin)
        } ?? .topLeft
    }

    func clampedCenterY(_ centerY: CGFloat, height: CGFloat) -> CGFloat {
        let lower = visibleBounds.minY + height / 2
        let upper = max(lower, visibleBounds.maxY - height / 2)
        return min(max(centerY, lower), upper)
    }

    func tuckedFrame(edge: PiPEdge, centerY: CGFloat, size: CGSize) -> CGRect {
        CGRect(x: edge == .left ? bounds.minX - size.width - 12 : bounds.maxX + 12,
               y: clampedCenterY(centerY, height: size.height) - size.height / 2,
               width: size.width, height: size.height)
    }

    func tabFrame(edge: PiPEdge, centerY: CGFloat) -> CGRect {
        CGRect(x: edge == .left ? bounds.minX + safeAreaInsets.left
                                : bounds.maxX - safeAreaInsets.right - Self.tabSize.width,
               y: clampedCenterY(centerY, height: Self.tabSize.height) - Self.tabSize.height / 2,
               width: Self.tabSize.width, height: Self.tabSize.height)
    }

    func placement(afterDragging frame: CGRect, translation: CGPoint, velocity: CGPoint,
                   startingCorner: PiPCorner, startingEdge: PiPEdge? = nil) -> PiPPlacement {
        let targetCorner = nearestCorner(to: frame, velocity: velocity)

        if let edge = startingEdge {
            let inwardDistance = translation.x * edge.inwardDirection
            let inwardVelocity = velocity.x * edge.inwardDirection
            if inwardDistance >= 44 || (inwardDistance > 8 && inwardVelocity >= 450) {
                return .corner(targetCorner)
            }
            return .tucked(edge: edge, centerY: clampedCenterY(frame.midY, height: frame.height))
        }

        // Momentum toward a different corner always wins over an edge crossing.
        let isCornerFlick = hypot(velocity.x, velocity.y) >= 650 && targetCorner != startingCorner
        let isHorizontalDrag = abs(translation.x) > max(24, abs(translation.y) * 1.25)
        let threshold = min(60, max(24, frame.width * 0.3))
        if !isCornerFlick && isHorizontalDrag {
            if bounds.minX - frame.minX >= threshold && translation.x < 0 {
                return .tucked(edge: .left, centerY: clampedCenterY(frame.midY, height: frame.height))
            }
            if frame.maxX - bounds.maxX >= threshold && translation.x > 0 {
                return .tucked(edge: .right, centerY: clampedCenterY(frame.midY, height: frame.height))
            }
        }
        return .corner(targetCorner)
    }
}
