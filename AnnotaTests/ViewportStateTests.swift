//
//  ViewportStateTests.swift
//  AnnotaTests
//
//  Created by Claude on 2026-02-18.
//

import Testing
import CoreGraphics
@testable import AnotarCanvas

struct ViewportStateTests {

    @Test func defaultState() async throws {
        let viewport = ViewportState()
        #expect(viewport.offset == .zero)
        #expect(viewport.scale == 1.0)
        #expect(viewport.zoomPercentage == 100)
    }

    @Test func screenToCanvasAtDefaultState() async throws {
        let viewport = ViewportState()
        let screenPoint = CGPoint(x: 100, y: 200)
        let canvasPoint = viewport.screenToCanvas(screenPoint)

        #expect(canvasPoint.x == 100)
        #expect(canvasPoint.y == 200)
    }

    @Test func screenToCanvasWithOffset() async throws {
        var viewport = ViewportState()
        viewport.offset = CGPoint(x: 50, y: 100)

        let screenPoint = CGPoint(x: 150, y: 200)
        let canvasPoint = viewport.screenToCanvas(screenPoint)

        // canvas = (screen - offset) / scale
        // x: (150 - 50) / 1 = 100
        // y: (200 - 100) / 1 = 100
        #expect(canvasPoint.x == 100)
        #expect(canvasPoint.y == 100)
    }

    @Test func screenToCanvasWithScale() async throws {
        var viewport = ViewportState()
        viewport.scale = 2.0

        let screenPoint = CGPoint(x: 200, y: 400)
        let canvasPoint = viewport.screenToCanvas(screenPoint)

        // canvas = (screen - offset) / scale
        // x: (200 - 0) / 2 = 100
        // y: (400 - 0) / 2 = 200
        #expect(canvasPoint.x == 100)
        #expect(canvasPoint.y == 200)
    }

    @Test func screenToCanvasWithOffsetAndScale() async throws {
        var viewport = ViewportState()
        viewport.offset = CGPoint(x: 100, y: 100)
        viewport.scale = 2.0

        let screenPoint = CGPoint(x: 300, y: 500)
        let canvasPoint = viewport.screenToCanvas(screenPoint)

        // canvas = (screen - offset) / scale
        // x: (300 - 100) / 2 = 100
        // y: (500 - 100) / 2 = 200
        #expect(canvasPoint.x == 100)
        #expect(canvasPoint.y == 200)
    }

    @Test func canvasToScreenRoundTrip() async throws {
        var viewport = ViewportState()
        viewport.offset = CGPoint(x: 50, y: 75)
        viewport.scale = 1.5

        let original = CGPoint(x: 100, y: 200)
        let screen = viewport.canvasToScreen(original)
        let back = viewport.screenToCanvas(screen)

        #expect(abs(back.x - original.x) < 0.001)
        #expect(abs(back.y - original.y) < 0.001)
    }

    @Test func panMutatesOffset() async throws {
        var viewport = ViewportState()
        viewport.pan(by: CGSize(width: 50, height: 100))

        #expect(viewport.offset.x == 50)
        #expect(viewport.offset.y == 100)

        viewport.pan(by: CGSize(width: -25, height: 50))
        #expect(viewport.offset.x == 25)
        #expect(viewport.offset.y == 150)
    }

    @Test func zoomClampsToLimits() async throws {
        var viewport = ViewportState()
        let center = CGPoint(x: 400, y: 300)

        // Zoom way out
        viewport.zoom(by: 0.01, around: center)
        #expect(viewport.scale >= ViewportState.minScale)

        // Reset and zoom way in
        viewport.reset()
        viewport.zoom(by: 100, around: center)
        #expect(viewport.scale <= ViewportState.maxScale)
    }

    @Test func reset() async throws {
        var viewport = ViewportState()
        viewport.offset = CGPoint(x: 100, y: 200)
        viewport.scale = 2.5

        viewport.reset()

        #expect(viewport.offset == .zero)
        #expect(viewport.scale == 1.0)
    }

    @Test func zoomPercentage() async throws {
        var viewport = ViewportState()

        viewport.scale = 0.5
        #expect(viewport.zoomPercentage == 50)

        viewport.scale = 1.0
        #expect(viewport.zoomPercentage == 100)

        viewport.scale = 2.0
        #expect(viewport.zoomPercentage == 200)

        viewport.scale = 1.25
        #expect(viewport.zoomPercentage == 125)
    }
}
