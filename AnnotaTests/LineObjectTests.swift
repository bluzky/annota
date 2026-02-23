//
//  LineObjectTests.swift
//  AnnotaTests
//
//  Unit tests for LineObject and Arrow functionality

import Testing
import SwiftUI
import CoreGraphics
@testable import AnotarCanvas

@MainActor
struct LineObjectTests {

    // MARK: - Helpers

    private func makeLine(
        startX: CGFloat = 0, startY: CGFloat = 0,
        endX: CGFloat = 100, endY: CGFloat = 100,
        strokeColor: Color = .black,
        strokeWidth: CGFloat = 2,
        strokeStyle: StrokeStyleType = .solid,
        startArrowHead: ArrowHead = .none,
        endArrowHead: ArrowHead = .none,
        label: String = "",
        rotation: CGFloat = 0
    ) -> LineObject {
        LineObject(
            startPoint: CGPoint(x: startX, y: startY),
            endPoint: CGPoint(x: endX, y: endY),
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle,
            startArrowHead: startArrowHead,
            endArrowHead: endArrowHead,
            label: label,
            rotation: rotation
        )
    }

    // MARK: - Computed Properties

    @Test func positionReturnsBoundingBoxOrigin() async throws {
        let line = makeLine(startX: 50, startY: 50, endX: 150, endY: 150)
        #expect(line.position.x == 50)
        #expect(line.position.y == 50)
    }

    @Test func positionHandlesNegativeCoordinates() async throws {
        let line = makeLine(startX: -50, startY: -30, endX: 50, endY: 70)
        #expect(line.position.x == -50)
        #expect(line.position.y == -30)
    }

