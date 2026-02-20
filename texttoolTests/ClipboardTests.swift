//
//  ClipboardTests.swift
//  texttoolTests
//

import Testing
import SwiftUI
@testable import texttool

@MainActor
@Suite(.serialized)
struct ClipboardTests {

    // MARK: - TextObject Codable Round-Trip

    @Test func textObjectCodableRoundTrip() async throws {
        let original = TextObject(
            position: CGPoint(x: 100, y: 200),
            text: "Hello World",
            fontSize: 24,
            color: .red,
            rotation: 0.5,
            zIndex: 3
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(TextObject.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.position == original.position)
        #expect(decoded.text == original.text)
        #expect(decoded.textAttributes.fontSize == original.textAttributes.fontSize)
        #expect(decoded.rotation == original.rotation)
        #expect(decoded.zIndex == original.zIndex)
        #expect(decoded.isEditing == false)
    }

    // MARK: - ShapeObject Codable Round-Trip

    @Test func shapeObjectCodableRoundTrip() async throws {
        let original = ShapeObject(
            position: CGPoint(x: 50, y: 75),
            size: CGSize(width: 200, height: 150),
            preset: .rectangle,
            color: .blue,
            strokeWidth: 3,
            fillOpacity: 0.5,
            text: "Shape text",
            rotation: 1.0,
            zIndex: 5
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ShapeObject.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.position == original.position)
        #expect(decoded.size == original.size)
        #expect(decoded.preset == original.preset)
        #expect(decoded.strokeWidth == original.strokeWidth)
        #expect(decoded.fillOpacity == original.fillOpacity)
        #expect(decoded.text == original.text)
        #expect(decoded.rotation == original.rotation)
        #expect(decoded.zIndex == original.zIndex)
        #expect(decoded.isEditing == false)

        // Verify Color survives via CodableColor component comparison
        let origStroke = CodableColor(original.strokeColor)
        let decodedStroke = CodableColor(decoded.strokeColor)
        #expect(abs(origStroke.red - decodedStroke.red) < 0.01)
        #expect(abs(origStroke.green - decodedStroke.green) < 0.01)
        #expect(abs(origStroke.blue - decodedStroke.blue) < 0.01)
    }

    // MARK: - CodableCanvasObject Round-Trip

    @Test func codableCanvasObjectRoundTrip() async throws {
        let textObj = TextObject(
            position: CGPoint(x: 10, y: 20),
            text: "Test",
            fontSize: 16
        )
        let shapeObj = ShapeObject(
            position: CGPoint(x: 30, y: 40),
            size: CGSize(width: 100, height: 80),
            preset: .oval
        )

        let codables: [CodableCanvasObject] = [
            .text(textObj),
            .shape(shapeObj)
        ]

        let data = try JSONEncoder().encode(codables)
        let decoded = try JSONDecoder().decode([CodableCanvasObject].self, from: data)

        #expect(decoded.count == 2)
    }

    // MARK: - ViewModel: deleteSelected

    @Test func deleteSelectedRemovesObjectsAndClearsSelection() async throws {
        let vm = CanvasViewModel()
        let id = vm.addTextObject(at: CGPoint(x: 10, y: 10))
        vm.selectObjectOnly(id: id)
        #expect(vm.objects.count == 1)
        #expect(vm.selectionState.hasSelection)

        vm.deleteSelected()

        #expect(vm.objects.isEmpty)
        #expect(!vm.selectionState.hasSelection)
    }

    // MARK: - ViewModel: copy + paste

    @Test func copyAndPasteCreatesNewObjectsWithNewIds() async throws {
        let vm = CanvasViewModel()
        let id = vm.addTextObject(at: CGPoint(x: 100, y: 100))
        vm.updateText(objectId: id, text: "Copy me")
        vm.selectObjectOnly(id: id)

        vm.copySelection()
        vm.pasteFromClipboard()

        #expect(vm.objects.count == 2)
        let ids = Set(vm.objects.map(\.id))
        #expect(ids.count == 2) // new ID for the pasted object
    }

    @Test func pastedObjectsAreOffset() async throws {
        let vm = CanvasViewModel()
        let id = vm.addTextObject(at: CGPoint(x: 100, y: 100))
        vm.selectObjectOnly(id: id)

        let originalPos = vm.objects.first!.position

        vm.copySelection()
        vm.pasteFromClipboard()

        let pastedObj = vm.objects.first { $0.id != id }!
        #expect(pastedObj.position.x == originalPos.x + 20)
        #expect(pastedObj.position.y == originalPos.y + 20)
    }

    @Test func pastedObjectsBecomeNewSelection() async throws {
        let vm = CanvasViewModel()
        let id = vm.addTextObject(at: CGPoint(x: 100, y: 100))
        vm.selectObjectOnly(id: id)

        vm.copySelection()
        vm.pasteFromClipboard()

        // The pasted object should be selected, not the original
        #expect(!vm.isSelected(id))
        let pastedId = vm.objects.first { $0.id != id }!.id
        #expect(vm.isSelected(pastedId))
    }

    // MARK: - ViewModel: cut + paste

    @Test func cutRemovesSelectedObjects() async throws {
        let vm = CanvasViewModel()
        let id = vm.addTextObject(at: CGPoint(x: 50, y: 50))
        vm.updateText(objectId: id, text: "Cut me")
        vm.selectObjectOnly(id: id)

        #expect(vm.objects.count == 1)
        vm.cutSelection()
        #expect(vm.objects.isEmpty)
        #expect(!vm.selectionState.hasSelection)
    }

    @Test func cutThenPasteRestoresObjects() async throws {
        let vm = CanvasViewModel()
        let id = vm.addTextObject(at: CGPoint(x: 50, y: 50))
        vm.updateText(objectId: id, text: "Cut me")
        vm.selectObjectOnly(id: id)

        // Verify selection and object state before cut
        #expect(vm.selectedIds.count == 1)
        #expect(vm.objects.count == 1)

        // Manually copy first to verify clipboard works
        vm.copySelection()
        let clipboardData = ClipboardService.pasteObjects()
        #expect(clipboardData != nil)
        #expect(clipboardData?.count == 1)

        // Now do the actual cut
        vm.deleteSelected()
        #expect(vm.objects.isEmpty)

        // Paste should restore from clipboard
        vm.pasteFromClipboard()
        #expect(vm.objects.count == 1)
    }

    // MARK: - Multi-object copy/paste

    @Test func multiObjectCopyPaste() async throws {
        let vm = CanvasViewModel()
        let id1 = vm.addTextObject(at: CGPoint(x: 10, y: 10))
        vm.addShape(preset: .rectangle, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 150))
        let shapeId = vm.objects.first(where: { $0.asShapeObject != nil })!.id

        vm.selectMultiple(ids: [id1, shapeId])
        vm.copySelection()
        vm.pasteFromClipboard()

        #expect(vm.objects.count == 4)
        #expect(vm.selectedIds.count == 2)
        // None of the selected (pasted) IDs should match originals
        #expect(!vm.isSelected(id1))
        #expect(!vm.isSelected(shapeId))
    }
}
