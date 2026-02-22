# Generic ShapeObject Design

## Problem Summary

`RectangleObject` and `OvalObject` are ~95% identical. The only differences are:

- `contains()` — bounding-box vs. ellipse equation
- `hitTest()` edge detection — straight edges vs. ellipse boundary
- The SwiftUI primitive used to render — `Rectangle()` vs `Ellipse()`
- `cornerRadius` exists only on rectangle

`CanvasViewModel` has the same `if var rectObj ... else if var ovalObj ...` pattern **10 times**. Adding any new shape would multiply this further.

---

## Core Idea

Replace both concrete types with a single `ShapeObject` that stores a **`ShapePreset`** — a value type that owns the SVG path string. The preset's `CGPath` (scaled to the object's actual bounding box at runtime) drives rendering, `contains()`, and `hitTest()`.

- **`ShapePreset`** — lightweight value type with a normalized SVG path string and a display name. Ships built-in presets. User-defined presets just need a valid SVG string.
- **`ShapeObject`** — single struct replacing both `RectangleObject` and `OvalObject`. All shared properties live here once; shape-specific behaviour is fully delegated to `ShapePreset`.
- **`ShapeObjectView`** — single SwiftUI view that calls `Path(svgPath:, in: rect)` from SVGPath and renders it. Text overlay is identical to both current views.

---

## Dependency: `nicklockwood/SVGPath`

Add to the Xcode project as a Swift Package:

```
url: "https://github.com/nicklockwood/SVGPath.git"
version: .upToNextMinor(from: "1.3.0")
```

SwiftUI integration used: `Path(svgPath: string, in: rect)` — scales the path to fit the object's actual `CGRect` automatically.

---

## 1. `ShapePreset` (new file: `Models/ShapePreset.swift`)

```swift
import SwiftUI
import SVGPath

/// A value type describing a shape via a normalized SVG path.
/// Paths are defined in a 0–100 unit coordinate space; SVGPath scales
/// them to fit the object's actual bounding rect at render/hit-test time.
struct ShapePreset: Codable, Hashable, Sendable {
    let name: String
    let svgPath: String

    init(name: String, svgPath: String) {
        self.name = name
        self.svgPath = svgPath
    }
}

// MARK: - Built-in Presets

extension ShapePreset {
    static let rectangle = ShapePreset(
        name: "Rectangle",
        svgPath: "M 0 0 L 100 0 L 100 100 L 0 100 Z"
    )

    static let oval = ShapePreset(
        name: "Oval",
        svgPath: """
        M 50 0
        C 77.6 0 100 22.4 100 50
        C 100 77.6 77.6 100 50 100
        C 22.4 100 0 77.6 0 50
        C 0 22.4 22.4 0 50 0 Z
        """
    )

    /// Corner radius is a value in the 0–100 unit space (e.g. 12 ≈ 12% of the shape).
    static func roundedRectangle(cornerRadius: CGFloat) -> ShapePreset {
        let r = min(max(cornerRadius, 0), 50)
        let svgPath = """
        M \(r) 0
        L \(100 - r) 0
        Q 100 0 100 \(r)
        L 100 \(100 - r)
        Q 100 100 \(100 - r) 100
        L \(r) 100
        Q 0 100 0 \(100 - r)
        L 0 \(r)
        Q 0 0 \(r) 0 Z
        """
        return ShapePreset(name: "Rounded Rectangle", svgPath: svgPath)
    }

    static let triangle = ShapePreset(
        name: "Triangle",
        svgPath: "M 50 0 L 100 100 L 0 100 Z"
    )

    static let diamond = ShapePreset(
        name: "Diamond",
        svgPath: "M 50 0 L 100 50 L 50 100 L 0 50 Z"
    )

    static let arrow = ShapePreset(
        name: "Arrow",
        svgPath: "M 0 30 L 60 30 L 60 0 L 100 50 L 60 100 L 60 70 L 0 70 Z"
    )

    static let star = ShapePreset(
        name: "Star",
        svgPath: """
        M 50 0 L 61 35 L 98 35 L 68 57 L 79 91
        L 50 70 L 21 91 L 32 57 L 2 35 L 39 35 Z
        """
    )

    /// All built-in presets in display order.
    static let builtIn: [ShapePreset] = [
        .rectangle, .oval, .roundedRectangle(cornerRadius: 12),
        .triangle, .diamond, .arrow, .star
    ]
}

// MARK: - Rendering Helpers

extension ShapePreset {
    /// Returns a CGPath scaled to fill `rect` exactly (stretch, not letterbox).
    func cgPath(in rect: CGRect) -> CGPath {
        (try? CGPath.from(svgPath: svgPath, in: rect)) ?? CGPath(rect: rect, transform: nil)
    }

    /// Returns a SwiftUI Path scaled to fill `rect` exactly.
    func path(in rect: CGRect) -> Path {
        (try? Path(svgPath: svgPath, in: rect)) ?? Path(rect)
    }

    /// SF Symbol name for toolbar display.
    var sfSymbol: String {
        switch name {
        case "Rectangle":         return "rectangle"
        case "Oval":              return "circle"
        case "Rounded Rectangle": return "rectangle.roundedtop"
        case "Triangle":          return "triangle"
        case "Diamond":           return "diamond"
        case "Arrow":             return "arrow.right"
        case "Star":              return "star"
        default:                  return "square.on.square"
        }
    }
}
```

