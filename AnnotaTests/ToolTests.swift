//
//  ToolTests.swift
//  AnnotaTests
//

import Testing
import SwiftUI
@testable import AnotarCanvas

@MainActor
@Suite(.serialized)
struct ToolRegistryTests {

    @Test func registryHasBuiltInTools() {
        let registry = ToolRegistry.shared
        #expect(registry.registeredTools.count >= 4)
        #expect(registry.tool(for: .rectangle) != nil)
        #expect(registry.tool(for: .line) != nil)
        #expect(registry.tool(for: .arrow) != nil)
        #expect(registry.tool(for: .text) != nil)
    }

    @Test func shapeToolsRegistered() {
        let registry = ToolRegistry.shared
        // All shape tools should be registered
        #expect(registry.tool(for: .rectangle) != nil)
        #expect(registry.tool(for: .oval) != nil)
        #expect(registry.tool(for: .triangle) != nil)
        #expect(registry.tool(for: .diamond) != nil)
        #expect(registry.tool(for: .star) != nil)
    }

    @Test func selectAndHandNotRegistered() {
        // Select and Hand are now registered tools — tool(for:) returns non-nil
        let registry = ToolRegistry.shared
        #expect(registry.tool(for: .select) != nil)
        #expect(registry.tool(for: .hand) != nil)
    }

    @Test func toolProperties() {
        let registry = ToolRegistry.shared
        let shapeTool = registry.tool(for: .rectangle)!
        #expect(shapeTool.name == "Rectangle")
        #expect(shapeTool.category == .shape)

        let lineTool = registry.tool(for: .line)!
        #expect(lineTool.name == "Line")
        #expect(lineTool.category == .drawing)

        let arrowTool = registry.tool(for: .arrow)!
        #expect(arrowTool.name == "Arrow")
        #expect(arrowTool.category == .drawing)

        let textTool = registry.tool(for: .text)!
        #expect(textTool.name == "Text")
        #expect(textTool.category == .annotation)
    }

    @Test func toolsByCategory() {
        let registry = ToolRegistry.shared
        let drawingTools = registry.tools(in: .drawing)
        #expect(drawingTools.count >= 2) // line + arrow
        let shapeTools = registry.tools(in: .shape)
        #expect(shapeTools.count >= 5) // rectangle, oval, triangle, diamond, star
        let annotationTools = registry.tools(in: .annotation)
        #expect(annotationTools.count >= 1)
    }
}

@MainActor
@Suite(.serialized)
struct ShapeToolTests {

    @Test func rectangleToolCreatesObject() {
        let vm = CanvasViewModel()
        vm.selectedTool = .rectangle
        vm.activeColor = .blue

        let tool = RectangleTool()
        tool.handleDragChanged(
            start: CGPoint(x: 10, y: 10),
            current: CGPoint(x: 110, y: 110),
            viewModel: vm
        )
        #expect(vm.dragStartPoint != nil)
        #expect(vm.currentDragPoint != nil)

        tool.handleDragEnded(
            start: CGPoint(x: 10, y: 10),
            end: CGPoint(x: 110, y: 110),
            viewModel: vm,
            shiftHeld: false
        )
        #expect(vm.objects.count == 1)
        #expect(vm.objects.first?.asType(ShapeObject.self) != nil)

        // Verify the shape was created with correct properties
        let shape = vm.objects.first?.asType(ShapeObject.self)
        #expect(shape?.toolId == "rectangle")
        #expect(shape?.size.width == 100)
        #expect(shape?.size.height == 100)
    }

    @Test func allShapeToolsHaveUniqueToolIds() {
        let rectangleTool = RectangleTool()
        let ovalTool = OvalTool()
        let triangleTool = TriangleTool()
        let diamondTool = DiamondTool()
        let starTool = StarTool()

        let toolIds = [
            rectangleTool.toolType,
            ovalTool.toolType,
            triangleTool.toolType,
            diamondTool.toolType,
            starTool.toolType
        ]

        #expect(Set(toolIds).count == toolIds.count)
    }

