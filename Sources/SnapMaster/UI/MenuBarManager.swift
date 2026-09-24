import Foundation
import AppKit

final class MenuBarManager: NSObject {
    static let shared = MenuBarManager()
    
    private var statusItem: NSStatusItem?
    private var recordMenuItem: NSMenuItem?
    
    var onCaptureArea: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?
    var onCaptureWindow: (() -> Void)?
    var onToggleRecord: (() -> Void)?
    var onCaptureText: (() -> Void)?
    var onScanQR: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    
    private override init() {
        super.init()
    }
    
    func setupMenuBar() {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.statusItem = statusItem
        
        if let button = statusItem.button {
            // Sử dụng SF Symbol camera.viewfinder cho Menu Bar
            if let image = NSImage(systemSymbolName: "camera.viewfinder", accessibilityDescription: "SnapMaster") {
                image.isTemplate = true
                button.image = image
            } else {
                button.title = "📸"
            }
        }
        
        rebuildMenu()
    }
    
    func rebuildMenu(isRecording: Bool = false) {
        let menu = NSMenu()
        
        // Nhóm Chụp ảnh
        let captureAreaItem = NSMenuItem(title: L10n.tr(.menuCaptureArea), action: #selector(captureAreaClicked), keyEquivalent: "1")
        captureAreaItem.keyEquivalentModifierMask = [.command, .shift]
        captureAreaItem.target = self
        captureAreaItem.image = NSImage(systemSymbolName: "crop", accessibilityDescription: nil)
        menu.addItem(captureAreaItem)
        
        let captureFullItem = NSMenuItem(title: L10n.tr(.menuCaptureFull), action: #selector(captureFullClicked), keyEquivalent: "2")
        captureFullItem.keyEquivalentModifierMask = [.command, .shift]
        captureFullItem.target = self
        captureFullItem.image = NSImage(systemSymbolName: "macbook.and.iphone", accessibilityDescription: nil)
        menu.addItem(captureFullItem)
        
        let captureWindowItem = NSMenuItem(title: L10n.tr(.menuCaptureWindow), action: #selector(captureWindowClicked), keyEquivalent: "3")
        captureWindowItem.keyEquivalentModifierMask = [.command, .shift]
        captureWindowItem.target = self
        captureWindowItem.image = NSImage(systemSymbolName: "uiwindow.split.2x1", accessibilityDescription: nil)
        menu.addItem(captureWindowItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Nhóm Trích xuất Text & Quét Mã QR
        let captureTextItem = NSMenuItem(title: L10n.tr(.menuCaptureText), action: #selector(captureTextClicked), keyEquivalent: "5")
        captureTextItem.keyEquivalentModifierMask = [.command, .shift]
        captureTextItem.target = self
        captureTextItem.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: nil)
        menu.addItem(captureTextItem)
        
        let scanQRItem = NSMenuItem(title: L10n.tr(.menuScanQR), action: #selector(scanQRClicked), keyEquivalent: "6")
        scanQRItem.keyEquivalentModifierMask = [.command, .shift]
        scanQRItem.target = self
        scanQRItem.image = NSImage(systemSymbolName: "qrcode.viewfinder", accessibilityDescription: nil)
        menu.addItem(scanQRItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Nhóm Quay video
        let recordTitle = isRecording ? L10n.tr(.menuStopRecord) : L10n.tr(.menuRecord)
        let recordItem = NSMenuItem(title: recordTitle, action: #selector(recordClicked), keyEquivalent: "4")
        recordItem.keyEquivalentModifierMask = [.command, .shift]
        recordItem.target = self
        recordItem.image = NSImage(systemSymbolName: isRecording ? "stop.circle.fill" : "record.circle", accessibilityDescription: nil)
        self.recordMenuItem = recordItem
        menu.addItem(recordItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Lịch sử hoạt động
        let historyItem = NSMenuItem(title: L10n.tr(.menuHistory), action: #selector(historyClicked), keyEquivalent: "h")
        historyItem.keyEquivalentModifierMask = [.command, .shift]
        historyItem.target = self
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        menu.addItem(historyItem)
        
        // Nhóm Tiện ích & Cài đặt
        let openFolderItem = NSMenuItem(title: L10n.tr(.menuOpenFolder), action: #selector(openFolderClicked), keyEquivalent: "o")
        openFolderItem.target = self
        openFolderItem.image = NSImage(systemSymbolName: "folder", accessibilityDescription: nil)
        menu.addItem(openFolderItem)
        
        let settingsItem = NSMenuItem(title: L10n.tr(.menuSettings), action: #selector(settingsClicked), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Thoát ứng dụng
        let quitItem = NSMenuItem(title: L10n.tr(.menuQuit), action: #selector(quitClicked), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    // MARK: - Actions
    @objc private func captureAreaClicked() {
        onCaptureArea?()
    }
    
    @objc private func captureFullClicked() {
        onCaptureFullScreen?()
    }
    
    @objc private func captureWindowClicked() {
        onCaptureWindow?()
    }
    
    @objc private func recordClicked() {
        onToggleRecord?()
    }
    
    @objc private func captureTextClicked() {
        onCaptureText?()
    }
    
    @objc private func scanQRClicked() {
        onScanQR?()
    }
    
    @objc private func historyClicked() {
        onOpenHistory?()
    }
    
    @objc private func openFolderClicked() {
        let dir = PreferencesManager.shared.saveDirectory
        NSWorkspace.shared.open(dir)
    }
    
    @objc private func settingsClicked() {
        SettingsWindowController.shared.showWindow()
    }
    
    @objc private func quitClicked() {
        NSApplication.shared.terminate(nil)
    }
}
