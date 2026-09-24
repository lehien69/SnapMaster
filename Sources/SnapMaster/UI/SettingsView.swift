import Foundation
import AppKit
import SwiftUI

final class SettingsWindowController: NSWindowController {
    static let shared = SettingsWindowController()
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 200, y: 200, width: 560, height: 490),
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
}

struct SettingsView: View {
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var state = SettingsViewState()
    
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
        .frame(width: 540, height: 560)
        .padding(20)
        .preferredColorScheme(prefs.appTheme.colorScheme)
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
        VStack(alignment: .leading, spacing: 16) {
            Text(L10n.tr(.shortcutsHeader))
                .font(.headline)
            
            VStack(spacing: 8) {
                ShortcutRow(title: L10n.tr(.shortcutArea), shortcut: "⌘ ⇧ 1")
                ShortcutRow(title: L10n.tr(.shortcutFull), shortcut: "⌘ ⇧ 2")
                ShortcutRow(title: L10n.tr(.shortcutWindow), shortcut: "⌘ ⇧ 3")
                ShortcutRow(title: L10n.tr(.shortcutRecord), shortcut: "⌘ ⇧ 4")
                ShortcutRow(title: L10n.tr(.shortcutText), shortcut: "⌘ ⇧ 5")
                ShortcutRow(title: L10n.tr(.shortcutQR), shortcut: "⌘ ⇧ 6")
                ShortcutRow(title: L10n.tr(.shortcutHistory), shortcut: "⌘ ⇧ H")
            }
            .padding(12)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            
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

struct ShortcutRow: View {
    let title: String
    let shortcut: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 13))
            Spacer()
            Text(shortcut)
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(nsColor: .windowBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
        }
    }
}
