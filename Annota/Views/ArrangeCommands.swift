//
//  ArrangeCommands.swift
//  Annota
//
//  Adds an "Arrange" top-level menu with alignment, distribution, and z-order commands.
//

import SwiftUI
import AnotarCanvas

struct ArrangeCommands: Commands {
    @FocusedObject private var focusedViewModel: CanvasViewModel?

    private var viewModel: CanvasViewModel? {
        focusedViewModel ?? AppState.shared.canvasViewModel
    }

    private var selectedCount: Int {
        viewModel?.selectionState.selectedIds.count ?? 0
    }

    private var canAlign: Bool { selectedCount >= 2 }
    private var canDistribute: Bool { selectedCount >= 3 }
    private var canArrange: Bool { selectedCount >= 1 }

    var body: some Commands {
        CommandMenu("Arrange") {
            // Alignment section
            Section {
                Button {
                    viewModel?.alignSelected(.left)
                } label: {
                    Label("Align Left", systemImage: "align.horizontal.left")
                }
                .disabled(!canAlign)

                Button {
                    viewModel?.alignSelected(.right)
                } label: {
                    Label("Align Right", systemImage: "align.horizontal.right")
                }
                .disabled(!canAlign)

                Button {
                    viewModel?.alignSelected(.top)
                } label: {
                    Label("Align Top", systemImage: "align.vertical.top")
                }
                .disabled(!canAlign)

                Button {
                    viewModel?.alignSelected(.bottom)
                } label: {
                    Label("Align Bottom", systemImage: "align.vertical.bottom")
                }
                .disabled(!canAlign)

                Button {
                    viewModel?.alignSelected(.centerHorizontal)
                } label: {
                    Label("Align Centers Horizontally", systemImage: "align.horizontal.center")
                }
                .disabled(!canAlign)

                Button {
                    viewModel?.alignSelected(.centerVertical)
                } label: {
                    Label("Align Centers Vertically", systemImage: "align.vertical.center")
                }
                .disabled(!canAlign)
            }

            Divider()

            // Distribution section
            Section {
                Button {
                    viewModel?.distributeSelected(.horizontal)
                } label: {
                    Label("Distribute Horizontally", systemImage: "distribute.horizontal.center")
                }
                .disabled(!canDistribute)

                Button {
                    viewModel?.distributeSelected(.vertical)
                } label: {
                    Label("Distribute Vertically", systemImage: "distribute.vertical.center")
                }
                .disabled(!canDistribute)
            }

            Divider()

            // Z-order section
            Section {
                Button {
                    viewModel?.bringToFront()
                } label: {
                    Label("Bring to Front", systemImage: "square.3.layers.3d.top.filled")
                }
                .keyboardShortcut("]", modifiers: [.command, .shift])
                .disabled(!canArrange)

                Button {
                    viewModel?.bringForward()
                } label: {
                    Label("Bring Forward", systemImage: "square.2.layers.3d.top.filled")
                }
                .keyboardShortcut("]", modifiers: [.command])
                .disabled(!canArrange)

                Button {
                    viewModel?.sendBackward()
                } label: {
                    Label("Send Backward", systemImage: "square.2.layers.3d.bottom.filled")
                }
                .keyboardShortcut("[", modifiers: [.command])
                .disabled(!canArrange)

                Button {
                    viewModel?.sendToBack()
                } label: {
                    Label("Send to Back", systemImage: "square.3.layers.3d.bottom.filled")
                }
                .keyboardShortcut("[", modifiers: [.command, .shift])
                .disabled(!canArrange)
            }
        }
    }
}
