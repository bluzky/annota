//
//  CanvasExportView.swift
//  texttool
//
//  A headless SwiftUI view used exclusively for off-screen rendering during export.
//  Renders all canvas objects without grid, selection UI, or interactive elements.
//

import SwiftUI

struct CanvasExportView: View {
    let objects: [AnyCanvasObject]
    let viewport: ViewportState

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.white

            ZStack(alignment: .topLeading) {
                ForEach(objects) { obj in
                    CanvasObjectExportView(object: obj)
                }
            }
            .scaleEffect(viewport.scale, anchor: .topLeading)
            .offset(x: viewport.offset.x, y: viewport.offset.y)
        }
    }
}

/// Dispatches export rendering for any AnyCanvasObject.
private struct CanvasObjectExportView: View {
    let object: AnyCanvasObject

    var body: some View {
        if let imageObj = object.asImageObject {
            ExportImageObjectView(object: imageObj)
        } else if let shapeObj = object.asShapeObject {
            ExportShapeObjectView(object: shapeObj)
        } else if let textObj = object.asTextObject {
            ExportTextObjectView(object: textObj)
        }
    }
}

// MARK: - Image

private struct ExportImageObjectView: View {
    let object: ImageObject

    var body: some View {
        if let nsImage = NSImage(data: object.imageData) {
            Image(nsImage: nsImage)
                .resizable()
                .frame(width: object.size.width, height: object.size.height)
                .rotationEffect(.radians(object.rotation))
                .position(
                    x: object.position.x + object.size.width / 2,
                    y: object.position.y + object.size.height / 2
                )
        }
    }
}

// MARK: - Shape

private struct ExportShapeObjectView: View {
    let object: ShapeObject

    private var effectiveHeight: CGFloat {
        if object.autoResizeHeight && !object.text.isEmpty {
            let attributes: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 16)
            ]
            let attributed = NSAttributedString(string: object.text, attributes: attributes)
            let bounds = attributed.boundingRect(
                with: NSSize(width: object.size.width - 32, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            )
            return max(object.size.height, ceil(bounds.height) + 24)
        }
        return object.size.height
    }

    var body: some View {
        ZStack {
            let height = effectiveHeight
            let shapeRect = CGRect(origin: .zero, size: CGSize(width: object.size.width, height: height))
            object.preset.path(in: shapeRect)
                .fill(object.fillColor.opacity(object.fillOpacity))
                .frame(width: object.size.width, height: height)
            object.preset.path(in: shapeRect)
                .stroke(object.strokeColor, lineWidth: object.strokeWidth)
                .frame(width: object.size.width, height: height)

            if !object.text.isEmpty {
                Text(object.text)
                    .font(.system(size: 16))
                    .foregroundColor(.black)
                    .multilineTextAlignment(.center)
                    .lineLimit(nil)
                    .frame(width: object.size.width - 16)
                    .padding(8)
            }
        }
        .rotationEffect(.radians(object.rotation))
        .position(
            x: object.position.x + object.size.width / 2,
            y: object.position.y + effectiveHeight / 2
        )
    }
}

// MARK: - Text

private struct ExportTextObjectView: View {
    let object: TextObject

    var body: some View {
        Text(object.text.isEmpty ? "" : object.text)
            .font(.system(size: object.fontSize))
            .foregroundColor(object.color)
            .fixedSize()
            .padding(4)
            .rotationEffect(.radians(object.rotation))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .offset(x: object.position.x, y: object.position.y)
    }
}
