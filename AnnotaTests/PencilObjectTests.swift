//
//  PencilObjectTests.swift
//  AnnotaTests
//
//  Unit tests for PencilObject model behaviour.
//

import Testing
import SwiftUI
import CoreGraphics
@testable import AnotarCanvas

@MainActor
struct PencilObjectTests {

    // MARK: - Helpers

    private func makeStroke(
        points: [CGPoint] = [CGPoint(x: 0, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 100, y: 0)],
        strokeColor: Color = .black,
        strokeWidth: CGFloat = 2,
        strokeStyle: StrokeStyleType = .solid,
        rotation: CGFloat = 0
    ) -> PencilObject {
        PencilObject(
            points: points,
            strokeColor: strokeColor,
            strokeWidth: strokeWidth,
            strokeStyle: strokeStyle,
            rotation: rotation
        )
    }

    // MARK: - Basic Properties

    @Test func defaultStrokeProperties() async throws {
        let stroke = makeStroke()
        #expect(stroke.strokeColor == .black)
        #expect(stroke.strokeWidth == 2)
        #expect(stroke.strokeStyle == .solid)
        #expect(stroke.usesControlPoints == false)
        #expect(stroke.isLocked == false)
        #expect(stroke.rotation == 0)
    }

    @Test func hasStrokeProperty() async throws {
        var stroke = makeStroke(strokeWidth: 3)
        #expect(stroke.hasStroke == true)
        stroke.strokeWidth = 0
        #expect(stroke.hasStroke == false)
    }

    // MARK: - Bounding Box / Position / Size

    @Test func positionReturnsBoundingBoxOrigin() async throws {
        let stroke = makeStroke(points: [
            CGPoint(x: 10, y: 20),
            CGPoint(x: 60, y: 80)
        ])
        #expect(stroke.position.x == 10)
        #expect(stroke.position.y == 20)
    }

