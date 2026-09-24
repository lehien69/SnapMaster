import Foundation
import AppKit
import SwiftUI

// MARK: - GitHub Release Data Models
struct GitHubReleaseAsset: Codable {
    let name: String
    let browserDownloadURL: String
    let size: Int
    
    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

struct GitHubRelease: Codable {
    let tagName: String
    let name: String?
    let body: String?
    let htmlURL: String
    let publishedAt: String?
    let assets: [GitHubReleaseAsset]
    
    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case body
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

// MARK: - Update Status Enum
enum UpdateStatus: Equatable {
    case idle
    case checking
    case updateAvailable(GitHubRelease)
    case upToDate
    case downloading(progress: Double)
    case installing
    case failed(String)
    
    static func == (lhs: UpdateStatus, rhs: UpdateStatus) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.checking, .checking), (.upToDate, .upToDate), (.installing, .installing):
            return true
        case (.updateAvailable(let a), .updateAvailable(let b)):
            return a.tagName == b.tagName
        case (.downloading(let a), .downloading(let b)):
            return a == b
        case (.failed(let a), .failed(let b)):
            return a == b
        default:
            return false
        }
    }
}

// MARK: - Update Manager
@MainActor
final class UpdateManager: NSObject, ObservableObject {
    static let shared = UpdateManager()
    
    private let repoOwner = "lehien69"
    private let repoName = "SnapMaster"
    
    @Published var status: UpdateStatus = .idle
    @Published var latestRelease: GitHubRelease?
    @Published var errorMessage: String?
    
    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
    
    private override init() {
        super.init()
    }
    
    // MARK: - Semantic Version Comparison
    static func isVersion(_ newVersion: String, newerThan currentVersion: String) -> Bool {
        let cleanNew = newVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        let cleanCur = currentVersion.trimmingCharacters(in: CharacterSet(charactersIn: "vV \t\n\r"))
        
        let newParts = cleanNew.split(separator: ".").compactMap { Int($0) }
        let curParts = cleanCur.split(separator: ".").compactMap { Int($0) }
        
        let maxLen = max(newParts.count, curParts.count)
        for i in 0..<maxLen {
            let n = i < newParts.count ? newParts[i] : 0
            let c = i < curParts.count ? curParts[i] : 0
            if n > c { return true }
            if n < c { return false }
        }
        return false
    }
    
    // MARK: - Check For Updates
    func checkForUpdates(isUserInitiated: Bool = false) {
        guard status != .checking else { return }
        status = .checking
        errorMessage = nil
        
        let urlString = "https://api.github.com/repos/\(repoOwner)/\(repoName)/releases/latest"
        guard let url = URL(string: urlString) else {
            status = .failed("Invalid URL")
            return
        }
        
        var request = URLRequest(url: url)
        request.setValue("SnapMaster-Updater", forHTTPHeaderField: "User-Agent")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 15.0
        
        URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    self.status = .failed(error.localizedDescription)
                    if isUserInitiated {
                        self.showErrorAlert(message: L10n.tr(.updateCheckFailedMessage))
                    }
                    return
                }
                
                guard let httpResponse = response as? HTTPURLResponse else {
                    self.status = .failed("Không nhận được phản hồi")
                    return
                }
                
                if httpResponse.statusCode == 404 {
                    // Chưa có bản release nào
                    self.status = .upToDate
                    if isUserInitiated {
                        self.showUpToDateAlert()
                    }
                    return
                }
                
                guard httpResponse.statusCode == 200, let data = data else {
                    self.status = .failed("Mã phản hồi: \(httpResponse.statusCode)")
                    if isUserInitiated {
                        self.showErrorAlert(message: L10n.tr(.updateCheckFailedMessage))
                    }
                    return
                }
                
