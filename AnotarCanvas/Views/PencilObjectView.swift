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
        let rawSize = object.size
        // Ensure minimum frame size so perfectly straight lines remain visible
        let minDim = object.strokeWidth
        let contentSize = CGSize(
            width: max(rawSize.width, minDim),
            height: max(rawSize.height, minDim)
        )

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
        // Position based on actual bounds center (not expanded contentSize)
        // to avoid shifting perfectly horizontal/vertical strokes
        .position(
            x: localOrigin.x + rawSize.width / 2,
            y: localOrigin.y + rawSize.height / 2
        )
    }
}

// MARK: - Export View

struct ExportPencilObjectView: View {
    let object: PencilObject

    var body: some View {
        let rawSize = object.size
        let minDim = object.strokeWidth
        let contentSize = CGSize(
            width: max(rawSize.width, minDim),
            height: max(rawSize.height, minDim)
        )
        object.localSmoothPath()
            .stroke(
                object.strokeColor,
                style: object.swiftUIStrokeStyle
            )
            .frame(width: contentSize.width, height: contentSize.height)
            .rotationEffect(.radians(object.rotation))
            .position(
                x: object.localOrigin.x + rawSize.width / 2,
                y: object.localOrigin.y + rawSize.height / 2
            )
    }
}
