# Archived Documentation

This directory contains design proposals and planning documents that have been implemented and are kept for historical reference.

## Implemented Proposals

### PLUGIN_ARCHITECTURE_DESIGN.md
**Status:** ✅ Implemented
**Date:** 2025-02
**Description:** Design proposal for plugin-based tool architecture with `CanvasTool` protocol, `ToolRegistry`, and dynamic tool registration. This architecture is now fully implemented in AnotarCanvas.

**Key Outcomes:**
- Tool-agnostic `CanvasView` (no hardcoded tool logic)
- Zero core modifications to add new tools
- `ToolManifest` for bundling tool + views + codable
- Separation of framework and application layers

### CANVAS_LIBRARY_PROPOSAL.md
**Status:** ✅ Implemented
**Date:** 2025-02
**Description:** Proposal for extracting canvas functionality as a reusable framework. Now implemented as the **AnotarCanvas** framework.

**Key Outcomes:**
- `AnotarCanvas` framework target created
- Public API surface defined
- Framework/application separation established
- Keyboard handling kept in application layer

### SHAPE_TOOL_REFACTOR_PLAN.md
**Status:** ✅ Implemented
**Date:** 2025-02
**Description:** Plan to refactor from single shape tool with presets to separate tool classes per shape (RectangleTool, OvalTool, etc.).

**Key Outcomes:**
- Each shape is now its own tool class
- `BaseShapeTool` provides shared drag-to-create logic
- `ShapeObject` stores `svgPath` and `toolId` (no preset enum)
- Icons and shortcuts moved to application layer
- `ToolMetadata` simplified (removed UI concerns)

## Current Documentation

For up-to-date documentation, see:
- **[../AnotarCanvas-API.md](../AnotarCanvas-API.md)** - Framework API reference
- **[../adding-a-tool.md](../adding-a-tool.md)** - Tool development guide
- **[../../ARCHITECTURE.md](../../ARCHITECTURE.md)** - System architecture
- **[../../CLAUDE.md](../../CLAUDE.md)** - Quick reference for AI assistants
- **[../../README.md](../../README.md)** - Project overview