    @Test func sizeReturnsBoundingBoxDimensions() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 50)
        #expect(line.size.width == 100)
        #expect(line.size.height == 50)
    }

    @Test func sizeHandlesDiagonalLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        #expect(line.size.width == 100)
        #expect(line.size.height == 100)
    }

    @Test func midPointCalculatesCorrectly() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let mid = line.midPoint
        #expect(mid.x == 50)
        #expect(mid.y == 50)
    }

    @Test func midPointHandlesAsymmetricLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 50)
        let mid = line.midPoint
        #expect(mid.x == 50)
        #expect(mid.y == 25)
    }

    @Test func lengthCalculatesCorrectly() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        #expect(line.length == 100)
    }

    @Test func lengthForDiagonalLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        // Length should be sqrt(100² + 100²) = sqrt(20000) ≈ 141.42
        let expectedLength = sqrt(100 * 100 + 100 * 100)
        #expect(abs(line.length - expectedLength) < 0.01)
    }

    @Test func angleForHorizontalLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        let angle = line.angle
        #expect(abs(angle) < 0.0001) // Should be essentially 0
    }

    @Test func angleForVerticalLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 0, endY: 100)
        let angle = line.angle
        // Should be π/2 (90 degrees)
        #expect(abs(angle - .pi / 2) < 0.0001)
    }

    @Test func angleForDiagonalLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let angle = line.angle
        // Should be π/4 (45 degrees)
        #expect(abs(angle - .pi / 4) < 0.0001)
    }

    @Test func isArrowFalseForPlainLine() async throws {
        let line = makeLine()
        #expect(line.isArrow == false)
    }

    @Test func isArrowTrueWithEndArrowHead() async throws {
        let line = makeLine(endArrowHead: .filled)
        #expect(line.isArrow == true)
    }

    @Test func isArrowTrueWithStartArrowHead() async throws {
        let line = makeLine(startArrowHead: .open)
        #expect(line.isArrow == true)
    }

    @Test func isArrowTrueWithBothArrowheads() async throws {
        let line = makeLine(startArrowHead: .open, endArrowHead: .filled)
        #expect(line.isArrow == true)
    }

    @Test func usesControlPointsReturnsTrue() async throws {
        let line = makeLine()
        #expect(line.usesControlPoints == true)
    }

    // MARK: - Bounding Box

    @Test func boundingBoxReturnsCorrectRect() async throws {
        let line = makeLine(startX: 10, startY: 10, endX: 110, endY: 110)
        let bbox = line.boundingBox()
        #expect(bbox.origin.x == 10)
        #expect(bbox.origin.y == 10)
        #expect(bbox.size.width == 100)
        #expect(bbox.size.height == 100)
    }

    @Test func boundingBoxForNegativeCoordinates() async throws {
        let line = makeLine(startX: -50, startY: -50, endX: 50, endY: 50)
        let bbox = line.boundingBox()
        #expect(bbox.origin.x == -50)
        #expect(bbox.origin.y == -50)
        #expect(bbox.size.width == 100)
        #expect(bbox.size.height == 100)
    }

    // MARK: - Hit Testing - Control Points

    @Test func hitTestDetectsStartControlPoint() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let threshold: CGFloat = 8

        let result = line.hitTest(CGPoint(x: 0, y: 0), threshold: threshold)
        if case .controlPoint(let index) = result {
            #expect(index == 0)
        } else {
            #expect(Bool(false), "Expected .controlPoint(0), got \(String(describing: result))")
        }
    }

    @Test func hitTestDetectsEndControlPoint() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let threshold: CGFloat = 8

        let result = line.hitTest(CGPoint(x: 100, y: 100), threshold: threshold)
        if case .controlPoint(let index) = result {
            #expect(index == 1)
        } else {
            #expect(Bool(false), "Expected .controlPoint(1), got \(String(describing: result))")
        }
    }

    @Test func hitControlPointWithinThreshold() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let threshold: CGFloat = 8

        // Point within threshold of startPoint
        let result = line.hitTest(CGPoint(x: 5, y: 5), threshold: threshold)
        if case .controlPoint(let index) = result {
            #expect(index == 0)
        } else {
            #expect(Bool(false), "Expected .controlPoint(0), got \(String(describing: result))")
        }
    }

    @Test func hitControlPointOutsideThreshold() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let threshold: CGFloat = 8

        // Point outside threshold of startPoint
        let result = line.hitTest(CGPoint(x: 20, y: 20), threshold: threshold)
        if case .controlPoint = result {
            #expect(Bool(false), "Should not detect control point at distance > threshold")
        }
    }

    // MARK: - Hit Testing - Line Segment

    @Test func hitTestDetectsLineBodyAtMidpoint() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        let threshold: CGFloat = 8

        // Point on the line at midpoint
        let result = line.hitTest(CGPoint(x: 50, y: 0), threshold: threshold)
        if case .body = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .body, got \(String(describing: result))")
        }
    }

    @Test func hitTestDetectsLineBodyNearLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        let threshold: CGFloat = 8

        // Point near the line (within threshold)
        let result = line.hitTest(CGPoint(x: 50, y: 5), threshold: threshold)
        if case .body = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .body for point near line, got \(String(describing: result))")
        }
    }

    @Test func hitTestDoesNotDetectFarFromLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        let threshold: CGFloat = 8

        // Point far from the line
        let result = line.hitTest(CGPoint(x: 50, y: 20), threshold: threshold)
        #expect(result == nil)
    }

    @Test func hitTestVerticalLine() async throws {
        let line = makeLine(startX: 50, startY: 0, endX: 50, endY: 100)
        let threshold: CGFloat = 8

        // Point near the vertical line
        let result = line.hitTest(CGPoint(x: 55, y: 50), threshold: threshold)
        if case .body = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .body for vertical line, got \(String(describing: result))")
        }
    }

    @Test func hitTestDiagonalLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let threshold: CGFloat = 8

        // Point at midpoint of diagonal line
        let result = line.hitTest(CGPoint(x: 50, y: 50), threshold: threshold)
        if case .body = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .body for diagonal line, got \(String(describing: result))")
        }
    }

    // MARK: - Hit Testing - Label

    @Test func hitTestDetectsLabelArea() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0, label: "Test")

        // Point at midpoint where label would be rendered
        let result = line.hitTest(CGPoint(x: 50, y: 0), threshold: 8)
        if case .label = result {
            // Correct - label has priority
        } else {
            #expect(Bool(false), "Expected .label, got \(String(describing: result))")
        }
    }

    @Test func hitTestIgnoresLabelWhenEmpty() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0, label: "")
        let threshold: CGFloat = 8

        // Point at midpoint should hit body, not label
        let result = line.hitTest(CGPoint(x: 50, y: 0), threshold: threshold)
        if case .label = result {
            #expect(Bool(false), "Should not return .label for empty label")
        } else if case .body = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .body, got \(String(describing: result))")
        }
    }

    // MARK: - Hit Testing - Priority

    @Test func controlPointsHavePriorityOverBody() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        let threshold: CGFloat = 8

        // Point at startPoint should detect control point, not body
        let result = line.hitTest(CGPoint(x: 0, y: 0), threshold: threshold)
        if case .controlPoint = result {
            // Correct - control point has priority
        } else {
            #expect(Bool(false), "Expected .controlPoint, got \(String(describing: result))")
        }
    }

    @Test func labelHasPriorityOverBody() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0, label: "A")

        // Point at midpoint should return label, not body
        let result = line.hitTest(CGPoint(x: 50, y: 0), threshold: 8)
        if case .label = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .label to have priority, got \(String(describing: result))")
        }
    }

    // MARK: - Contains

    @Test func containsReturnsTrueForPointOnLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        #expect(line.contains(CGPoint(x: 50, y: 0)))
    }

    @Test func containsReturnsTrueForPointNearLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        // Point within stroke/4 proximity
        #expect(line.contains(CGPoint(x: 50, y: 1)))
    }

    @Test func containsReturnsFalseForPointFarFromLine() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0)
        #expect(!line.contains(CGPoint(x: 50, y: 20)))
    }

    @Test func containsRespectsLabelArea() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0, label: "Test")
        // Point at midpoint where label would be
        #expect(line.contains(CGPoint(x: 50, y: 0)))
    }

    @Test func containsWithWiderStroke() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 0, strokeWidth: 10)
        // With wider stroke, should hit point further away
        #expect(line.contains(CGPoint(x: 50, y: 7)))
    }

    // MARK: - Intersects Rect (Marquee Selection)

    @Test func intersectsRectWhenLineCrosses() async throws {
        let line = makeLine(startX: 50, startY: 50, endX: 150, endY: 150)
        let rect = CGRect(x: 75, y: 75, width: 50, height: 50)
        #expect(line.intersectsRect(rect))
    }

    @Test func intersectsRectWhenInside() async throws {
        let line = makeLine(startX: 20, startY: 20, endX: 40, endY: 40)
        let rect = CGRect(x: 10, y: 10, width: 50, height: 50)
        #expect(line.intersectsRect(rect))
    }

    @Test func intersectsRectWhenContainsEndpoint() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let rect = CGRect(x: 90, y: 90, width: 20, height: 20)
        #expect(line.intersectsRect(rect))
    }

    @Test func doesNotIntersectRectWhenFarAway() async throws {
        let line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        let rect = CGRect(x: 200, y: 200, width: 50, height: 50)
        #expect(!line.intersectsRect(rect))
    }

    @Test func intersectsRectDetectsPartialOverlap() async throws {
        // Diagonal line crossing a rect
        let line = makeLine(startX: 0, startY: 100, endX: 100, endY: 0)
        let rect = CGRect(x: 25, y: 25, width: 50, height: 50)
        #expect(line.intersectsRect(rect))
    }

    // MARK: - Size Setter

    @Test func sizeSetterScalesLine() async throws {
        var line = makeLine(startX: 0, startY: 0, endX: 100, endY: 100)
        line.size = CGSize(width: 200, height: 200)

        // Line should now extend from (0,0) to (200,200)
        #expect(line.startPoint.x == 0)
        #expect(line.startPoint.y == 0)
        #expect(line.endPoint.x == 200)
        #expect(line.endPoint.y == 200)
    }

    @Test func sizeSetterHandlesHorizontalLine() async throws {
        var line = makeLine(startX: 0, startY: 50, endX: 100, endY: 50)
        line.size = CGSize(width: 150, height: 0)

        #expect(line.startPoint.x == 0)
        #expect(line.startPoint.y == 50)
        #expect(line.endPoint.x == 150)
        #expect(line.endPoint.y == 50)
    }

    @Test func sizeSetterHandlesVerticalLine() async throws {
        var line = makeLine(startX: 50, startY: 0, endX: 50, endY: 100)
        line.size = CGSize(width: 0, height: 150)

        #expect(line.startPoint.x == 50)
        #expect(line.startPoint.y == 0)
        #expect(line.endPoint.x == 50)
        #expect(line.endPoint.y == 150)
    }

    // MARK: - Position Setter

    @Test func positionSetterMovesLine() async throws {
        var line = makeLine(startX: 10, startY: 10, endX: 110, endY: 110)
        line.position = CGPoint(x: 20, y: 20)

        // Both points should move by same offset (10,10)
        #expect(line.startPoint.x == 20)
        #expect(line.startPoint.y == 20)
        #expect(line.endPoint.x == 120)
        #expect(line.endPoint.y == 120)
    }

    // MARK: - Codable

    @Test func lineObjectEncodeDecodeRoundTrip() async throws {
        let original = LineObject(
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 100, y: 150),
            strokeColor: .blue,
            strokeWidth: 3,
            strokeStyle: .dashed(pattern: [8, 4]),
            startArrowHead: .open,
            endArrowHead: .filled,
            label: "Test Label",
            rotation: 0.5
        )

        let encoder = JSONEncoder()
        let data = try encoder.encode(original)
        let decoder = JSONDecoder()
        let decoded = try decoder.decode(LineObject.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.startPoint == original.startPoint)
        #expect(decoded.endPoint == original.endPoint)
        #expect(decoded.rotation == original.rotation)
        #expect(decoded.strokeWidth == original.strokeWidth)
        #expect(decoded.startArrowHead == original.startArrowHead)
        #expect(decoded.endArrowHead == original.endArrowHead)
        #expect(decoded.label == original.label)
    }

    @Test func encodeDecodePreservesStrokeStyle() async throws {
        let testCases: [(StrokeStyleType, String)] = [
            (.solid, "solid"),
            (.dotted, "dotted"),
            (.dashed(pattern: [8, 4]), "dashed")
        ]

        for (style, desc) in testCases {
            let original = LineObject(
                startPoint: .zero,
                endPoint: CGPoint(x: 100, y: 100),
                strokeStyle: style
            )

            let encoder = JSONEncoder()
            let data = try encoder.encode(original)
            let decoder = JSONDecoder()
            let decoded = try decoder.decode(LineObject.self, from: data)

            #expect(decoded.strokeStyle == style, "Failed for \(desc)")
        }
    }

    // MARK: - Copy

    @Test func copiedCreatesNewObjectWithOffset() async throws {
        let original = LineObject(
            startPoint: CGPoint(x: 10, y: 10),
            endPoint: CGPoint(x: 100, y: 100),
            strokeColor: .red
        )

        let newId = UUID()
        let zIndex = 5
        let offset = CGPoint(x: 20, y: 20)
        let copy = original.copied(newId: newId, zIndex: zIndex, offset: offset)

        #expect(copy.id == newId)
        #expect(copy.id != original.id)
        #expect(copy.zIndex == zIndex)
        #expect(copy.isLocked == false) // Copy should not be locked
        #expect(copy.startPoint.x == original.startPoint.x + offset.x)
        #expect(copy.startPoint.y == original.startPoint.y + offset.y)
        #expect(copy.endPoint.x == original.endPoint.x + offset.x)
        #expect(copy.endPoint.y == original.endPoint.y + offset.y)
        #expect(copy.strokeColor == original.strokeColor)
    }

    // MARK: - CustomizableObject Protocol

    @Test func applyCustomAttributesSetsArrowHeads() async throws {
        var line = makeLine()

        line.applyCustomAttributes([
            "startArrowHead": "open",
            "endArrowHead": "filled"
        ])

        #expect(line.startArrowHead == .open)
        #expect(line.endArrowHead == .filled)
    }

    @Test func applyCustomAttributesIgnoresUnknownValues() async throws {
        var line = makeLine()
        let originalStartArrow = line.startArrowHead
        let originalEndArrow = line.endArrowHead

        line.applyCustomAttributes([
            "startArrowHead": "invalid_value",
            "unknownAttribute": "some_value"
        ])

        // Should not change with invalid values
        #expect(line.startArrowHead == originalStartArrow)
        #expect(line.endArrowHead == originalEndArrow)
    }

    @Test func getCustomAttributesReturnsArrowHeads() async throws {
        let line = makeLine(startArrowHead: .open, endArrowHead: .diamond)
        let attrs = line.getCustomAttributes()

        #expect(attrs["startArrowHead"] as? String == "open")
        #expect(attrs["endArrowHead"] as? String == "diamond")
    }

    // MARK: - StrokableObject Protocol

    @Test func lineHasDefaultStrokeProperties() async throws {
        let line = makeLine()

        #expect(line.strokeColor == .black)
        #expect(line.strokeWidth == 2)
        #expect(line.strokeStyle == .solid)
    }

    @Test func lineAcceptsCustomStrokeProperties() async throws {
        let line = makeLine(
            strokeColor: .red,
            strokeWidth: 5,
            strokeStyle: .dotted
        )

        #expect(line.strokeColor == .red)
        #expect(line.strokeWidth == 5)
        #expect(line.strokeStyle == .dotted)
    }

    @Test func hasStrokePropertyWorks() async throws {
        var line = makeLine(strokeWidth: 2)
        #expect(line.hasStroke == true)

        line.strokeWidth = 0
        #expect(line.hasStroke == false)
    }

    // MARK: - Edge Cases

    @Test func zeroLengthLine() async throws {
        let line = makeLine(startX: 50, startY: 50, endX: 50, endY: 50)

        // Should handle zero-length without errors
        #expect(line.length == 0)
        #expect(line.size.width == 0)
        #expect(line.size.height == 0)
    }

    @Test func veryShortLineWidth() async throws {
        let line = makeLine(startX: 50, startY: 50, endX: 50, endY: 51)

        #expect(line.length == 1)
        #expect(line.size.width == 0)
        #expect(line.size.height == 1)
    }

    @Test func veryShortLineHeight() async throws {
        let line = makeLine(startX: 50, startY: 50, endX: 51, endY: 50)

        #expect(line.length == 1)
        #expect(line.size.width == 1)
        #expect(line.size.height == 0)
    }

    // MARK: - All ArrowHead Styles

    @Test func allArrowHeadStylesSupported() async throws {
        let styles: [ArrowHead] = [.none, .open, .filled, .circle, .diamond]

        for style in styles {
            let line = makeLine(endArrowHead: style)
            #expect(line.endArrowHead == style, "Failed for \(style)")
        }
    }

    // MARK: - ArrowHead Enum

    @Test func arrowHeadRawValues() async throws {
        #expect(ArrowHead.none.rawValue == "none")
        #expect(ArrowHead.open.rawValue == "open")
        #expect(ArrowHead.filled.rawValue == "filled")
        #expect(ArrowHead.circle.rawValue == "circle")
        #expect(ArrowHead.diamond.rawValue == "diamond")
    }

    @Test func arrowHeadContainsAllCases() async throws {
        let allCases = ArrowHead.allCases
        #expect(allCases.count == 5)
        #expect(allCases.contains(.none))
        #expect(allCases.contains(.open))
        #expect(allCases.contains(.filled))
        #expect(allCases.contains(.circle))
        #expect(allCases.contains(.diamond))
    }
}