**Key design decisions:**

- Paths use a `0–100` unit coordinate space — human-readable and easy to hand-author.
- `SVGPath.cgPath(in: rect)` scales to the actual pixel rect at use time, so the same preset works at any size.
- `roundedRectangle(cornerRadius:)` is a factory function, not a stored enum case. The radius is baked into the SVG string; `ShapeObject` has no separate `cornerRadius` property.
- `Codable` conformance means presets survive serialisation via the SVG string alone.

---

## 2. `ShapeObject` (new file: `Models/ShapeObject.swift`)

Replaces both `RectangleObject.swift` and `OvalObject.swift`.

```swift
import SwiftUI
import SVGPath

struct ShapeObject: CanvasObject, TextContentObject, StrokableObject, FillableObject {
    // MARK: - CanvasObject
    let id: UUID
    var position: CGPoint
    var size: CGSize
    var rotation: CGFloat = 0
    var isLocked: Bool = false
    var zIndex: Int = 0

    // MARK: - StrokableObject
    var strokeColor: Color
    var strokeWidth: CGFloat = 2
    var strokeStyle: StrokeStyleType = .solid

    // MARK: - FillableObject
    var fillColor: Color
    var fillOpacity: CGFloat = 0.1

    // MARK: - TextContentObject
    var text: String = ""
    var textAttributes: TextAttributes = .default
    var isEditing: Bool = false

    // MARK: - Shape-specific
    var preset: ShapePreset
    var autoResizeHeight: Bool = false

    // MARK: - Init

    init(
        id: UUID = UUID(),
        position: CGPoint,
        size: CGSize,
        preset: ShapePreset = .rectangle,
        color: Color = .black,
        strokeWidth: CGFloat = 2,
        strokeStyle: StrokeStyleType = .solid,
        fillOpacity: CGFloat = 0.1,
        text: String = "",
        isEditing: Bool = false,
        autoResizeHeight: Bool = false,
        rotation: CGFloat = 0,
        isLocked: Bool = false,
        zIndex: Int = 0
    ) {
        self.id = id
        self.position = position
        self.size = size
        self.preset = preset
        self.strokeColor = color
        self.fillColor = color
        self.strokeWidth = strokeWidth
        self.strokeStyle = strokeStyle
        self.fillOpacity = fillOpacity
        self.text = text
        self.isEditing = isEditing
        self.autoResizeHeight = autoResizeHeight
        self.rotation = rotation
        self.isLocked = isLocked
        self.zIndex = zIndex
    }

    // MARK: - CanvasObject

    func contains(_ point: CGPoint) -> Bool {
        let localPoint = rotation != 0 ? transformToLocal(point) : point
        return preset.cgPath(in: boundingBox()).contains(localPoint)
    }

    func boundingBox() -> CGRect {
        CGRect(origin: position, size: size)
    }

    func hitTest(_ point: CGPoint, threshold: CGFloat) -> HitTestResult? {
        let localPoint = rotation != 0 ? transformToLocal(point) : point
        let bounds = boundingBox()

        // Quick-reject: outside expanded bounding box
        guard bounds.insetBy(dx: -threshold, dy: -threshold).contains(localPoint) else {
            return nil
        }

        // Corners: always the four bounding-box corners (resize handles are rectangular)
        if let corner = hitTestCorner(point: localPoint, bounds: bounds, threshold: threshold) {
            return .corner(corner)
        }

        // Edge: stroke the CGPath and test containment — shape-agnostic, handles curves
        let path = preset.cgPath(in: bounds)
        let strokedPath = path.copy(
            strokingWithWidth: threshold * 2,
            lineCap: .round,
            lineJoin: .round,
            miterLimit: 1
        )
        if strokedPath.contains(localPoint) {
            return .edge(edgeForPoint(localPoint, in: bounds))
        }

        // Body: interior of the shape path
        if path.contains(localPoint) {
            return .body
        }

        return nil
    }
}

// MARK: - Private Helpers

private extension ShapeObject {
    func hitTestCorner(point: CGPoint, bounds: CGRect, threshold: CGFloat) -> Corner? {
        let corners: [(Corner, CGPoint)] = [
            (.topLeft,     CGPoint(x: bounds.minX, y: bounds.minY)),
            (.topRight,    CGPoint(x: bounds.maxX, y: bounds.minY)),
            (.bottomLeft,  CGPoint(x: bounds.minX, y: bounds.maxY)),
            (.bottomRight, CGPoint(x: bounds.maxX, y: bounds.maxY)),
        ]
        for (corner, cp) in corners {
            if hypot(point.x - cp.x, point.y - cp.y) <= threshold { return corner }
        }
        return nil
    }

    /// Classify a point near the shape boundary into the nearest cardinal edge.
    /// Normalises by half-extents so aspect ratio doesn't bias the result.
    func edgeForPoint(_ point: CGPoint, in bounds: CGRect) -> Edge {
        let dx = point.x - bounds.midX
        let dy = point.y - bounds.midY
        let nx = dx / (bounds.width  / 2)
        let ny = dy / (bounds.height / 2)
        if abs(nx) >= abs(ny) {
            return nx >= 0 ? .right : .left
        } else {
            return ny >= 0 ? .bottom : .top
        }
    }
}
```