    @Test func allShapeToolsHaveShapeCategory() {
        let rectangleTool = RectangleTool()
        let ovalTool = OvalTool()
        let triangleTool = TriangleTool()
        let diamondTool = DiamondTool()
        let starTool = StarTool()

        #expect(rectangleTool.category == .shape)
        #expect(ovalTool.category == .shape)
        #expect(triangleTool.category == .shape)
        #expect(diamondTool.category == .shape)
        #expect(starTool.category == .shape)
    }
}

@MainActor
@Suite(.serialized)
struct LineToolTests {

    @Test func lineToolCreatesLineObject() {
        let vm = CanvasViewModel()
        vm.selectedTool = .line

        let tool = LineTool()
        tool.handleDragEnded(
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 100, y: 100),
            viewModel: vm,
            shiftHeld: false
        )
        #expect(vm.objects.count == 1)
        let line = vm.objects.first?.asType(LineObject.self)
        #expect(line != nil)
        #expect(line?.isArrow == false)
    }
}

@MainActor
@Suite(.serialized)
struct ArrowToolTests {

    @Test func arrowToolCreatesArrowObject() {
        let vm = CanvasViewModel()
        vm.selectedTool = .arrow

        let tool = ArrowTool()
        tool.handleDragEnded(
            start: CGPoint(x: 0, y: 0),
            end: CGPoint(x: 100, y: 50),
            viewModel: vm,
            shiftHeld: false
        )
        #expect(vm.objects.count == 1)
        let line = vm.objects.first?.asType(LineObject.self)
        #expect(line != nil)
        #expect(line?.isArrow == true)
    }
}

@MainActor
@Suite(.serialized)
struct TextToolTests {

    @Test func textToolClickCreatesTextObject() {
        let vm = CanvasViewModel()
        vm.selectedTool = .text

        let tool = TextTool()
        tool.handleClick(
            at: CGPoint(x: 50, y: 50),
            viewModel: vm,
            shiftHeld: false
        )
        #expect(vm.objects.count == 1)
        #expect(vm.objects.first?.asType(TextObject.self) != nil)
        #expect(vm.objects.first?.isEditing == true)
    }

    @Test func textToolClickOnExistingObjectStartsEditing() {
        let vm = CanvasViewModel()
        vm.selectedTool = .text

        // Create a text object first
        let textObj = TextObject(position: CGPoint(x: 50, y: 50), text: "Hello")
        let id = vm.addObject(textObj)
        vm.deselectAll()
        #expect(vm.objects.first?.isEditing == false)

        // Click on it should start editing
        let tool = TextTool()
        tool.handleClick(
            at: CGPoint(x: 50, y: 50),
            viewModel: vm,
            shiftHeld: false
        )
        // The object at that position should be in editing mode
        #expect(vm.isSelected(id))
    }
}

// MARK: - ObjectViewRegistry Tests

@MainActor
@Suite(.serialized)
struct ObjectViewRegistryTests {

    @Test func registeredTypesReturnViews() {
        // ToolRegistry.shared triggers registerBuiltInObjectTypes
        _ = ToolRegistry.shared

        let shape = ShapeObject(
            position: .zero,
            size: CGSize(width: 100, height: 100),
            svgPath: "M 0,0 L 100,0 L 100,100 L 0,100 Z",
            toolId: "rectangle"
        )
        let wrapped = AnyCanvasObject(shape)
        let vm = CanvasViewModel()

        // Interactive view should not be EmptyView
        let view = ObjectViewRegistry.view(for: wrapped, isSelected: false, viewModel: vm)
        // We can't easily inspect AnyView, but we can verify it doesn't crash
        #expect(type(of: view) == AnyView.self)
    }

    @Test func exportRegisteredTypesReturnViews() {
        _ = ToolRegistry.shared

        let text = TextObject(position: .zero, text: "Hello")
        let wrapped = AnyCanvasObject(text)

        let view = ObjectViewRegistry.exportView(for: wrapped)
        #expect(type(of: view) == AnyView.self)
    }
}

// MARK: - CodableObjectRegistry Tests

@MainActor
@Suite(.serialized)
struct CodableObjectRegistryTests {

