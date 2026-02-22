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

    init() {
        // Ensure CodableObjectRegistry types are registered before any test runs.
        // ToolRegistry.shared triggers registerBuiltInObjectTypes() in its private init.
        _ = ToolRegistry.shared
    }

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

        let textWrapped = AnyCanvasObject(textObj)
        let shapeWrapped = AnyCanvasObject(shapeObj)

        let codables: [CodableCanvasObject] = [
            CodableCanvasObject.from(textWrapped)!,
            CodableCanvasObject.from(shapeWrapped)!
        ]

        let data = try JSONEncoder().encode(codables)
        let decoded = try JSONDecoder().decode([CodableCanvasObject].self, from: data)

        #expect(decoded.count == 2)

        // Verify round-trip produces valid objects
        let restored0 = decoded[0].toAnyCanvasObject(newId: UUID(), zIndex: 0, offset: .zero)
        let restored1 = decoded[1].toAnyCanvasObject(newId: UUID(), zIndex: 0, offset: .zero)
        #expect(restored0 != nil)
        #expect(restored1 != nil)
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

        #expect(vm.selectedIds.count == 1)
        #expect(vm.objects.count == 1)

        // Single cutSelection() copies to clipboard and deletes the selection
        vm.cutSelection()
        #expect(vm.objects.isEmpty)
        #expect(!vm.selectionState.hasSelection)

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

    // MARK: - ImageObject Codable Round-Trip

    @Test func imageObjectCodableRoundTrip() async throws {
        // Create minimal 1x1 PNG data
        let pngData = makeSinglePixelPNG()

        let original = ImageObject(
            position: CGPoint(x: 50, y: 75),
            size: CGSize(width: 200, height: 150),
            imageData: pngData,
            aspectRatio: 4.0 / 3.0,
            maintainAspectRatio: true,
            rotation: 0.25,
            zIndex: 2
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(ImageObject.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.position == original.position)
        #expect(decoded.size == original.size)
        #expect(abs(decoded.aspectRatio - original.aspectRatio) < 0.001)
        #expect(decoded.maintainAspectRatio == original.maintainAspectRatio)
        #expect(decoded.rotation == original.rotation)
        #expect(decoded.zIndex == original.zIndex)
        #expect(decoded.imageData == original.imageData)
    }

    @Test func codableCanvasObjectWithImageRoundTrip() async throws {
        let pngData = makeSinglePixelPNG()
        let imageObj = ImageObject(
            position: CGPoint(x: 10, y: 20),
            size: CGSize(width: 100, height: 100),
            imageData: pngData,
            aspectRatio: 1.0
        )

        let wrapped = AnyCanvasObject(imageObj)
        let codable = CodableCanvasObject.from(wrapped)!
        let codables: [CodableCanvasObject] = [codable]
        let data = try JSONEncoder().encode(codables)
        let decoded = try JSONDecoder().decode([CodableCanvasObject].self, from: data)

        #expect(decoded.count == 1)
        let restored = decoded[0].toAnyCanvasObject(newId: UUID(), zIndex: 0, offset: .zero)
        #expect(restored != nil)
        let decodedImage = restored?.asType(ImageObject.self)
        #expect(decodedImage != nil)
        #expect(decodedImage?.imageData == imageObj.imageData)
    }

    @Test func imageObjectFittingSizePreservesAspectRatio() {
        // Landscape: 800x400 should fit within 300px max
        let landscapeSize = CGSize(width: 800, height: 400)
        let fitted = ImageObject.fittingSize(for: landscapeSize, maxDimension: 300)
        #expect(abs(fitted.width / fitted.height - 2.0) < 0.001) // aspect ratio preserved
        #expect(fitted.width <= 300)
        #expect(fitted.height <= 300)

        // Portrait: 400x800 should fit within 300px max
        let portraitSize = CGSize(width: 400, height: 800)
        let fittedPortrait = ImageObject.fittingSize(for: portraitSize, maxDimension: 300)
        #expect(abs(fittedPortrait.width / fittedPortrait.height - 0.5) < 0.001) // aspect ratio preserved
        #expect(fittedPortrait.width <= 300)
        #expect(fittedPortrait.height <= 300)

        // Small image: should not be scaled up
        let smallSize = CGSize(width: 50, height: 50)
        let fittedSmall = ImageObject.fittingSize(for: smallSize, maxDimension: 300)
        #expect(fittedSmall.width == 50)
        #expect(fittedSmall.height == 50)
    }

    @Test func addImageObjectCentersOnPosition() async throws {
        let vm = CanvasViewModel()
        let pngData = makeSinglePixelPNG()
        let imageSize = CGSize(width: 600, height: 400)
        let center = CGPoint(x: 200, y: 150)

        let id = vm.addImageObject(imageData: pngData, imageSize: imageSize, at: center)

        let obj = vm.objects.compactMap { $0.asType(ImageObject.self) }.first { $0.id == id }
        #expect(obj != nil)

        // Size should match real pixel dimensions when no maxSize is given
        #expect(obj!.size == imageSize)

        // The object's bounding box center should match the requested center
        let bbox = obj!.boundingBox()
        #expect(abs(bbox.midX - center.x) < 0.5)
        #expect(abs(bbox.midY - center.y) < 0.5)
    }

    @Test func addImageObjectCapsToMaxSize() async throws {
        let vm = CanvasViewModel()
        let pngData = makeSinglePixelPNG()
        // Large image that exceeds the viewport
        let imageSize = CGSize(width: 2000, height: 1000)
        let maxSize = CGSize(width: 800, height: 600)
        let center = CGPoint(x: 400, y: 300)

        let id = vm.addImageObject(imageData: pngData, imageSize: imageSize, at: center, maxSize: maxSize)
        let obj = vm.objects.compactMap { $0.asType(ImageObject.self) }.first { $0.id == id }!

        // Should fit within the min(maxSize) dimension while preserving aspect ratio
        #expect(obj.size.width <= maxSize.width)
        #expect(obj.size.height <= maxSize.height)
        #expect(abs(obj.size.width / obj.size.height - 2.0) < 0.001) // 2000/1000 aspect ratio preserved
    }

    @Test func pastedImageIsHighestZIndex() async throws {
        let vm = CanvasViewModel()
        // Add some existing objects
        _ = vm.addTextObject(at: CGPoint(x: 10, y: 10))
        vm.addShape(preset: .rectangle, from: CGPoint(x: 50, y: 50), to: CGPoint(x: 150, y: 150))

        let maxExistingZIndex = vm.objects.map(\.zIndex).max() ?? 0

        let pngData = makeSinglePixelPNG()
        let id = vm.addImageObject(imageData: pngData, imageSize: CGSize(width: 100, height: 100), at: .zero)
        let imageObj = vm.objects.compactMap { $0.asType(ImageObject.self) }.first { $0.id == id }!

        #expect(imageObj.zIndex > maxExistingZIndex)
    }
    // MARK: - LineObject Codable Round-Trip

    @Test func lineObjectCodableRoundTrip() async throws {
        let original = LineObject(
            startPoint: CGPoint(x: 10, y: 20),
            endPoint: CGPoint(x: 200, y: 150),
            strokeColor: .blue,
            strokeWidth: 3,
            strokeStyle: .dashed(pattern: [8, 4]),
            startArrowHead: .open,
            endArrowHead: .filled,
            label: "Edge",
            rotation: 0.3,
            zIndex: 4
        )

        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(LineObject.self, from: data)

        #expect(decoded.id == original.id)
        #expect(decoded.startPoint == original.startPoint)
        #expect(decoded.endPoint == original.endPoint)
        #expect(decoded.strokeWidth == original.strokeWidth)
        #expect(decoded.strokeStyle == original.strokeStyle)
        #expect(decoded.startArrowHead == original.startArrowHead)
        #expect(decoded.endArrowHead == original.endArrowHead)
        #expect(decoded.label == original.label)
        #expect(decoded.rotation == original.rotation)
        #expect(decoded.zIndex == original.zIndex)
        #expect(decoded.isEditingLabel == false)
    }

    @Test func lineObjectCodableCanvasObjectRoundTrip() async throws {
        let original = LineObject(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 100, y: 100),
            strokeColor: .red,
            endArrowHead: .filled
        )
        let wrapped = AnyCanvasObject(original)
        let codable = CodableCanvasObject.from(wrapped)
        #expect(codable != nil)

        let data = try JSONEncoder().encode([codable!])
        let decoded = try JSONDecoder().decode([CodableCanvasObject].self, from: data)
        #expect(decoded.count == 1)

        let restored = decoded[0].toAnyCanvasObject(newId: UUID(), zIndex: 0, offset: .zero)
        #expect(restored != nil)
        let restoredLine = restored?.asType(LineObject.self)
        #expect(restoredLine != nil)
        #expect(restoredLine?.endArrowHead == .filled)
    }

}

// MARK: - Helpers

private func makeSinglePixelPNG() -> Data {
    // Create a 1x1 white NSImage and convert to PNG
    let image = NSImage(size: NSSize(width: 1, height: 1))
    image.lockFocus()
    NSColor.white.setFill()
    NSRect(x: 0, y: 0, width: 1, height: 1).fill()
    image.unlockFocus()
    guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        return Data()
    }
    let rep = NSBitmapImageRep(cgImage: cgImage)
    return rep.representation(using: .png, properties: [:]) ?? Data()
}
