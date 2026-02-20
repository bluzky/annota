//
//  CanvasObjectView.swift
//  texttool
//

import SwiftUI

/// Dispatches rendering for any AnyCanvasObject to the correct view type.
/// Adding support for a new object type only requires adding a case here.
struct CanvasObjectView: View {
    let object: AnyCanvasObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    @ViewBuilder
    var body: some View {
        if let imageObj = object.asImageObject {
            ImageObjectView(
                object: imageObj,
                isSelected: isSelected,
                viewModel: viewModel
            )
        } else if let shapeObj = object.asShapeObject {
            ShapeObjectView(
                object: shapeObj,
                isSelected: isSelected,
                viewModel: viewModel
            )
        } else if let lineObj = object.asLineObject {
            LineObjectView(
                object: lineObj,
                isSelected: isSelected,
                viewModel: viewModel
            )
        } else if let textObj = object.asTextObject {
            TextObjectView(
                object: textObj,
                viewModel: viewModel,
                isSelected: isSelected
            )
        }
    }
}
