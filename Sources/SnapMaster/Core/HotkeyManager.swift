import Foundation
import AppKit
import Carbon

enum HotKeyAction: UInt32 {
    case captureArea = 1
    case captureFullScreen = 2
    case captureWindow = 3
    case recordScreen = 4
    case captureText = 5
    case scanQR = 6
    case openHistory = 7
}

final class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    
    var onCaptureArea: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?
    var onCaptureWindow: (() -> Void)?
    var onRecordScreen: (() -> Void)?
    var onCaptureText: (() -> Void)?
    var onScanQR: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    
    private init() {}
    
    func setupDefaultHotkeys() {
        // Cài đặt handler lắng nghe sự kiện Carbon HotKey toàn hệ thống
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        
        let handler: EventHandlerUPP = { _, event, _ in
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            
            if status == noErr {
                DispatchQueue.main.async {
                    HotkeyManager.shared.triggerAction(for: hotKeyID.id)
                }
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, nil)
        
        // Đăng ký các phím tắt mặc định:
        // Cmd + Shift + 1 -> Chụp vùng (Area)
        // Cmd + Shift + 2 -> Chụp toàn màn hình (Full Screen)
        // Cmd + Shift + 3 -> Chụp cửa sổ (Window)
        // Cmd + Shift + 4 -> Bật/Tắt quay màn hình (Screen Record)
        
        let cmdShiftModifiers = UInt32(cmdKey | shiftKey)
        
        register(action: .captureArea, keyCode: UInt32(kVK_ANSI_1), modifiers: cmdShiftModifiers)
        register(action: .captureFullScreen, keyCode: UInt32(kVK_ANSI_2), modifiers: cmdShiftModifiers)
        register(action: .captureWindow, keyCode: UInt32(kVK_ANSI_3), modifiers: cmdShiftModifiers)
        register(action: .recordScreen, keyCode: UInt32(kVK_ANSI_4), modifiers: cmdShiftModifiers)
        register(action: .captureText, keyCode: UInt32(kVK_ANSI_5), modifiers: cmdShiftModifiers)
        register(action: .scanQR, keyCode: UInt32(kVK_ANSI_6), modifiers: cmdShiftModifiers)
        register(action: .openHistory, keyCode: UInt32(kVK_ANSI_H), modifiers: cmdShiftModifiers)
    }
    
    func register(action: HotKeyAction, keyCode: UInt32, modifiers: UInt32) {
        let actionID = action.rawValue
        
        // Hủy đăng ký cũ nếu có
        if let existing = hotKeyRefs[actionID] {
            UnregisterEventHotKey(existing)
            hotKeyRefs.removeValue(forKey: actionID)
        }
        
        let signature = OSType(0x534E4150) // 'SNAP'
        let hotKeyID = EventHotKeyID(signature: signature, id: actionID)
        var hotKeyRef: EventHotKeyRef?
        
        let err = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        
        if err == noErr, let ref = hotKeyRef {
            hotKeyRefs[actionID] = ref
        }
    }
    
    private func triggerAction(for id: UInt32) {
        guard let action = HotKeyAction(rawValue: id) else { return }
        
        switch action {
        case .captureArea:
            onCaptureArea?()
        case .captureFullScreen:
            onCaptureFullScreen?()
        case .captureWindow:
            onCaptureWindow?()
        case .recordScreen:
            onRecordScreen?()
        case .captureText:
            onCaptureText?()
        case .scanQR:
            onScanQR?()
        case .openHistory:
            onOpenHistory?()
        }
    }
    
    deinit {
        for (_, ref) in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
    }
}
