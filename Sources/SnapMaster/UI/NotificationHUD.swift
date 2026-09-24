import Foundation
import AppKit
import SwiftUI

@MainActor
final class NotificationHUDController {
    static let shared = NotificationHUDController()
    
    private var hudWindow: NSWindow?
    private var dismissTimer: Timer?
    
    private init() {}
    
    func show(
        icon: String,
        title: String,
        message: String,
        isSuccess: Bool = true,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        if hudWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 440, height: 84),
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            window.isOpaque = false
            window.backgroundColor = .clear
            window.level = .floating
            window.hasShadow = true
            window.ignoresMouseEvents = false
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.hudWindow = window
        }
        
        guard let window = hudWindow else { return }
        
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let width: CGFloat = 440
        let height: CGFloat = 84
        let x = (screen.visibleFrame.width - width) / 2 + screen.visibleFrame.minX
        let y = screen.visibleFrame.maxY - height - 30
        window.setFrame(NSRect(x: x, y: y, width: width, height: height), display: true)
        
        let rootView = NotificationHUDView(
            icon: icon,
            title: title,
            message: message,
            isSuccess: isSuccess,
            actionTitle: actionTitle,
            onAction: { [weak self] in
                action?()
                self?.dismiss()
            },
            onDismiss: { [weak self] in
                self?.dismiss()
            }
        )
        
        window.contentView = NSHostingView(rootView: rootView)
        window.alphaValue = 0
        window.orderFront(nil)
        
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.2
            window.animator().alphaValue = 1.0
        }
        
        dismissTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
            DispatchQueue.main.async {
                self?.dismiss()
            }
        }
    }
    
    func dismiss() {
        dismissTimer?.invalidate()
        dismissTimer = nil
        
        guard let window = hudWindow else { return }
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.25
            window.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            DispatchQueue.main.async {
                self?.hudWindow?.orderOut(nil)
            }
        })
    }
}

struct NotificationHUDView: View {
    let icon: String
    let title: String
    let message: String
    let isSuccess: Bool
    let actionTitle: String?
    let onAction: () -> Void
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(isSuccess ? .green : .orange)
                .frame(width: 36, height: 36)
                .background(
                    Circle()
                        .fill(isSuccess ? Color.green.opacity(0.15) : Color.orange.opacity(0.15))
                )
            
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                
                Text(message)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundColor(Color.white.opacity(0.85))
                    .lineLimit(3)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            if let actTitle = actionTitle {
                Button(action: onAction) {
                    Text(actTitle)
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.6))
                    .padding(4)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.95))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.4), radius: 16, x: 0, y: 6)
        )
    }
}
