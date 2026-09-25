import Foundation
import AppKit
import SwiftUI
import Carbon

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 560, height: 600),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr(.settingsTitle)
        window.center()
        window.isReleasedWhenClosed = false
        super.init(window: window)
        
        let hosting = NSHostingView(rootView: SettingsView())
        window.contentView = hosting
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func showWindow() {
        window?.title = L10n.tr(.settingsTitle)
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

final class SettingsViewState: ObservableObject {
    @Published var selectedTab: Int = 0
    @Published var recordingAction: HotKeyAction? = nil
    private var eventMonitor: Any? = nil
    
    func startRecording(for action: HotKeyAction, prefs: PreferencesManager) {
        stopRecording()
        recordingAction = action
        
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [weak self] event in
            guard let self = self else { return event }
            
            // Nếu bấm ESC -> huỷ bỏ
            if event.keyCode == UInt16(kVK_Escape) {
                DispatchQueue.main.async {
                    self.stopRecording()
                }
                return nil
            }
            
            let carbonMods = KeyboardShortcut.carbonModifiers(from: event.modifierFlags)
            // Yêu cầu có ít nhất 1 phím bổ trợ (⌘, ⌥, ⌃, ⇧)
            if carbonMods > 0 {
                let newShortcut = KeyboardShortcut(keyCode: UInt32(event.keyCode), modifiers: carbonMods)
                DispatchQueue.main.async {
                    prefs.setShortcut(newShortcut, for: action)
                    self.stopRecording()
                }
                return nil
            }
            
            return nil
        }
    }
    
    func stopRecording() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        recordingAction = nil
    }
    
    deinit {
        stopRecording()
    }
}

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @StateObject var state = SettingsViewState()
    
    var body: some View {
        TabView(selection: $state.selectedTab) {
            generalSettings
                .tabItem {
                    Label(L10n.tr(.tabGeneral), systemImage: "gearshape")
                }
                .tag(0)
            
            shortcutSettings
                .tabItem {
                    Label(L10n.tr(.tabShortcuts), systemImage: "keyboard")
                }
                .tag(1)
            
            personalizationSettings
                .tabItem {
                    Label(L10n.tr(.tabPersonalization), systemImage: "sparkles")
                }
                .tag(2)
        }
        .frame(width: 540, height: 600)
        .padding(20)
        .preferredColorScheme(prefs.appTheme.colorScheme)
        .onChange(of: state.selectedTab) { _ in
            state.stopRecording()
        }
        .onDisappear {
            state.stopRecording()
        }
    }
    
    // MARK: - General Settings
    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Nhóm Giao diện & Ngôn ngữ
            GroupBox(label: Text(L10n.tr(.sectionAppearanceLanguage)).bold()) {
                VStack(alignment: .leading, spacing: 12) {
                    // Chọn Ngôn ngữ
                    HStack {
                        Label(L10n.tr(.labelLanguage), systemImage: "globe")
                            .frame(width: 140, alignment: .leading)
                        
                        Picker("", selection: $prefs.appLanguage) {
                            ForEach(AppLanguage.allCases) { lang in
                                Text(lang.displayName).tag(lang)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                    
                    // Chọn Theme
                    HStack {
                        Label(L10n.tr(.labelTheme), systemImage: "circle.righthalf.filled")
                            .frame(width: 140, alignment: .leading)
                        
                        Picker("", selection: $prefs.appTheme) {
                            ForEach(AppTheme.allCases) { theme in
                                Text(theme.displayName(language: prefs.appLanguage)).tag(theme)
                            }
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }
                }
                .padding(8)
            }
            
            // Thư mục lưu trữ
            GroupBox(label: Text(L10n.tr(.sectionSaveDirectory)).bold()) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(prefs.saveDirectory.path)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(1)
                            .truncationMode(.middle)
                        
                        Spacer()
                        
                        Button(L10n.tr(.buttonChooseDirectory)) {
                            chooseDirectory()
                        }
                    }
                    
                    Button(L10n.tr(.buttonOpenInFinder)) {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: prefs.saveDirectory.path)
                    }
                    .buttonStyle(LinkButtonStyle())
                    .font(.caption)
                }
                .padding(8)
            }
            
            // Tùy chọn chụp ảnh
            GroupBox(label: Text(L10n.tr(.sectionCaptureOptions)).bold()) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(L10n.tr(.toggleAutoCopy), isOn: $prefs.autoCopyToClipboard)
                    Toggle(L10n.tr(.toggleThumbnail), isOn: $prefs.showFloatingThumbnail)
                    Toggle(L10n.tr(.toggleSound), isOn: $prefs.playCaptureSound)
                    
                    HStack {
                        Text(L10n.tr(.labelThumbnailDuration))
                            .font(.caption)
                        Slider(value: $prefs.thumbnailDuration, in: 2...10, step: 1)
                        Text("\(Int(prefs.thumbnailDuration)) \(L10n.tr(.secondsSuffix))")
                            .font(.caption.monospacedDigit())
                            .frame(width: 50)
                    }
                }
                .padding(8)
            }
            
            // Cập nhật ứng dụng
            GroupBox(label: Text(L10n.tr(.sectionSoftwareUpdate)).bold()) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(L10n.tr(.toggleAutoCheckUpdates), isOn: $prefs.autoCheckUpdates)
                    
                    HStack {
                        Text(L10n.tr(.labelCurrentVersion(UpdateManager.shared.currentVersion)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Button(action: {
                            UpdateManager.shared.checkForUpdates(isUserInitiated: true)
                        }) {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text(L10n.tr(.buttonCheckUpdatesNow))
                            }
                        }
                    }
                }
                .padding(8)
            }
            
            Spacer()
        }
    }
    
    // MARK: - Shortcuts Settings
    private var shortcutSettings: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(L10n.tr(.shortcutsHeader))
                    .font(.headline)
                
                Spacer()
                
                Button(action: {
                    state.stopRecording()
                    prefs.resetShortcutsToDefault()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.counterclockwise")
                        Text(L10n.tr(.shortcutResetDefaults))
                    }
                    .font(.caption)
                }
            }
            
            Text(L10n.tr(.shortcutClickToChange))
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 6) {
                ForEach(HotKeyAction.allCases) { action in
                    ShortcutEditRow(
                        title: action.displayName,
                        shortcut: prefs.shortcut(for: action),
                        isRecording: state.recordingAction == action,
                        onToggleRecord: {
                            if state.recordingAction == action {
                                state.stopRecording()
                            } else {
                                state.startRecording(for: action, prefs: prefs)
                            }
                        }
                    )
                    
                    if action != HotKeyAction.allCases.last {
                        Divider()
                    }
                }
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
            if state.recordingAction != nil {
                HStack {
                    Image(systemName: "record.circle.fill")
                        .foregroundColor(.red)
                    Text(L10n.tr(.shortcutRecordPrompt))
                        .font(.caption)
                        .foregroundColor(.primary)
                    Spacer()
                    Button(action: {
                        state.stopRecording()
                    }) {
                        Text("ESC")
                            .font(.caption.monospaced().bold())
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                .padding(8)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                )
            }
            
            Text(L10n.tr(.shortcutsNote))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
    
    // MARK: - Personalization Settings
    private var personalizationSettings: some View {
        VStack(alignment: .leading, spacing: 16) {
            GroupBox(label: Text(L10n.tr(.sectionWatermark)).bold()) {
                VStack(alignment: .leading, spacing: 10) {
                    Toggle(L10n.tr(.toggleWatermark), isOn: $prefs.watermarkEnabled)
                    
                    if prefs.watermarkEnabled {
                        TextField(L10n.tr(.placeholderWatermark), text: $prefs.watermarkText)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                        
                        HStack {
                            Text(L10n.tr(.labelOpacity))
                                .font(.caption)
                            Slider(value: $prefs.watermarkOpacity, in: 0.1...1.0)
                            Text("\(Int(prefs.watermarkOpacity * 100))%")
                                .font(.caption.monospacedDigit())
                                .frame(width: 40)
                        }
                    }
                }
                .padding(8)
            }
            
            GroupBox(label: Text(L10n.tr(.sectionBeautify)).bold()) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.tr(.labelPadding))
                        Slider(value: $prefs.beautifyPadding, in: 16...80, step: 4)
                        Text("\(Int(prefs.beautifyPadding)) px")
                            .frame(width: 50)
                    }
                    
                    HStack {
                        Text(L10n.tr(.labelCornerRadius))
                        Slider(value: $prefs.beautifyCornerRadius, in: 0...32, step: 2)
                        Text("\(Int(prefs.beautifyCornerRadius)) px")
                            .frame(width: 50)
                    }
                }
                .padding(8)
            }
            
            Spacer()
        }
    }
    
    private func chooseDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        
        if panel.runModal() == .OK, let url = panel.url {
            prefs.saveDirectory = url
        }
    }
}

struct ShortcutEditRow: View {
    let title: String
    let shortcut: KeyboardShortcut
    let isRecording: Bool
    let onToggleRecord: () -> Void
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            
            Spacer()
            
            Button(action: onToggleRecord) {
                HStack(spacing: 6) {
                    if isRecording {
                        Image(systemName: "record.circle.fill")
                            .foregroundColor(.red)
                        Text(L10n.currentLanguage == .vietnamese ? "Bấm tổ hợp phím..." : "Press keys...")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.accentColor)
                    } else {
                        Text(shortcut.displayString)
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(isRecording ? Color.accentColor.opacity(0.15) : Color(nsColor: .windowBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isRecording ? Color.accentColor : Color.gray.opacity(0.3), lineWidth: isRecording ? 1.5 : 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
    }
}