    @Test func sizeReturnsBoundingBoxDimensions() async throws {
        let stroke = makeStroke(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 50)
        ])
        #expect(stroke.size.width == 100)
        #expect(stroke.size.height == 50)
    }

    @Test func boundingBoxIncludesStrokeWidth() async throws {
        let stroke = makeStroke(
            points: [CGPoint(x: 10, y: 10), CGPoint(x: 90, y: 10)],
            strokeWidth: 4
        )
        let bbox = stroke.boundingBox()
        // Bounding box should be padded by strokeWidth/2 = 2 on each side
        #expect(bbox.minX <= 10)
        #expect(bbox.minY <= 10)
    }

    @Test func positionSetterMovesAllPoints() async throws {
        var stroke = makeStroke(points: [
            CGPoint(x: 10, y: 10),
            CGPoint(x: 50, y: 10)
        ])
        stroke.position = CGPoint(x: 20, y: 20)

        // Both points should shift by (10, 10)
        #expect(stroke.points[0].x == 20)
        #expect(stroke.points[0].y == 20)
        #expect(stroke.points[1].x == 60)
        #expect(stroke.points[1].y == 20)
    }

    @Test func sizeSetterScalesPoints() async throws {
        // Use points with both non-zero width and height so the guard passes
        var stroke = makeStroke(points: [
            CGPoint(x: 0, y: 0),
            CGPoint(x: 100, y: 100)
        ])
        stroke.size = CGSize(width: 200, height: 200)
        #expect(abs(stroke.size.width - 200) < 1)
        #expect(abs(stroke.size.height - 200) < 1)
    }

    // MARK: - Contains

    @Test func containsReturnsTrueForPointOnStroke() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        #expect(stroke.contains(CGPoint(x: 50, y: 0)))
    }

    @Test func containsReturnsTrueForPointNearStroke() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        // Within default hit threshold of ~8pts
        #expect(stroke.contains(CGPoint(x: 50, y: 3)))
    }

    @Test func containsReturnsFalseForPointFarFromStroke() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        #expect(!stroke.contains(CGPoint(x: 50, y: 20)))
    }

    // MARK: - Hit Testing

    @Test func hitTestBodyOnStroke() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        let result = stroke.hitTest(CGPoint(x: 50, y: 0), threshold: 8)
        if case .body = result {
            // Correct
        } else {
            #expect(Bool(false), "Expected .body, got \(String(describing: result))")
        }
    }

    @Test func hitTestNilForFarPoint() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        let result = stroke.hitTest(CGPoint(x: 50, y: 30), threshold: 8)
        #expect(result == nil)
    }

    // MARK: - Marquee Intersection

    @Test func intersectsRectWhenStrokeCrosses() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 100)])
        let rect = CGRect(x: 40, y: 40, width: 30, height: 30)
        #expect(stroke.intersectsRect(rect))
    }

    @Test func doesNotIntersectRectWhenFarAway() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        let rect = CGRect(x: 200, y: 200, width: 50, height: 50)
        #expect(!stroke.intersectsRect(rect))
    }

    @Test func intersectsRectWhenEndpointInside() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)])
        let rect = CGRect(x: 40, y: 40, width: 20, height: 20)
        #expect(stroke.intersectsRect(rect))
    }

    // MARK: - Codable Round-Trip

    @Test func encodeDecodeRoundTrip() async throws {
        let original = PencilObject(
            points: [
                CGPoint(x: 10, y: 20),
                CGPoint(x: 50, y: 80),
                CGPoint(x: 90, y: 30)
            ],
            strokeColor: .blue,
            strokeWidth: 4,
            strokeStyle: .dashed(pattern: [8, 4]),
            rotation: 0.3
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(PencilObject.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.points.count == original.points.count)
        #expect(decoded.points[0] == original.points[0])
        #expect(decoded.points[1] == original.points[1])
        #expect(decoded.points[2] == original.points[2])
        #expect(decoded.strokeWidth == original.strokeWidth)
        #expect(decoded.strokeStyle == original.strokeStyle)
        #expect(decoded.rotation == original.rotation)
        #expect(decoded.isLocked == original.isLocked)
    }

    @Test func encodeDecodePreservesAllStrokeStyles() async throws {
        let styles: [StrokeStyleType] = [.solid, .dotted, .dashed(pattern: [6, 3])]
        for style in styles {
            let obj = PencilObject(points: [.zero, CGPoint(x: 10, y: 0)], strokeStyle: style)
            let data = try JSONEncoder().encode(obj)
            let decoded = try JSONDecoder().decode(PencilObject.self, from: data)
            #expect(decoded.strokeStyle == style, "Failed for style: \(style)")
        }
    }

    // MARK: - Copy

    @Test func copiedCreatesNewObjectWithOffset() async throws {
        let original = PencilObject(
            points: [CGPoint(x: 10, y: 10), CGPoint(x: 50, y: 50)],
            strokeColor: .red,
            strokeWidth: 3
        )

        let newId = UUID()
        let offset = CGPoint(x: 20, y: 20)
        let copy = original.copied(newId: newId, zIndex: 5, offset: offset)

        #expect(copy.id == newId)
        #expect(copy.id != original.id)
        #expect(copy.zIndex == 5)
        #expect(copy.isLocked == false)
        #expect(copy.points[0].x == original.points[0].x + offset.x)
        #expect(copy.points[0].y == original.points[0].y + offset.y)
        #expect(copy.points[1].x == original.points[1].x + offset.x)
        #expect(copy.points[1].y == original.points[1].y + offset.y)
        #expect(copy.strokeWidth == original.strokeWidth)
    }

    // MARK: - Smooth Path

    @Test func smoothPathWithTwoPoints() async throws {
        let stroke = makeStroke(points: [CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 0)])
        let path = stroke.smoothPath()
        // Should produce a non-empty path without crashing
        #expect(!path.isEmpty)
    }

    @Test func smoothPathWithManyPoints() async throws {
        let pts = stride(from: 0, to: 200, by: 10).map { CGPoint(x: CGFloat($0), y: 0) }
        let stroke = PencilObject(points: pts)
        let path = stroke.smoothPath()
        #expect(!path.isEmpty)
    }

    @Test func smoothPathWithSinglePoint() async throws {
        let stroke = PencilObject(points: [CGPoint(x: 50, y: 50)])
        // Should not crash; returns a degenerate path
        let _ = stroke.smoothPath()
    }

    @Test func smoothPathWithNoPoints() async throws {
        let stroke = PencilObject(points: [])
        let path = stroke.smoothPath()
        // Empty path — just confirm no crash
        #expect(path.isEmpty)
    }

    // MARK: - Single-Point Edge Cases

    @Test func containsWithSinglePoint() async throws {
        let stroke = PencilObject(points: [CGPoint(x: 50, y: 50)])
        #expect(stroke.contains(CGPoint(x: 50, y: 50)))
    }

    @Test func emptyPointsPosition() async throws {
        let stroke = PencilObject(points: [])
        // Should not crash; returns .zero origin
        #expect(stroke.position == .zero)
    }

    // MARK: - AnyCanvasObject Integration

    @Test func asPencilObjectViaAnyCanvasObject() async throws {
        let pencil = PencilObject(points: [.zero, CGPoint(x: 10, y: 0)])
        let wrapped = AnyCanvasObject(pencil)
        #expect(wrapped.asPencilObject != nil)
        #expect(wrapped.asLineObject == nil)
    }
}
