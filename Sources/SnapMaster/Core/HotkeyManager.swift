import Foundation
import AppKit
import Carbon

// MARK: - Keyboard Shortcut Model
struct KeyboardShortcut: Codable, Equatable, Hashable {
    var keyCode: UInt32
    var modifiers: UInt32 // Carbon modifier mask (cmdKey, shiftKey, optionKey, controlKey)
    
    var displayString: String {
        var parts: [String] = []
        if (modifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
        if (modifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
        if (modifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
        if (modifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }
        
        parts.append(Self.keyName(for: keyCode))
        return parts.joined(separator: " ")
    }
    
    var keyEquivalent: String {
        Self.keyEquivalentCharacter(for: keyCode)
    }
    
    var modifierFlags: NSEvent.ModifierFlags {
        var flags: NSEvent.ModifierFlags = []
        if (modifiers & UInt32(cmdKey)) != 0 { flags.insert(.command) }
        if (modifiers & UInt32(shiftKey)) != 0 { flags.insert(.shift) }
        if (modifiers & UInt32(optionKey)) != 0 { flags.insert(.option) }
        if (modifiers & UInt32(controlKey)) != 0 { flags.insert(.control) }
        return flags
    }
    
    static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        return mods
    }
    
    static func keyName(for keyCode: UInt32) -> String {
        switch Int(keyCode) {
        case kVK_ANSI_A: return "A"
        case kVK_ANSI_B: return "B"
        case kVK_ANSI_C: return "C"
        case kVK_ANSI_D: return "D"
        case kVK_ANSI_E: return "E"
        case kVK_ANSI_F: return "F"
        case kVK_ANSI_G: return "G"
        case kVK_ANSI_H: return "H"
        case kVK_ANSI_I: return "I"
        case kVK_ANSI_J: return "J"
        case kVK_ANSI_K: return "K"
        case kVK_ANSI_L: return "L"
        case kVK_ANSI_M: return "M"
        case kVK_ANSI_N: return "N"
        case kVK_ANSI_O: return "O"
        case kVK_ANSI_P: return "P"
        case kVK_ANSI_Q: return "Q"
        case kVK_ANSI_R: return "R"
        case kVK_ANSI_S: return "S"
        case kVK_ANSI_T: return "T"
        case kVK_ANSI_U: return "U"
        case kVK_ANSI_V: return "V"
        case kVK_ANSI_W: return "W"
        case kVK_ANSI_X: return "X"
        case kVK_ANSI_Y: return "Y"
        case kVK_ANSI_Z: return "Z"
        case kVK_ANSI_0: return "0"
        case kVK_ANSI_1: return "1"
        case kVK_ANSI_2: return "2"
        case kVK_ANSI_3: return "3"
        case kVK_ANSI_4: return "4"
        case kVK_ANSI_5: return "5"
        case kVK_ANSI_6: return "6"
        case kVK_ANSI_7: return "7"
        case kVK_ANSI_8: return "8"
        case kVK_ANSI_9: return "9"
        case kVK_Space: return "Space"
        case kVK_Return: return "↩"
        case kVK_Tab: return "⇥"
        case kVK_F1: return "F1"
        case kVK_F2: return "F2"
        case kVK_F3: return "F3"
        case kVK_F4: return "F4"
        case kVK_F5: return "F5"
        case kVK_F6: return "F6"
        case kVK_F7: return "F7"
        case kVK_F8: return "F8"
        case kVK_F9: return "F9"
        case kVK_F10: return "F10"
        case kVK_F11: return "F11"
        case kVK_F12: return "F12"
        case kVK_ANSI_Minus: return "-"
        case kVK_ANSI_Equal: return "="
        case kVK_ANSI_LeftBracket: return "["
        case kVK_ANSI_RightBracket: return "]"
        case kVK_ANSI_Quote: return "'"
        case kVK_ANSI_Semicolon: return ";"
        case kVK_ANSI_Backslash: return "\\"
        case kVK_ANSI_Comma: return ","
        case kVK_ANSI_Slash: return "/"
        case kVK_ANSI_Period: return "."
        case kVK_ANSI_Grave: return "`"
        default: return "Key(\(keyCode))"
        }
    }
    
    static func keyEquivalentCharacter(for keyCode: UInt32) -> String {
        let name = keyName(for: keyCode)
        if name.count == 1 {
            return name.lowercased()
        }
        return ""
    }
    
    // Default shortcuts
    static let defaultCaptureArea = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_1), modifiers: UInt32(cmdKey | shiftKey))
    static let defaultCaptureFullScreen = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_2), modifiers: UInt32(cmdKey | shiftKey))
    static let defaultCaptureWindow = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_3), modifiers: UInt32(cmdKey | shiftKey))
    static let defaultRecordScreen = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_4), modifiers: UInt32(cmdKey | shiftKey))
    static let defaultCaptureText = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_5), modifiers: UInt32(cmdKey | shiftKey))
    static let defaultScanQR = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_6), modifiers: UInt32(cmdKey | shiftKey))
    static let defaultOpenHistory = KeyboardShortcut(keyCode: UInt32(kVK_ANSI_H), modifiers: UInt32(cmdKey | shiftKey))
    
    static func defaultShortcut(for action: HotKeyAction) -> KeyboardShortcut {
        switch action {
        case .captureArea: return defaultCaptureArea
        case .captureFullScreen: return defaultCaptureFullScreen
        case .captureWindow: return defaultCaptureWindow
        case .recordScreen: return defaultRecordScreen
        case .captureText: return defaultCaptureText
        case .scanQR: return defaultScanQR
        case .openHistory: return defaultOpenHistory
        }
    }
}

