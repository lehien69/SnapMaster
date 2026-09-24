import Foundation
import AppKit
import SwiftUI

@MainActor
final class HistoryWindowController: NSWindowController {
    static let shared = HistoryWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 720, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Lịch sử hoạt động - SnapMaster"
        window.center()
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 600, height: 400)
        
        super.init(window: window)
        
        let hosting = NSHostingView(rootView: HistoryView())
        window.contentView = hosting
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showWindow() {
        window?.title = "\(L10n.tr(.historyTitle)) - SnapMaster"
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
