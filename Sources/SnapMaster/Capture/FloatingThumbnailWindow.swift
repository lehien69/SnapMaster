import Foundation
import AppKit
import SwiftUI

final class FloatingThumbnailWindowController: NSWindowController {
    private var dismissTimer: Timer?
    private let capturedImage: NSImage
    private let onEditRequested: (NSImage) -> Void
    
    init(image: NSImage, onEdit: @escaping (NSImage) -> Void) {
        self.capturedImage = image
        self.onEditRequested = onEdit
        
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let width: CGFloat = 260
        let aspectRatio = image.size.height > 0 ? (image.size.width / image.size.height) : 1.6
        let height = min(220, max(140, width / aspectRatio))
        
        let margin: CGFloat = 24.0
        let rect = NSRect(
            x: screen.visibleFrame.maxX - width - margin,
            y: screen.visibleFrame.minY + margin,
            width: width,
            height: height
        )
        
        let window = NSWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        super.init(window: window)
        
        let contentView = FloatingThumbnailView(
            image: image,
            onCopy: { [weak self] in
                ScreenCaptureManager.shared.copyImageToClipboard(image)
                self?.dismiss()
            },
            onSave: { [weak self] in
                let url = PreferencesManager.shared.generateTimestampedFilename()
                _ = ScreenCaptureManager.shared.saveImage(image, to: url)
                self?.dismiss()
            },
            onEdit: { [weak self] in
                self?.onEditRequested(image)
                self?.dismiss()
            },
            onOCR: { [weak self] in
                OCRManager.shared.recognizeAndCopyText(from: image)
                self?.dismiss()
            },
            onClose: { [weak self] in
                self?.dismiss()
            },
            onHoverChanged: { [weak self] isHovered in
                if isHovered {
                    self?.dismissTimer?.invalidate()
                } else {
                    self?.startDismissTimer()
                }
            }
        )
        
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func show() {
        window?.alphaValue = 0
        window?.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.25
            window?.animator().alphaValue = 1.0
        }
        
        startDismissTimer()
    }
    
    private func startDismissTimer() {
        dismissTimer?.invalidate()
        let duration = PreferencesManager.shared.thumbnailDuration
        dismissTimer = Timer.scheduledTimer(withTimeInterval: duration, repeats: false) { [weak self] _ in
            self?.dismiss()
        }
    }
    
    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.2
            window?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            self?.window?.orderOut(nil)
        })
    }
}

final class ThumbnailViewState: ObservableObject {
    @Published var isHovered = false
}

struct FloatingThumbnailView: View {
    let image: NSImage
    let onCopy: () -> Void
    let onSave: () -> Void
    let onEdit: () -> Void
    let onOCR: () -> Void
    let onClose: () -> Void
    let onHoverChanged: (Bool) -> Void
    
    @ObservedObject var state = ThumbnailViewState()
    
    var body: some View {
        ZStack {
            // Khung ảnh nền
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .shadow(color: Color.black.opacity(0.25), radius: 8, x: 0, y: 4)
            
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .cornerRadius(10)
                .padding(6)
            
            // Thanh công cụ thao tác nhanh khi rê chuột qua (Hover Actions)
            if state.isHovered {
                VStack {
                    HStack {
                        Spacer()
                        Button(action: onClose) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .padding(6)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        QuickActionButton(icon: "doc.on.doc", label: L10n.tr(.actionCopy), action: onCopy)
                        QuickActionButton(icon: "square.and.arrow.down", label: L10n.tr(.editorSave), action: onSave)
                        QuickActionButton(icon: "pencil.tip.crop.circle", label: L10n.tr(.actionEdit), action: onEdit)
                        QuickActionButton(icon: "text.viewfinder", label: "OCR", action: onOCR)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.black.opacity(0.75))
                    .cornerRadius(8)
                    .padding(.bottom, 6)
                }
                .transition(.opacity)
            }
        }
        .preferredColorScheme(PreferencesManager.shared.appTheme.colorScheme)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                state.isHovered = hovering
            }
            onHoverChanged(hovering)
        }
    }
}

struct QuickActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(label)
                    .font(.system(size: 9, weight: .medium))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.15))
            .cornerRadius(6)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