                do {
                    let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                    self.latestRelease = release
                    
                    if Self.isVersion(release.tagName, newerThan: self.currentVersion) {
                        self.status = .updateAvailable(release)
                        UpdateWindowController.shared.show(with: release)
                    } else {
                        self.status = .upToDate
                        if isUserInitiated {
                            self.showUpToDateAlert()
                        }
                    }
                } catch {
                    self.status = .failed("Lỗi phân tích dữ liệu: \(error.localizedDescription)")
                    if isUserInitiated {
                        self.showErrorAlert(message: L10n.tr(.updateCheckFailedMessage))
                    }
                }
            }
        }.resume()
    }
    
    // MARK: - Download & Auto Update
    func downloadAndInstallUpdate(release: GitHubRelease) {
        // Tìm file .zip asset
        guard let asset = release.assets.first(where: { $0.name.lowercased().hasSuffix(".zip") }) else {
            // Nếu không có file zip trong release, mở trang release trên GitHub để người dùng tải
            if let url = URL(string: release.htmlURL) {
                NSWorkspace.shared.open(url)
            }
            return
        }
        
        guard let downloadURL = URL(string: asset.browserDownloadURL) else { return }
        
        status = .downloading(progress: 0.0)
        
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent("SnapMasterUpdate", isDirectory: true)
        try? FileManager.default.removeItem(at: tempDir)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        let destinationZipURL = tempDir.appendingPathComponent("SnapMaster_Update.zip")
        
        let downloadTask = URLSession.shared.downloadTask(with: downloadURL) { [weak self] tempLocation, response, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                if let error = error {
                    self.status = .failed(error.localizedDescription)
                    self.showErrorAlert(message: error.localizedDescription)
                    return
                }
                
                guard let tempLocation = tempLocation else {
                    self.status = .failed("Không tải được file")
                    return
                }
                
                do {
                    try? FileManager.default.removeItem(at: destinationZipURL)
                    try FileManager.default.moveItem(at: tempLocation, to: destinationZipURL)
                    
                    self.status = .installing
                    self.applyUpdate(zipURL: destinationZipURL, in: tempDir)
                } catch {
                    self.status = .failed("Lỗi xử lý file tải về: \(error.localizedDescription)")
                    self.showErrorAlert(message: error.localizedDescription)
                }
            }
        }
        downloadTask.resume()
    }
    
    // MARK: - Extract and Apply Update Script
    private func applyUpdate(zipURL: URL, in tempDir: URL) {
        let extractedDir = tempDir.appendingPathComponent("extracted", isDirectory: true)
        try? FileManager.default.createDirectory(at: extractedDir, withIntermediateDirectories: true)
        
        // 1. Giải nén bằng tiện ích gốc ditto của macOS
        let dittoProcess = Process()
        dittoProcess.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
        dittoProcess.arguments = ["-xk", zipURL.path, extractedDir.path]
        
        do {
            try dittoProcess.run()
            dittoProcess.waitUntilExit()
            
            // 2. Tìm file SnapMaster.app bên trong thư mục giải nén
            let fileManager = FileManager.default
            guard let enumerator = fileManager.enumerator(at: extractedDir, includingPropertiesForKeys: [.isDirectoryKey]) else {
                status = .failed("Không tìm thấy nội dung giải nén")
                return
            }
            
            var newAppURL: URL?
            for case let fileURL as URL in enumerator {
                if fileURL.pathExtension == "app" {
                    newAppURL = fileURL
                    break
                }
            }
            
            guard let newApp = newAppURL else {
                status = .failed("Không tìm thấy SnapMaster.app trong bản cập nhật")
                return
            }
            
            let currentAppPath = Bundle.main.bundlePath
            let currentPID = ProcessInfo.processInfo.processIdentifier
            let scriptURL = tempDir.appendingPathComponent("apply_update.sh")
            
            let scriptContent = """
            #!/bin/bash
            sleep 1
            PID=$1
            OLD_APP="$2"
            NEW_APP="$3"

            if [ -n "$PID" ]; then
                kill -9 "$PID" 2>/dev/null || true
            fi

            rm -rf "$OLD_APP"
            cp -R "$NEW_APP" "$OLD_APP"
            xattr -dr com.apple.quarantine "$OLD_APP" 2>/dev/null || true
            rm -rf "/tmp/SnapMasterUpdate"

            open "$OLD_APP"
            """
            
            try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)
            
            // Cấp quyền thực thi
            let chmodProcess = Process()
            chmodProcess.executableURL = URL(fileURLWithPath: "/bin/chmod")
            chmodProcess.arguments = ["+x", scriptURL.path]
            try? chmodProcess.run()
            chmodProcess.waitUntilExit()
            
            // 3. Khởi chạy script chạy nền độc lập và thoát app hiện tại
            let launchProcess = Process()
            launchProcess.executableURL = URL(fileURLWithPath: "/bin/bash")
            launchProcess.arguments = [scriptURL.path, "\(currentPID)", currentAppPath, newApp.path]
            try launchProcess.run()
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                NSApp.terminate(nil)
            }
            
        } catch {
            status = .failed("Lỗi cài đặt bản cập nhật: \(error.localizedDescription)")
            showErrorAlert(message: error.localizedDescription)
        }
    }
    
    // MARK: - Alerts
    private func showUpToDateAlert() {
        let alert = NSAlert()
        alert.messageText = L10n.tr(.updateUpToDateTitle)
        alert.informativeText = L10n.tr(.updateUpToDateMessage(currentVersion))
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
    
    private func showErrorAlert(message: String) {
        let alert = NSAlert()
        alert.messageText = L10n.tr(.updateCheckFailedTitle)
        alert.informativeText = message
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
