import Foundation
import AppKit
import SwiftUI

final class EditorWindowController: NSWindowController {
    convenience init(image: NSImage) {
        let viewModel = EditorViewModel(image: image)
        
        let window = NSWindow(
            contentRect: NSRect(x: 100, y: 100, width: 900, height: 650),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        
        window.title = "SnapMaster Editor"
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.center()
        
        self.init(window: window)
        
        let hostingView = NSHostingView(rootView: EditorView(viewModel: viewModel, onClose: { [weak self] in
            self?.close()
        }))
        
        window.contentView = hostingView
    }
}