**Key design decisions:**

- `contains()` delegates to `CGPath.contains()` — correct for any shape, zero custom math.
- Edge hit-testing uses `CGPath.copy(strokingWithWidth:)` which strokes the outline into a filled region. This is shape-agnostic and matches what is visible on screen exactly — it handles ellipses, polygons, and arbitrary Bézier curves uniformly.
- Corner handles remain at the four bounding-box corners regardless of shape — this is where the selection box resize handles are anchored.
- No separate `cornerRadius` property — it lives inside `ShapePreset.svgPath`.

---

## 3. `AnyCanvasObject` changes (minimal)

Three targeted changes to `Models/AnyCanvasObject.swift`:

```swift
// 1. ObjectType: remove .rectangle and .oval, add .shape
enum ObjectType {
    case text, shape, line, arrow, pencil, highlighter,
         autoNumber, sticker, note, image, mosaic, unknown
}

// 2. Type switch in init:
switch object {
case is TextObject:  self.objectType = .text
case is ShapeObject: self.objectType = .shape
default:             self.objectType = .unknown
}

// 3. Accessors: remove asRectangleObject / asOvalObject, add:
var asShapeObject: ShapeObject? { _object as? ShapeObject }
```

---

## 4. `DrawingTool` changes (`Models/DrawingTool.swift`)

