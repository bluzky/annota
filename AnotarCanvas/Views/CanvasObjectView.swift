//
//  CanvasObjectView.swift
//  AnotarCanvas
//

import SwiftUI

/// Dispatches rendering for any AnyCanvasObject to the correct view type.
/// Adding support for a new object type only requires adding a case here.
struct CanvasObjectView: View {
    let object: AnyCanvasObject
    let isSelected: Bool
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        ObjectViewRegistry.view(for: object, isSelected: isSelected, viewModel: viewModel)
    }
}
