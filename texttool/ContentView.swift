//
//  ContentView.swift
//  texttool
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = CanvasViewModel()

    var body: some View {
        VStack(spacing: 0) {
            ToolbarView(viewModel: viewModel, toolRegistry: ToolRegistry.shared)
            CanvasView(viewModel: viewModel)
        }
        .frame(minWidth: 800, minHeight: 600)
        .focusedSceneObject(viewModel)
        .onAppear {
            AppState.shared.canvasViewModel = viewModel
        }
    }
}

#Preview {
    ContentView()
}
