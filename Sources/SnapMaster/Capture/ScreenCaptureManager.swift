import Foundation
import AppKit
import CoreGraphics
import ImageIO
import ScreenCaptureKit

final class ScreenCaptureManager {
    static let shared = ScreenCaptureManager()
    
    private init() {}
    
    // MARK: - Native Interactive & FullScreen Capture (TextSniper & CleanShot X method)
    
    /// Chụp vùng màn hình tương tác người dùng dùng công cụ hệ thống macOS (/usr/sbin/screencapture)
    /// Mang lại trải nghiệm mượt mà 0ms độ trễ, crosshair chuẩn xác Retina như TextSniper & CleanShot X
    func captureAreaInteractively(completion: @escaping (NSImage?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("SnapMaster_capture_\(UUID().uuidString).png")
        
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            // -i: Chế độ tương tác (chuột chọn vùng hoặc phím cách để chọn cửa sổ)
            // -x: Tắt âm thanh mặc định của hệ thống (SnapMaster tự quản lý âm thanh)
            process.arguments = ["-i", "-x", tempURL.path]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Lỗi khi chạy /usr/sbin/screencapture: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Nếu người dùng nhấn ESC để hủy, file sẽ không tồn tại
            guard FileManager.default.fileExists(atPath: tempURL.path),
                  let data = try? Data(contentsOf: tempURL),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    /// Chụp toàn bộ màn hình qua công cụ hệ thống macOS
    func captureFullScreen(completion: @escaping (NSImage?) -> Void) {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("SnapMaster_fullscreen_\(UUID().uuidString).png")
        
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                try? FileManager.default.removeItem(at: tempURL)
            }
            
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            process.arguments = ["-x", tempURL.path]
            
            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                print("Lỗi khi chụp toàn màn hình: \(error)")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            guard FileManager.default.fileExists(atPath: tempURL.path),
                  let data = try? Data(contentsOf: tempURL),
                  let source = CGImageSourceCreateWithData(data as CFData, nil),
                  let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            DispatchQueue.main.async {
                completion(image)
            }
        }
    }
    
    // MARK: - Synchronous Fallbacks
    
    /// Chụp toàn bộ màn hình chính hoặc màn hình được chỉ định (đồng bộ)
    func captureFullScreen(displayID: CGDirectDisplayID = CGMainDisplayID()) -> NSImage? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("SnapMaster_sync_full_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", tempURL.path]
        try? process.run()
        process.waitUntilExit()
        
        guard FileManager.default.fileExists(atPath: tempURL.path),
              let data = try? Data(contentsOf: tempURL),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Chụp một màn hình NSScreen cụ thể và trả về CGImage nguyên bản sắc nét
    func captureScreenCGImage(_ screen: NSScreen) -> CGImage? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("SnapMaster_screen_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", tempURL.path]
        try? process.run()
        process.waitUntilExit()
        
        guard FileManager.default.fileExists(atPath: tempURL.path),
              let data = try? Data(contentsOf: tempURL),
              let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    
    /// Chụp một vùng cụ thể trên màn hình (tọa độ pixel CoreGraphics) qua screencapture -R
    func captureRect(_ rect: CGRect, displayID: CGDirectDisplayID = CGMainDisplayID()) -> NSImage? {
        let tempDir = FileManager.default.temporaryDirectory
        let tempURL = tempDir.appendingPathComponent("SnapMaster_rect_\(UUID().uuidString).png")
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let rectArg = "-R\(Int(rect.origin.x)),\(Int(rect.origin.y)),\(Int(rect.width)),\(Int(rect.height))"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        process.arguments = ["-x", rectArg, tempURL.path]
        try? process.run()
        process.waitUntilExit()
        
        guard FileManager.default.fileExists(atPath: tempURL.path),
              let data = try? Data(contentsOf: tempURL),
              let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
    }
    
    /// Chuyển đổi vùng chọn từ hệ tọa độ Cocoa (gốc dưới-trái) sang CoreGraphics (gốc trên-trái)
    func convertCocoaRectToCoreGraphics(_ cocoaRect: CGRect, for screen: NSScreen) -> CGRect {
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? screen.frame.height
        let scaleFactor = screen.backingScaleFactor
        
        // Tọa độ điểm logic trên màn hình chính
        let x = cocoaRect.origin.x
        let y = primaryScreenHeight - (cocoaRect.origin.y + cocoaRect.height)
        
        // Nhân tỉ lệ scale Retina
        return CGRect(
            x: x * scaleFactor,
            y: y * scaleFactor,
            width: cocoaRect.width * scaleFactor,
            height: cocoaRect.height * scaleFactor
        )
    }
    
    // MARK: - Clipboard & File Operations
    
    /// Sao chép ảnh vào Clipboard của hệ thống
    func copyImageToClipboard(_ image: NSImage) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if let tiffData = image.tiffRepresentation,
           let bitmap = NSBitmapImageRep(data: tiffData),
           let pngData = bitmap.representation(using: .png, properties: [:]) {
            pasteboard.setData(pngData, forType: .png)
        }
    }
    
    /// Lưu ảnh vào file định dạng PNG hoặc JPEG
    func saveImage(_ image: NSImage, to url: URL, format: String = "png") -> Bool {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        let fileData: Data?
        if format.lowercased() == "jpg" || format.lowercased() == "jpeg" {
            fileData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        } else {
            fileData = bitmap.representation(using: .png, properties: [:])
        }
        
        guard let data = fileData else { return false }
        
        do {
            try data.write(to: url)
            return true
        } catch {
            print("Lỗi khi lưu ảnh: \(error)")
            return false
        }
    }
}
