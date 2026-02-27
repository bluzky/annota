//
//  PencilObjectView.swift
//  AnotarCanvas
//

import SwiftUI

struct PencilObjectView: View {
    let object: PencilObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        let bbox = object.boundingBox()
        let localOrigin = object.localOrigin
        // Bounding box in canvas coords, without the stroke-width padding
        let contentSize = object.size

        ZStack {
            // Render path in local coordinates (origin at bounding box top-left)
            object.localSmoothPath()
                .stroke(
                    object.strokeColor,
                    style: object.swiftUIStrokeStyle
                )
                .frame(width: contentSize.width, height: contentSize.height)

            // Selection bounding box overlay (in local space)
            if isSelected {
                Rectangle()
                    .stroke(Color.accentColor, lineWidth: 1)
                    .frame(width: bbox.width, height: bbox.height)
            }
        }
        // Rotate around the content center
        .rotationEffect(.radians(object.rotation))
        // Position at the center of the bounding box in canvas coordinates
        .position(
            x: localOrigin.x + contentSize.width / 2,
            y: localOrigin.y + contentSize.height / 2
        )
    }
}

// MARK: - Export View

struct ExportPencilObjectView: View {
    let object: PencilObject

    var body: some View {
        let contentSize = object.size
        object.localSmoothPath()
            .stroke(
                object.strokeColor,
                style: object.swiftUIStrokeStyle
            )
            .frame(width: contentSize.width, height: contentSize.height)
            .rotationEffect(.radians(object.rotation))
            .position(
                x: object.localOrigin.x + contentSize.width / 2,
                y: object.localOrigin.y + contentSize.height / 2
            )
    }
}
