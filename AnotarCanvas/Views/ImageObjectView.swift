//
//  ImageObjectView.swift
//  texttool
//

import SwiftUI
import AppKit

struct ImageObjectView: View {
    let object: ImageObject
    var isSelected: Bool = false
    @ObservedObject var viewModel: CanvasViewModel

    var body: some View {
        Group {
            if let nsImage = object.nsImage {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: object.size.width, height: object.size.height)
            } else {
                // Fallback placeholder when image data is invalid
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: object.size.width, height: object.size.height)
                    Image(systemName: "photo")
                        .font(.system(size: min(object.size.width, object.size.height) * 0.3))
                        .foregroundColor(.gray)
                }
            }
        }
        .rotationEffect(.radians(object.rotation))
        .position(
            x: object.position.x + object.size.width / 2,
            y: object.position.y + object.size.height / 2
        )
    }
}
