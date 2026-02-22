//
//  AnnotaApp.swift
//  Annota
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

@main
struct AnnotaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CanvasFileCommands()
        }
    }
}