```swift
enum DrawingTool: Equatable {
    case select
    case text
    case shape(ShapePreset)   // replaces .rectangle and .oval
    case hand
}

extension DrawingTool {
    var isShapeTool: Bool {
        if case .shape = self { return true }
        return false
    }
    var shapePreset: ShapePreset? {
        if case .shape(let p) = self { return p }
        return nil
    }
}
```

`DrawingTool` needs an explicit `Equatable` conformance because `ShapePreset` (associated value) is already `Equatable`, so synthesis works automatically.

---

## 5. `ShapeObjectView` (new file: `Views/ShapeObjectView.swift`)

Replaces both `RectangleObjectView.swift` and `OvalObjectView.swift`. Also fixes three bugs present in both old views: hardcoded `lineWidth: 2`, hardcoded `opacity(0.1)`, hardcoded `fontSize: 16 / foregroundColor(.black)`.

```swift
import SwiftUI
import SVGPath

struct ShapeObjectView: View {
    let object: ShapeObject
    var isSelected: Bool = false
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        ZStack {
            let frameRect = CGRect(
                origin: .zero,
                size: CGSize(width: object.size.width, height: effectiveHeight)
            )

            // Shape stroke
            object.preset.path(in: frameRect)
                .stroke(object.strokeColor, style: object.swiftUIStrokeStyle)

            // Shape fill
            object.preset.path(in: frameRect)
                .fill(object.effectiveFillColor)

            // Text overlay
            if object.isEditing {
                ConstrainedAutoGrowingTextView(
                    text: textBinding,
                    fontSize: object.textAttributes.fontSize,
                    textColor: NSColor(object.textAttributes.textColor.nsColor),
                    maxWidth: object.size.width - 16,
                    alignment: .center,
                    onHeightChange: { newHeight in
                        if object.autoResizeHeight {
                            updateHeightIfNeeded(newHeight + 24)
                        }
                    }
                )
                .frame(width: object.size.width - 16)
                .padding(8)
            } else if !object.text.isEmpty {
                Text(object.text)
                    .font(object.font)
                    .foregroundColor(object.textAttributes.textColor.color)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(width: object.size.width - 16)
                    .padding(8)
            }
        }
        .frame(width: object.size.width, height: effectiveHeight)
        .rotationEffect(.radians(object.rotation))
        .position(
            x: object.position.x + object.size.width / 2,
            y: object.position.y + effectiveHeight / 2
        )
        .onChange(of: object.text) { _ in
            if object.autoResizeHeight { updateHeight() }
        }
    }

    private var effectiveHeight: CGFloat {
        guard object.autoResizeHeight && !object.text.isEmpty else { return object.size.height }
        return max(object.size.height, calculatedTextHeight + 24)
    }

    private var calculatedTextHeight: CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: object.textAttributes.nsFont]
        let str = NSAttributedString(string: object.text, attributes: attrs)
        let rect = str.boundingRect(
            with: NSSize(width: object.size.width - 32, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )
        return ceil(rect.height)
    }

    private func updateHeight() {
        let newHeight = calculatedTextHeight + 24
        if newHeight > object.size.height {
            viewModel.updateShapeObject(withId: object.id) { $0.size.height = newHeight }
        }
    }

    private func updateHeightIfNeeded(_ newHeight: CGFloat) {
        if newHeight > object.size.height {
            viewModel.updateShapeObject(withId: object.id) { $0.size.height = newHeight }
        }
    }

    private var textBinding: Binding<String> {
        Binding(
            get: { object.text },
            set: { viewModel.updateText(objectId: object.id, text: $0) }
        )
    }
}
```

---

## 6. `CanvasViewModel` changes

### Generic updater eliminates all type-dispatch duplication

```swift
// Single generic updater replaces updateRectangleObject + updateOvalObject
func updateObject<T: CanvasObject>(withId id: UUID, as type: T.Type,
                                   update: (inout T) -> Void) {
    guard let index = objectIndex(withId: id),
          var typed = objects[index].asType(T.self) else { return }
    update(&typed)
    objects[index] = AnyCanvasObject(typed)
}

func updateShapeObject(withId id: UUID, update: (inout ShapeObject) -> Void) {
    updateObject(withId: id, as: ShapeObject.self, update: update)
}
func updateTextObject(withId id: UUID, update: (inout TextObject) -> Void) {
    updateObject(withId: id, as: TextObject.self, update: update)
}
```