    @Test func textObjectEncodeDecodeRoundTrip() throws {
        _ = ToolRegistry.shared

        let original = TextObject(
            position: CGPoint(x: 10, y: 20),
            text: "Registry Test",
            fontSize: 18
        )
        let wrapped = AnyCanvasObject(original)

        // Encode via registry
        let disc = CodableObjectRegistry.discriminator(for: wrapped)
        #expect(disc == "text")

        let data = CodableObjectRegistry.encode(wrapped)
        #expect(data != nil)

        // Decode via registry
        let decoded = CodableObjectRegistry.decode(discriminator: "text", data: data!)
        #expect(decoded != nil)

        let textObj = decoded as? TextObject
        #expect(textObj != nil)
        #expect(textObj?.id == original.id)
        #expect(textObj?.text == "Registry Test")
    }

    @Test func shapeObjectEncodeDecodeRoundTrip() throws {
        _ = ToolRegistry.shared

        let ovalPath = """
            M 50 0 C 77.6 0 100 22.4 100 50
            C 100 77.6 77.6 100 50 100
            C 22.4 100 0 77.6 0 50
            C 0 22.4 22.4 0 50 0 Z
            """

        let original = ShapeObject(
            position: CGPoint(x: 30, y: 40),
            size: CGSize(width: 100, height: 80),
            svgPath: ovalPath,
            toolId: "oval",
            color: .blue
        )
        let wrapped = AnyCanvasObject(original)

        let disc = CodableObjectRegistry.discriminator(for: wrapped)
        #expect(disc == "shape")

        let data = CodableObjectRegistry.encode(wrapped)
        #expect(data != nil)

        let decoded = CodableObjectRegistry.decode(discriminator: "shape", data: data!) as? ShapeObject
        #expect(decoded != nil)
        #expect(decoded?.id == original.id)
        #expect(decoded?.toolId == "oval")
    }

    @Test func lineObjectEncodeDecodeRoundTrip() throws {
        _ = ToolRegistry.shared

        let original = LineObject(
            startPoint: CGPoint(x: 0, y: 0),
            endPoint: CGPoint(x: 100, y: 100),
            strokeColor: .red,
            endArrowHead: .filled
        )
        let wrapped = AnyCanvasObject(original)

        let disc = CodableObjectRegistry.discriminator(for: wrapped)
        #expect(disc == "line")

        let data = CodableObjectRegistry.encode(wrapped)
        #expect(data != nil)

        let decoded = CodableObjectRegistry.decode(discriminator: "line", data: data!) as? LineObject
        #expect(decoded != nil)
        #expect(decoded?.id == original.id)
        #expect(decoded?.endArrowHead == .filled)
    }

    @Test func unregisteredTypeReturnsNil() {
        _ = ToolRegistry.shared

        let result = CodableObjectRegistry.decode(discriminator: "unknown_type", data: Data())
        #expect(result == nil)
    }

    @Test func usesControlPointsFlagWorks() {
        let line = LineObject(startPoint: .zero, endPoint: CGPoint(x: 100, y: 0))
        let wrappedLine = AnyCanvasObject(line)
        #expect(wrappedLine.usesControlPoints == true)

        let shape = ShapeObject(
            position: .zero,
            size: CGSize(width: 50, height: 50),
            svgPath: "M 0,0 L 100,0 L 100,100 L 0,100 Z",
            toolId: "rectangle"
        )
        let wrappedShape = AnyCanvasObject(shape)
        #expect(wrappedShape.usesControlPoints == false)

        let text = TextObject(position: .zero, text: "hi")
        let wrappedText = AnyCanvasObject(text)
        #expect(wrappedText.usesControlPoints == false)
    }

    @Test func genericAddObjectWorks() {
        let vm = CanvasViewModel()
        let shape = ShapeObject(
            position: CGPoint(x: 10, y: 10),
            size: CGSize(width: 50, height: 50),
            svgPath: "M 0,0 L 100,0 L 100,100 L 0,100 Z",
            toolId: "rectangle"
        )
        let id = vm.addObject(shape)
        #expect(vm.objects.count == 1)
        #expect(vm.objects.first?.id == id)
        #expect(vm.objects.first?.asType(ShapeObject.self) != nil)
    }
}
