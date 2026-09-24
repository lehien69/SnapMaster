import Foundation
import AppKit
import SwiftUI

// MARK: - Update Window Controller
@MainActor
final class UpdateWindowController: NSWindowController {
    static let shared = UpdateWindowController()
    
    private var hostingView: NSHostingView<UpdateView>?
    
    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 380),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = L10n.tr(.updateModalTitle)
        window.center()
        window.isReleasedWhenClosed = false
        window.level = .floating
        
        super.init(window: window)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show(with release: GitHubRelease) {
        window?.title = L10n.tr(.updateModalTitle)
        
        let updateView = UpdateView(
            release: release,
            onClose: { [weak self] in
                self?.window?.orderOut(nil)
            }
        )
        
        self.hostingView = NSHostingView(rootView: updateView)
        window?.contentView = hostingView
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

// MARK: - Update View
struct UpdateView: View {
    let release: GitHubRelease
    let onClose: () -> Void
    
    @ObservedObject var updateManager = UpdateManager.shared
    @ObservedObject var prefs = PreferencesManager.shared
    
    var isUpdating: Bool {
        switch updateManager.status {
        case .downloading, .installing:
            return true
        default:
            return false
        }
    }
    
    var statusText: String {
        switch updateManager.status {
        case .downloading:
            return L10n.tr(.updateDownloading)
        case .installing:
            return L10n.tr(.updateInstalling)
        default:
            return ""
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack(spacing: 16) {
                Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 48, height: 48)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.tr(.updateAvailableHeader(release.tagName)))
                        .font(.headline)
                    
                    Text(L10n.tr(.updateCurrentVersionInfo(updateManager.currentVersion)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            
            Divider()
            
            // Release Notes Box
            VStack(alignment: .leading, spacing: 8) {
                Text(L10n.tr(.updateReleaseNotes))
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                ScrollView {
                    Text(release.body ?? (prefs.appLanguage == .vietnamese ? "Bản cập nhật bao gồm các cải tiến hiệu năng và sửa lỗi." : "This update includes performance improvements and bug fixes."))
                        .font(.system(size: 12))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                }
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                )
            }
            .padding(.horizontal, 20)
            
            // Progress Bar / Status
            if isUpdating {
                VStack(spacing: 6) {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle())
                    
                    Text(statusText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }
            
            Divider()
            
            // Bottom Action Buttons
            HStack {
                Button(L10n.tr(.updateButtonLater), action: onClose)
                    .disabled(isUpdating)
                    .buttonStyle(PlainButtonStyle())
                    .foregroundColor(isUpdating ? .secondary.opacity(0.5) : .secondary)
                
                Spacer()
                
                Button(action: {
                    updateManager.downloadAndInstallUpdate(release: release)
                }) {
                    HStack(spacing: 6) {
                        if isUpdating {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                        }
                        Text(L10n.tr(.updateButtonNow))
                    }
                }
                .buttonStyle(BorderedProminentButtonStyle())
                .disabled(isUpdating)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .frame(width: 480, height: 380)
        .preferredColorScheme(prefs.appTheme.colorScheme)
    }
}