### Object creation

```swift
func addShape(preset: ShapePreset, from start: CGPoint, to end: CGPoint) {
    let origin = CGPoint(x: min(start.x, end.x), y: min(start.y, end.y))
    let size   = CGSize(width: abs(end.x - start.x), height: abs(end.y - start.y))
    guard size.width > 1 && size.height > 1 else { return }
    var obj = ShapeObject(
        position: origin,
        size: size,
        preset: preset,
        color: activeColor,
        autoResizeHeight: autoResizeShapes
    )
    obj.zIndex = nextZIndex
    nextZIndex += 1
    objects.append(AnyCanvasObject(obj))
    sortObjectsByZIndex()
}
```

### Collapsed dispatch pattern

Every method that previously had `if var rectObj ... else if var ovalObj ...` becomes two branches instead of three (`TextObject` + `ShapeObject`). Example for `startEditing`:

```swift
func startEditing(objectId: UUID) {
    guard let index = objectIndex(withId: objectId) else { return }
    if var obj = objects[index].asTextObject {
        obj.isEditing = true
        objects[index] = AnyCanvasObject(obj)
    } else if var obj = objects[index].asShapeObject {
        obj.isEditing = true
        objects[index] = AnyCanvasObject(obj)
    }
    selectedObjectId = objectId
}
```

### Backward compatibility computed properties

```swift
var shapeObjects: [ShapeObject] { objects.compactMap { $0.asShapeObject } }
// rectangleObjects / ovalObjects removed
```

---

## 7. `CanvasView` changes

```swift
// Rendering:
// Before: ForEach(viewModel.rectangleObjects) + ForEach(viewModel.ovalObjects)
// After:
ForEach(viewModel.shapeObjects) { shape in
    ShapeObjectView(object: shape,
                    isSelected: viewModel.isSelected(shape.id),
                    viewModel: viewModel)
}

// Drag preview — shape-agnostic:
if viewModel.selectedTool.isShapeTool,
   let preset = viewModel.selectedTool.shapePreset,
   let start = viewModel.dragStartPoint,
   let current = viewModel.currentDragPoint {
    let width  = abs(current.x - start.x)
    let height = abs(current.y - start.y)
    let x = min(start.x, current.x) + width / 2
    let y = min(start.y, current.y) + height / 2
    preset.path(in: CGRect(x: 0, y: 0, width: width, height: height))
        .stroke(viewModel.activeColor.opacity(0.5), lineWidth: 2)
        .frame(width: width, height: height)
        .position(x: x, y: y)
}

// Tool check:
// Before: viewModel.selectedTool == .rectangle || viewModel.selectedTool == .oval
// After:  viewModel.selectedTool.isShapeTool

// Shape creation on drag end:
if let preset = viewModel.selectedTool.shapePreset {
    viewModel.addShape(preset: preset, from: start, to: end)
}
```

The shift-constrain-to-circle logic for the oval tool moves into `CanvasView` as a preset-specific check:

```swift
// Only constrain to square when drawing an oval
if preset == .oval && NSEvent.modifierFlags.contains(.shift) {
    // constrain width/height to equal
}
```

---

## 8. `ToolbarView` changes

```swift
// Before: two hardcoded buttons
toolButton(.rectangle, icon: "rectangle", tooltip: "Rectangle")
toolButton(.oval,      icon: "circle",    tooltip: "Oval")

// After: driven by ShapePreset.builtIn
ForEach(ShapePreset.builtIn, id: \.name) { preset in
    toolButton(.shape(preset), icon: preset.sfSymbol, tooltip: preset.name)
}
```

---

## 9. Files deleted

| File | Replaced by |
|---|---|
| `Models/RectangleObject.swift` | `Models/ShapeObject.swift` |
| `Models/OvalObject.swift` | `Models/ShapeObject.swift` |
| `Views/RectangleObjectView.swift` | `Views/ShapeObjectView.swift` |
| `Views/OvalObjectView.swift` | `Views/ShapeObjectView.swift` |

