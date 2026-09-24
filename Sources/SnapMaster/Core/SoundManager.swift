import Foundation
import AppKit

final class SoundManager {
    static let shared = SoundManager()
    
    private var shutterSound: NSSound?
    
    private init() {
        // Đường dẫn âm thanh chụp ảnh tiêu chuẩn của macOS
        let soundPath = "/System/Library/Components/CoreAudio.component/Contents/SharedSupport/SystemSounds/system/Screen Capture.aif"
        if FileManager.default.fileExists(atPath: soundPath) {
            shutterSound = NSSound(contentsOfFile: soundPath, byReference: true)
        }
    }
    
    func playShutterSound() {
        guard PreferencesManager.shared.playCaptureSound else { return }
        
        if let sound = shutterSound {
            sound.stop()
            sound.play()
        } else {
            // Âm thanh mặc định dự phòng nếu file hệ thống không tìm thấy
            NSSound.beep()
        }
    }
}
