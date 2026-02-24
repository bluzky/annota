//
//  FileWatcher.swift
//  Annota
//
//  File monitoring using DispatchSource
//

import Foundation
import Dispatch

@MainActor
final class FileWatcher {
    private var dispatchSource: DispatchSourceFileSystemObject?
    private let fileURL: URL
    private let callback: () -> Void
    private var fileDescriptor: Int32 = -1

    var isSuppressed: Bool = false

    init(fileURL: URL, callback: @escaping () -> Void) {
        self.fileURL = fileURL
        self.callback = callback
    }

    func start() {
        stop()

        // Open the file for monitoring
        fileDescriptor = open(fileURL.path, O_EVTONLY)
        guard fileDescriptor >= 0 else { return }

        let fd = fileDescriptor
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .extend],
            queue: DispatchQueue.main
        )

        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            Task { @MainActor in
                guard !self.isSuppressed else { return }
                self.callback()
            }
        }

        // Cancel handler is the sole owner of closing the fd
        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        dispatchSource = source
    }

    func stop() {
        // Cancelling the source triggers setCancelHandler which closes the fd
        dispatchSource?.cancel()
        dispatchSource = nil
        fileDescriptor = -1
    }

    deinit {
        dispatchSource?.cancel()
    }
}
