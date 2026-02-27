# Capabilities System

The framework uses a unified `Capability` type for both tools and objects. Type aliases `ToolCapability` and `ObjectCapability` provide semantic clarity.

## Built-in Capabilities

| Capability | Description |
|------------|-------------|
| `.stroke` | Stroke color, width, and style controls |
| `.fill` | Fill color controls |
| `.labelText` | Text label controls for lines/arrows |
| `.textFormatting` | Font, size, and alignment controls |
| `.shapeAttributes` | Shape-specific attributes (corner radius, etc.) |
| `.arrowheads` | Arrowhead style controls |
| `.pressureSensitive` | Pen pressure/tilt support |

## Usage

### Declare Capabilities

```swift
public struct PencilTool: CanvasTool {
    // Only show stroke controls
    public var capabilities: Set<ToolCapability> {
        [.stroke]
    }
}

public struct RectangleTool: CanvasTool {
    // Show stroke, fill, and shape controls
    public var capabilities: Set<ToolCapability> {
        [.stroke, .fill, .shapeAttributes]
    }
}
```

### Check Capabilities

```swift
let tool = toolRegistry.tool(for: viewModel.selectedTool)

if tool?.supports(.labelText) == true {
    // Show label text controls
}
```

## Custom Capabilities

Define your own capabilities using string literals:

```swift
// Define (works for both tools and objects - it's the same type)
extension Capability {
    public static let gradientFill: Capability = "gradientFill"
    public static let shadowEffect: Capability = "shadowEffect"
}

// Use in tool
public struct GradientTool: CanvasTool {
    public var capabilities: Set<ToolCapability> {
        [.stroke, .gradientFill]
    }
}

// Use in object capability checking
if selection.supports(.shadowEffect) {
    showShadowControls()
}
```

## Custom Controls

For complex attributes, provide custom UI via `customToolControls`:

```swift
public struct ArrowTool: CanvasTool {
    public var capabilities: Set<ToolCapability> {
        [.stroke, .labelText, .arrowheads]
    }

    public func customToolControls(viewModel: CanvasViewModel) -> AnyView? {
        AnyView(ArrowheadPicker(viewModel: viewModel))
    }
}
```

The framework shows standard controls for declared capabilities, then appends any custom controls.

## Tool vs Object Capabilities

Both use the same `Capability` type with semantic type aliases:

```swift
// ToolCapability - what a TOOL supports when creating objects
let toolCaps: Set<ToolCapability> = [.stroke, .fill, .labelText]

// ObjectCapability - what selected OBJECTS support for editing
let objCaps: Set<ObjectCapability> = [.stroke, .fill, .resize, .rotate]

// Both are actually just Capability under the hood
ToolCapability.stroke == ObjectCapability.stroke  // true - same type
```

**Additional Object-Specific Capabilities:**
- `.textContent` - Object has editable text
- `.textAlignment` - Object supports text alignment
- `.resize` - Object can be resized
- `.rotate` - Object can be rotated

Note: `.stroke` and `.fill` work for both tools and objects.

**Usage:**
```swift
let selection = SelectionCapabilities.from(objects: selectedObjects)

if selection.supports(.stroke) {
    // Show stroke controls
}
```

The system is extensible - third-party code can define custom object capabilities and check for them when rendering selection controls.
