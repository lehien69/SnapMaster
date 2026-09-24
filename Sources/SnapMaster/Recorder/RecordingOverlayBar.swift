import Foundation
import AppKit
import SwiftUI
import Combine

final class RecordingOverlayBarController: NSWindowController {
    private var timer: Timer?
    private var elapsedSeconds: Int = 0
    private let onStop: () -> Void
    private let onTogglePause: (Bool) -> Void
    
    init(onStop: @escaping () -> Void, onTogglePause: @escaping (Bool) -> Void) {
        self.onStop = onStop
        self.onTogglePause = onTogglePause
        
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let width: CGFloat = 200
        let height: CGFloat = 46
        let rect = NSRect(
            x: (screen.visibleFrame.width - width) / 2 + screen.visibleFrame.minX,
            y: screen.visibleFrame.minY + 36,
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
        
        let view = RecordingBarView(
            onStop: { [weak self] in
                self?.stopTimer()
                self?.onStop()
                self?.close()
            },
            onTogglePause: onTogglePause
        )
        
        window.contentView = NSHostingView(rootView: view)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func start() {
        window?.orderFront(nil)
    }
    
    func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

final class RecordingBarState: ObservableObject {
    @Published var seconds: Int = 0
    @Published var isPaused: Bool = false
    @Published var isDotVisible: Bool = true
}

struct RecordingBarView: View {
    let onStop: () -> Void
    let onTogglePause: (Bool) -> Void
    
    @ObservedObject var state = RecordingBarState()
    
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var body: some View {
        HStack(spacing: 12) {
            // Chấm đỏ nhấp nháy báo hiệu đang quay
            Circle()
                .fill(Color.red)
                .frame(width: 10, height: 10)
                .opacity(state.isPaused ? 0.3 : (state.isDotVisible ? 1.0 : 0.3))
                .animation(.easeInOut(duration: 0.5), value: state.isDotVisible)
            
            // Đồng hồ đếm thời gian
            Text(formattedTime(state.seconds))
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundColor(.white)
            
            Spacer()
            
            // Nút tạm dừng / tiếp tục
            Button(action: {
                state.isPaused.toggle()
                onTogglePause(state.isPaused)
            }) {
                Image(systemName: state.isPaused ? "play.fill" : "pause.fill")
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.2))
                    .clipShape(Circle())
            }
            .buttonStyle(PlainButtonStyle())
            
            // Nút dừng quay
            Button(action: onStop) {
                HStack(spacing: 4) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                    Text("Dừng")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.red)
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )
        )
        .onReceive(timer) { _ in
            if !state.isPaused {
                state.seconds += 1
                state.isDotVisible.toggle()
            }
        }
    }
    
    private func formattedTime(_ totalSeconds: Int) -> String {
        let mins = totalSeconds / 60
        let secs = totalSeconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}
