import XCTest
import UIKit
@testable import PiPKit

final class PiPPlacementTests: XCTestCase {
    private let geometry = PiPGeometry(bounds: CGRect(x: 0, y: 0, width: 400, height: 850),
                                       insets: UIEdgeInsets(top: 70, left: 16, bottom: 50, right: 16))

    func testVelocityAloneCannotTuck() {
        let frame = geometry.frame(for: .topLeft, size: CGSize(width: 200, height: 100))
        XCTAssertEqual(geometry.placement(afterDragging: frame, translation: CGPoint(x: -20, y: 0),
                                          velocity: CGPoint(x: -2000, y: 0), startingCorner: .topLeft),
                       .corner(.topLeft))
    }

    func testDeliberateOutwardDragsTuckBothEdges() {
        for (edge, x, translation) in [(PiPEdge.left, CGFloat(-70), CGFloat(-86)), (.right, 270, 86)] {
            let result = geometry.placement(afterDragging: CGRect(x: x, y: 200, width: 200, height: 100),
                                            translation: CGPoint(x: translation, y: 10), velocity: .zero,
                                            startingCorner: edge == .left ? .topLeft : .topRight)
            XCTAssertEqual(result, .tucked(edge: edge, centerY: 250))
        }
    }

    func testHorizontalFlickAcrossScreenLandsInOppositeCornerDespiteOvershoot() {
        let result = geometry.placement(afterDragging: CGRect(x: 275, y: 70, width: 200, height: 100),
                                        translation: CGPoint(x: 259, y: 0), velocity: CGPoint(x: 1000, y: 0),
                                        startingCorner: .topLeft)
        XCTAssertEqual(result, .corner(.topRight))
    }

    func testDiagonalCornerFlickDoesNotTuck() {
        XCTAssertEqual(geometry.placement(afterDragging: CGRect(x: 270, y: 450, width: 200, height: 100),
                                          translation: CGPoint(x: 254, y: 380),
                                          velocity: CGPoint(x: 900, y: 1500), startingCorner: .topLeft),
                       .corner(.bottomRight))
    }

    func testEveryCornerTransferWinsOverTuckingDuringAFlick() {
        let size = CGSize(width: 200, height: 100)
        for start in PiPCorner.allCases {
            let startFrame = geometry.frame(for: start, size: size)
            for target in PiPCorner.allCases where target != start {
                var endFrame = geometry.frame(for: target, size: size)
                let left = endFrame.midX < geometry.bounds.midX
                endFrame.origin.x = left ? -75 : 275
                let dx = endFrame.midX - startFrame.midX
                let dy = endFrame.midY - startFrame.midY
                let velocity = CGPoint(x: abs(dx) > 100 ? (dx > 0 ? 1000 : -1000) : 0,
                                       y: abs(dy) > 100 ? (dy > 0 ? 1600 : -1600) : 0)
                XCTAssertEqual(geometry.placement(afterDragging: endFrame,
                                                  translation: CGPoint(x: dx, y: dy), velocity: velocity,
                                                  startingCorner: start), .corner(target),
                               "Flick from \(start) to \(target) must not tuck")
            }
        }
    }

    func testVerticalCornerFlickAlongSameEdgeDoesNotTuck() {
        XCTAssertEqual(geometry.placement(afterDragging: CGRect(x: -75, y: 450, width: 200, height: 100),
                                          translation: CGPoint(x: -91, y: 380),
                                          velocity: CGPoint(x: -400, y: 1700), startingCorner: .topLeft),
                       .corner(.bottomLeft))
    }

    func testSmallAccidentalOvershootSnapsBack() {
        XCTAssertEqual(geometry.placement(afterDragging: CGRect(x: -30, y: 70, width: 200, height: 100),
                                          translation: CGPoint(x: -46, y: 0), velocity: .zero,
                                          startingCorner: .topLeft), .corner(.topLeft))
    }

    func testSlowDragAcrossScreenCanIntentionallyTuckOppositeEdge() {
        XCTAssertEqual(geometry.placement(afterDragging: CGRect(x: 275, y: 70, width: 200, height: 100),
                                          translation: CGPoint(x: 259, y: 0), velocity: CGPoint(x: 100, y: 0),
                                          startingCorner: .topLeft), .tucked(edge: .right, centerY: 120))
    }

    func testPullTabNeedsAnInwardPullOrFlickToRestore() {
        let frame = CGRect(x: -180, y: 200, width: 200, height: 100)
        XCTAssertEqual(geometry.placement(afterDragging: frame, translation: CGPoint(x: 20, y: 0),
                                          velocity: .zero, startingCorner: .topLeft, startingEdge: .left),
                       .tucked(edge: .left, centerY: 250))
        XCTAssertEqual(geometry.placement(afterDragging: frame, translation: CGPoint(x: 50, y: 0),
                                          velocity: .zero, startingCorner: .topLeft, startingEdge: .left),
                       .corner(.topLeft))
        XCTAssertEqual(geometry.placement(afterDragging: frame, translation: CGPoint(x: 20, y: 0),
                                          velocity: CGPoint(x: 800, y: 0), startingCorner: .topLeft,
                                          startingEdge: .left), .corner(.topLeft))
    }

    func testRightPullTabRestoresWithLeftwardMotion() {
        XCTAssertEqual(geometry.placement(afterDragging: CGRect(x: 350, y: 200, width: 200, height: 100),
                                          translation: CGPoint(x: -62, y: 0), velocity: .zero,
                                          startingCorner: .topRight, startingEdge: .right), .corner(.topRight))
    }

    func testTuckedContentIsFullyOffscreenAndTabRespectsSafeArea() {
        for edge in [PiPEdge.left, .right] {
            let frame = geometry.tuckedFrame(edge: edge, centerY: -100, size: CGSize(width: 200, height: 100))
            let tab = geometry.tabFrame(edge: edge, centerY: -100)
            XCTAssertFalse(frame.intersects(geometry.bounds))
            XCTAssertGreaterThanOrEqual(tab.minY, geometry.visibleBounds.minY)
            XCTAssertLessThanOrEqual(tab.maxY, geometry.visibleBounds.maxY)
            XCTAssertTrue(geometry.bounds.contains(tab))
        }
    }

    func testResizingToSmallBoundsPreservesAspectRatioAndKeepsCornersInside() {
        let small = PiPGeometry(bounds: CGRect(x: 50, y: 20, width: 240, height: 180),
                                insets: UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16))
        let fitted = small.fittedSize(CGSize(width: 400, height: 200))
        XCTAssertEqual(fitted.width / fitted.height, 2, accuracy: 0.001)
        for corner in PiPCorner.allCases {
            XCTAssertTrue(small.visibleBounds.contains(small.frame(for: corner, size: fitted)))
        }
    }

    func testLandscapeTabsAvoidHorizontalCutoutSafeAreas() {
        let landscape = PiPGeometry(bounds: CGRect(x: 0, y: 0, width: 850, height: 400),
                                    insets: UIEdgeInsets(top: 16, left: 78, bottom: 37, right: 78),
                                    safeAreaInsets: UIEdgeInsets(top: 0, left: 62, bottom: 21, right: 62))
        for edge in [PiPEdge.left, .right] {
            let tab = landscape.tabFrame(edge: edge, centerY: 200)
            XCTAssertGreaterThanOrEqual(tab.minX, 62)
            XCTAssertLessThanOrEqual(tab.maxX, 850 - 62)
        }
    }
}
