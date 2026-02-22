//
//  AnnotaApp.swift
//  Annota
//
//  Created by Flex on 12/11/25.
//

import SwiftUI

@main
struct AnnotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
        }
        .commands {
            CanvasFileCommands()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app appearance to light
        NSApp.appearance = NSAppearance(named: .aqua)
    }
}
