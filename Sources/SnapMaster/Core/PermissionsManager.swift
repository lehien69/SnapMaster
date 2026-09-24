import Foundation
import AppKit
import AVFoundation
import CoreGraphics

final class PermissionsManager {
    static let shared = PermissionsManager()
    
    private init() {}
    
    /// Kiểm tra quyền chụp & quay màn hình
    var hasScreenRecordingPermission: Bool {
        if #available(macOS 10.15, *) {
            if CGPreflightScreenCaptureAccess() {
                return true
            }
            // Fallback kiểm tra thông qua danh sách cửa sổ của hệ thống:
            // Khi chưa cấp quyền, macOS lọc bỏ kCGWindowName của các app khác.
            // Nếu có ít nhất 1 cửa sổ ngoài process hiện tại có tên, quyền đã được cấp.
            if let windowList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] {
                let currentPID = getpid()
                let hasOtherAppWindowNames = windowList.contains { info in
                    let pid = info[kCGWindowOwnerPID as String] as? pid_t
                    let name = info[kCGWindowName as String] as? String
                    return pid != currentPID && name != nil && !name!.isEmpty
                }
                if hasOtherAppWindowNames {
                    return true
                }
            }
            return false
        }
        return true
    }
    
    /// Yêu cầu người dùng cấp quyền quay/chụp màn hình
    func requestScreenRecordingPermission() {
        if #available(macOS 10.15, *) {
            _ = CGRequestScreenCaptureAccess()
        }
    }
    
    /// Kiểm tra quyền sử dụng Micro
    var hasMicrophonePermission: Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }
    
    /// Yêu cầu cấp quyền Micro
    func requestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)
        switch status {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }
    
    /// Mở Cài đặt hệ thống (System Settings) vào mục Quyền riêng tư
    func openSystemPrivacySettings(for type: String = "Privacy_ScreenCapture") {
        let urlString = "x-apple.systempreferences:com.apple.preference.security?\(type)"
        if let url = URL(string: urlString) {
            NSWorkspace.shared.open(url)
        }
    }
}