---

## 10. Tests (`AnnotaTests/ShapeObjectTests.swift`)

```swift
import Testing
@testable import Annota

@Suite("ShapeObject")
struct ShapeObjectTests {
    // contains() — rectangle preset
    @Test func rectangleContainsCenterPoint()
    @Test func rectangleDoesNotContainOutsidePoint()

    // contains() — oval preset (corners of bounding box must be outside)
    @Test func ovalContainsCenterPoint()
    @Test func ovalDoesNotContainCornerOfBoundingBox()

    // contains() — triangle (centroid inside; corner of bounding box may be outside)
    @Test func triangleContainsCentroid()
    @Test func triangleDoesNotContainBottomLeftCornerOfBoundingBox()

    // hitTest() — corners always on bounding box for all presets
    @Test func hitTestCornerDetectedForRectangle()
    @Test func hitTestCornerDetectedForOval()
    @Test func hitTestCornerDetectedForTriangle()

    // hitTest() — edge detection follows shape boundary, not bounding box
    @Test func hitTestEdgeOnOvalCurveNotBoundingBoxEdge()
    @Test func hitTestBodyInsideOval()
    @Test func hitTestNilOutsideOvalBoundingBox()

    // Rotation
    @Test func rotatedShapeContainsPointInRotatedSpace()
    @Test func rotatedShapeDoesNotContainSamePointInUnrotatedSpace()

    // Custom SVG preset
    @Test func customSVGPathContainsExpectedPoints()
    @Test func customSVGPathRejectsPointsOutsideShape()
}
```

---

## Migration Summary

| | Before | After |
|---|---|---|
| Shape model files | 2 (`RectangleObject`, `OvalObject`) | 1 (`ShapeObject`) |
| Shape view files | 2 (`RectangleObjectView`, `OvalObjectView`) | 1 (`ShapeObjectView`) |
| ViewModel type-dispatch branches | 10 × 3 branches = 30 | 10 × 2 branches = 20 |
| Adding a new built-in shape | New model + new view + 10 ViewModel branches | 1 `static let` on `ShapePreset` |
| User-defined shape | Not possible | `ShapePreset(name: "My Shape", svgPath: "...")` |
| Hardcoded rendering values | strokeWidth 2, opacity 0.1, fontSize 16, color black | All read from model (bug fixes included) |

---

## Open Questions

**1. `DrawingTool.shape(ShapePreset)` vs separate cases**

Using an associated value means toolbar button highlighting works via `==` on `DrawingTool`. This requires iterating `ShapePreset.builtIn` in the toolbar rather than hardcoding cases. Alternative: keep `.rectangle` and `.oval` as top-level cases for the two most common shapes and only use `ShapePreset` internally on the model. This is a UX/API tradeoff.

**2. `CGPath.copy(strokingWithWidth:)` performance**

This allocates a new `CGPath` on every `hitTest` call. During interactive dragging this runs dozens of times per second. Options:
- Accept it — `CGPath` construction is fast in practice for simple paths
- Cache the stroked path on `ShapeObject`, invalidated when `size` or `preset` changes (requires a stored property or a lazy equivalent via a wrapper type)
- Use bounding-box edge logic for polygon presets and only use stroked path for curved ones

**3. SVGPath scaling mode**

`SVGPath`'s `in rect` parameter scales to fit while preserving aspect ratio by default (letterboxing). Canvas shapes should stretch to fill the exact bounding rect (e.g. a circle preset on a non-square object should render as an ellipse). This needs verification before committing — may require a manual `CGAffineTransform` scale instead of relying on the library's `in rect` parameter.

**4. Serialisation**

`ShapePreset` is `Codable`. If canvas state is ever persisted to disk, `ShapeObject` needs `Codable` too (all its properties already are, except `Color` which uses the existing `CodableColor` wrapper). Worth adding now to avoid a breaking schema change later.