// MARK: - HotKey Action Enum
enum HotKeyAction: UInt32, CaseIterable, Identifiable, Codable {
    case captureArea = 1
    case captureFullScreen = 2
    case captureWindow = 3
    case recordScreen = 4
    case captureText = 5
    case scanQR = 6
    case openHistory = 7
    
    var id: UInt32 { rawValue }
    
    var preferenceKey: String {
        switch self {
        case .captureArea: return "shortcut_capture_area"
        case .captureFullScreen: return "shortcut_capture_full_screen"
        case .captureWindow: return "shortcut_capture_window"
        case .recordScreen: return "shortcut_record_screen"
        case .captureText: return "shortcut_capture_text"
        case .scanQR: return "shortcut_scan_qr"
        case .openHistory: return "shortcut_open_history"
        }
    }
    
    var displayName: String {
        switch self {
        case .captureArea: return L10n.tr(.shortcutArea)
        case .captureFullScreen: return L10n.tr(.shortcutFull)
        case .captureWindow: return L10n.tr(.shortcutWindow)
        case .recordScreen: return L10n.tr(.shortcutRecord)
        case .captureText: return L10n.tr(.shortcutText)
        case .scanQR: return L10n.tr(.shortcutQR)
        case .openHistory: return L10n.tr(.shortcutHistory)
        }
    }
}

// MARK: - Global Hotkey Manager
final class HotkeyManager {
    static let shared = HotkeyManager()
    
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var isHandlerInstalled = false
    
    var onCaptureArea: (() -> Void)?
    var onCaptureFullScreen: (() -> Void)?
    var onCaptureWindow: (() -> Void)?
    var onRecordScreen: (() -> Void)?
    var onCaptureText: (() -> Void)?
    var onScanQR: (() -> Void)?
    var onOpenHistory: (() -> Void)?
    
    private init() {}
    
    func setupDefaultHotkeys() {
        setupHotkeys()
    }
    
    func setupHotkeys() {
        if !isHandlerInstalled {
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
            isHandlerInstalled = true
        }
        
        registerAllFromPreferences()
    }
    
    func registerAllFromPreferences() {
        for action in HotKeyAction.allCases {
            let shortcut = PreferencesManager.shared.shortcut(for: action)
            register(action: action, shortcut: shortcut)
        }
    }
    
    func register(action: HotKeyAction, shortcut: KeyboardShortcut) {
        register(action: action, keyCode: shortcut.keyCode, modifiers: shortcut.modifiers)
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
    
    func unregister(action: HotKeyAction) {
        let actionID = action.rawValue
        if let existing = hotKeyRefs[actionID] {
            UnregisterEventHotKey(existing)
            hotKeyRefs.removeValue(forKey: actionID)
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
