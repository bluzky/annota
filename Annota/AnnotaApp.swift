//
//  AnnotaApp.swift
//  Annota
//
//  Created by Flex on 12/11/25.
//

import SwiftUI
import AnotarCanvas

@main
struct AnnotaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = SettingsManager(
        defaults: AnnotaSettings(),
        storage: TOMLSettingsStorage(appName: "Annota")
    )

    var body: some Scene {
        Window("Annota", id: "main") {
            ContentView()
                .preferredColorScheme(.light)
                .environmentObject(settings)
        }
        .commands {
            CommandGroup(replacing: .newItem) { }
            EditCommands()
            CanvasFileCommands()
            ArrangeCommands()
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

        // Register built-in tools
        registerBuiltInTools()
    }

    @MainActor
    private func registerBuiltInTools() {
        let registry = ToolRegistry.shared

        // Tool-only (no produced object) — registered directly
        registry.register(SelectTool())
        registry.register(HandTool())
        registry.register(ArrowTool())

        // Shape tools — each shape shares ShapeObject registrations
        // Only the first shape registration reaches the ObjectViewRegistry/CodableObjectRegistry
        // calls; subsequent ones are no-ops for those registries (same discriminator).
        registry.register(RectangleTool().manifest())
        registry.register(OvalTool().manifest())
        registry.register(TriangleTool().manifest())
        registry.register(DiamondTool().manifest())
        registry.register(StarTool().manifest())

        // Line, pencil, and text tools carry their own object registrations
        registry.register(LineTool.manifest)
        registry.register(PencilTool.manifest)
        registry.register(TextTool.manifest)

        // ImageObject has no toolbar tool — register views and codable support directly.
        registry.register(ImageObject.objectManifest)
    }
}
