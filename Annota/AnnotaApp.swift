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
    @StateObject private var settings = SettingsManager(
        defaults: AnnotaSettings(),
        storage: TOMLSettingsStorage(appName: "Annota")
    )

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(settings)
        }
        .commands {
            CanvasFileCommands()
        }

        Settings {
            SettingsWindowView()
                .environmentObject(settings)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set app appearance to light
        NSApp.appearance = NSAppearance(named: .aqua)
    }
}
