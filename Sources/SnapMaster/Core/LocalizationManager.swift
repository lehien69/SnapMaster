import Foundation
import AppKit
import SwiftUI

// MARK: - App Language Enum
enum AppLanguage: String, CaseIterable, Identifiable, Codable {
    case vietnamese = "vi"
    case english = "en"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .vietnamese: return "Tiếng Việt"
        case .english: return "English"
        }
    }
}

// MARK: - App Theme Enum
enum AppTheme: String, CaseIterable, Identifiable, Codable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var id: String { rawValue }
    
    func displayName(language: AppLanguage) -> String {
        switch (self, language) {
        case (.system, .vietnamese): return "Theo hệ thống"
        case (.system, .english): return "System Default"
        case (.light, .vietnamese): return "Sáng (Light)"
        case (.light, .english): return "Light"
        case (.dark, .vietnamese): return "Tối (Dark)"
        case (.dark, .english): return "Dark"
        }
    }
    
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

// MARK: - Localization Service (L10n)
final class L10n {
    static var currentLanguage: AppLanguage {
        PreferencesManager.shared.appLanguage
    }
    
    static func tr(_ key: Key) -> String {
        key.localized(for: currentLanguage)
    }
    
    enum Key {
        // MARK: - Menu Bar
        case menuCaptureArea
        case menuCaptureFull
        case menuCaptureWindow
        case menuCaptureText
        case menuScanQR
        case menuRecord
        case menuStopRecord
        case menuHistory
        case menuOpenFolder
        case menuSettings
        case menuCheckUpdates
        case menuQuit
        
        // MARK: - Settings General
        case settingsTitle
        case tabGeneral
        case tabShortcuts
        case tabPersonalization
        case sectionAppearanceLanguage
        case labelLanguage
        case labelTheme
        case sectionSaveDirectory
        case buttonChooseDirectory
        case buttonOpenInFinder
        case sectionCaptureOptions
        case toggleAutoCopy
        case toggleThumbnail
        case toggleSound
        case labelThumbnailDuration
        case secondsSuffix
        
        // MARK: - Settings Shortcuts
        case shortcutsHeader
        case shortcutArea
        case shortcutFull
        case shortcutWindow
        case shortcutRecord
        case shortcutText
        case shortcutQR
        case shortcutHistory
        case shortcutsNote
        
        // MARK: - Settings Personalization
        case sectionWatermark
        case toggleWatermark
        case placeholderWatermark
        case labelOpacity
        case sectionBeautify
        case labelPadding
        case labelCornerRadius
        
        // MARK: - History
        case historyTitle
        case historyItemsCount(Int)
        case filterAll
        case filterScreenshot
        case filterText
        case filterQR
        case filterVideo
        case searchPlaceholder
        case buttonClearAll
        case emptyHistory
        case emptyHistorySub
        case clearAlertTitle
        case clearAlertMessage
        case clearAlertConfirm
        case clearAlertCancel
        case actionCopy
        case actionCopied
        case actionOpenLink
        case actionEdit
        case actionShowInFinder
        case actionDelete
        
        // MARK: - HUD & Toasts
        case hudTextExtracted
        case hudLinkCopied
        case hudCopiedToClipboard
        case hudCopiedAndOpened
        case hudNoTextFound
        case hudNoTextFoundTip
        case hudNoCodeFound
        case hudNoCodeFoundTip
        case hudReopenLink
        case hudCopyAgain
        
        // MARK: - Editor
        case editorOCR
        case editorCopy
        case editorSave
        case editorClose
        case editorCopiedImage
        case editorSavedImage
        case editorNoText
        case editorCopiedChars(Int)
        
        // MARK: - Auto Update
        case sectionSoftwareUpdate
        case toggleAutoCheckUpdates
        case buttonCheckUpdatesNow
        case labelCurrentVersion(String)
        case updateModalTitle
        case updateAvailableHeader(String)
        case updateCurrentVersionInfo(String)
        case updateReleaseNotes
        case updateButtonNow
        case updateButtonLater
        case updateDownloading
        case updateInstalling
        case updateUpToDateTitle
        case updateUpToDateMessage(String)
        case updateCheckFailedTitle
        case updateCheckFailedMessage
        
        func localized(for lang: AppLanguage) -> String {
            switch lang {
            case .vietnamese:
                switch self {
                // Menu Bar
                case .menuCaptureArea: return "Chụp vùng chọn (Area)"
                case .menuCaptureFull: return "Chụp toàn màn hình"
                case .menuCaptureWindow: return "Chụp cửa sổ"
                case .menuCaptureText: return "Quét chữ màn hình (OCR)"
                case .menuScanQR: return "Quét mã QR / Barcode"
                case .menuRecord: return "Quay video màn hình"
                case .menuStopRecord: return "⏹ Dừng quay màn hình"
                case .menuHistory: return "Lịch sử hoạt động (History)..."
                case .menuOpenFolder: return "Mở thư mục ảnh..."
                case .menuSettings: return "Cài đặt & Cá nhân hóa..."
                case .menuCheckUpdates: return "Kiểm tra bản cập nhật..."
                case .menuQuit: return "Thoát SnapMaster"
                    
                // Settings General
                case .settingsTitle: return "Cài đặt SnapMaster"
                case .tabGeneral: return "Chung"
                case .tabShortcuts: return "Phím tắt"
                case .tabPersonalization: return "Cá nhân hóa"
                case .sectionAppearanceLanguage: return "Giao diện & Ngôn ngữ"
                case .labelLanguage: return "Ngôn ngữ:"
                case .labelTheme: return "Chủ đề giao diện:"
                case .sectionSaveDirectory: return "Thư mục lưu trữ"
                case .buttonChooseDirectory: return "Chọn thư mục..."
                case .buttonOpenInFinder: return "Mở thư mục trong Finder"
                case .sectionCaptureOptions: return "Tùy chọn chụp ảnh"
                case .toggleAutoCopy: return "Tự động sao chép ảnh vào Clipboard"
                case .toggleThumbnail: return "Hiển thị cửa sổ xem nhanh (Floating Thumbnail)"
                case .toggleSound: return "Phát âm thanh màn trập khi chụp"
                case .labelThumbnailDuration: return "Thời gian hiển thị Thumbnail:"
                case .secondsSuffix: return "giây"
                    
                // Settings Shortcuts
                case .shortcutsHeader: return "Phím tắt toàn cầu (Global Hotkeys)"
                case .shortcutArea: return "Chụp vùng chọn (Area)"
                case .shortcutFull: return "Chụp toàn màn hình (Full Screen)"
                case .shortcutWindow: return "Chụp cửa sổ (Window)"
                case .shortcutRecord: return "Bật / Tắt quay màn hình (Screen Record)"
                case .shortcutText: return "Quét chữ màn hình (Capture Text - OCR)"
                case .shortcutQR: return "Quét mã QR / Barcode màn hình"
                case .shortcutHistory: return "Mở lịch sử (History)"
                case .shortcutsNote: return "💡 Các phím tắt này hoạt động trên toàn hệ thống ngay cả khi bạn đang mở ứng dụng khác."
                    
                // Settings Personalization
                case .sectionWatermark: return "Watermark (Đóng dấu cá nhân)"
                case .toggleWatermark: return "Bật đóng dấu Watermark tự động"
                case .placeholderWatermark: return "Nội dung Watermark..."
                case .labelOpacity: return "Độ mờ:"
                case .sectionBeautify: return "Tùy biến khung viền ảnh (Beautify Framing)"
                case .labelPadding: return "Khoảng đệm nền (Padding):"
                case .labelCornerRadius: return "Bo góc ảnh (Corner Radius):"
                    
                // History
                case .historyTitle: return "Lịch sử hoạt động"
                case .historyItemsCount(let count): return "(\(count) mục)"
                case .filterAll: return "Tất cả"
                case .filterScreenshot: return "Ảnh chụp"
                case .filterText: return "Văn bản"
                case .filterQR: return "Mã QR"
                case .filterVideo: return "Video"
                case .searchPlaceholder: return "Tìm kiếm nội dung lịch sử..."
                case .buttonClearAll: return "Xóa tất cả"
                case .emptyHistory: return "Chưa có mục nào trong lịch sử"
                case .emptyHistorySub: return "Các lần chụp màn hình, trích xuất chữ và quét mã QR sẽ tự động hiển thị tại đây."
                case .clearAlertTitle: return "Xóa toàn bộ lịch sử?"
                case .clearAlertMessage: return "Hành động này sẽ xóa danh sách các lần chụp, quét chữ và mã QR đã lưu trong lịch sử SnapMaster. Các file ảnh/video thực tế trong máy sẽ không bị xóa."
                case .clearAlertConfirm: return "Xóa lịch sử"
                case .clearAlertCancel: return "Hủy"
                case .actionCopy: return "Sao chép"
                case .actionCopied: return "Đã sao chép!"
                case .actionOpenLink: return "Mở liên kết"
                case .actionEdit: return "Chỉnh sửa"
                case .actionShowInFinder: return "Xem trong Finder"
                case .actionDelete: return "Xóa"
                    
                // HUD & Toasts
                case .hudTextExtracted: return "Đã trích xuất & sao chép văn bản"
                case .hudLinkCopied: return "Đã sao chép liên kết"
                case .hudCopiedToClipboard: return "Đã sao chép vào Clipboard"
                case .hudCopiedAndOpened: return "Đã sao chép & mở liên kết"
                case .hudNoTextFound: return "Không tìm thấy văn bản"
                case .hudNoTextFoundTip: return "💡 Mẹo: Hãy khoanh vùng rõ nét bao gồm khoảng trống xung quanh chữ."
                case .hudNoCodeFound: return "Không tìm thấy mã"
                case .hudNoCodeFoundTip: return "💡 Mẹo: Hãy khoanh vùng rộng hơn bao gồm cả khoảng trắng xung quanh mã QR/Barcode."
                case .hudReopenLink: return "Mở lại liên kết"
                case .hudCopyAgain: return "Sao chép lại"
                    
                // Editor
                case .editorOCR: return "OCR Copy Chữ"
                case .editorCopy: return "Copy Ảnh"
                case .editorSave: return "Lưu Ảnh"
                case .editorClose: return "Đóng"
                case .editorCopiedImage: return "Đã sao chép ảnh vào Clipboard!"
                case .editorSavedImage: return "Đã lưu ảnh vào thư mục SnapMaster!"
                case .editorNoText: return "Không phát hiện chữ trên ảnh."
                case .editorCopiedChars(let count): return "Đã sao chép \(count) ký tự từ ảnh!"
                
                // Auto Update
                case .sectionSoftwareUpdate: return "Cập nhật ứng dụng"
                case .toggleAutoCheckUpdates: return "Tự động kiểm tra bản cập nhật khi khởi động"
                case .buttonCheckUpdatesNow: return "Kiểm tra cập nhật ngay..."
                case .labelCurrentVersion(let v): return "Phiên bản hiện tại: v\(v)"
                case .updateModalTitle: return "Cập nhật SnapMaster"
                case .updateAvailableHeader(let v): return "Đã có bản cập nhật mới: \(v)"
                case .updateCurrentVersionInfo(let v): return "Phiên bản bạn đang dùng: v\(v)"
                case .updateReleaseNotes: return "Nội dung cập nhật mới:"
                case .updateButtonNow: return "Tải & Cập nhật ngay"
                case .updateButtonLater: return "Để sau"
                case .updateDownloading: return "Đang tải bản cập nhật..."
                case .updateInstalling: return "Đang cài đặt và khởi động lại..."
                case .updateUpToDateTitle: return "Bạn đang dùng phiên bản mới nhất"
                case .updateUpToDateMessage(let v): return "SnapMaster v\(v) là phiên bản mới nhất hiện có."
                case .updateCheckFailedTitle: return "Kiểm tra cập nhật thất bại"
                case .updateCheckFailedMessage: return "Không thể kết nối đến máy chủ GitHub để kiểm tra bản cập nhật. Vui lòng thử lại sau."
                }
                
            case .english:
                switch self {
                // Menu Bar
                case .menuCaptureArea: return "Capture Area"
                case .menuCaptureFull: return "Capture Full Screen"
                case .menuCaptureWindow: return "Capture Window"
                case .menuCaptureText: return "Capture Text (OCR)"
                case .menuScanQR: return "Scan QR / Barcode"
                case .menuRecord: return "Record Screen"
                case .menuStopRecord: return "⏹ Stop Recording"
                case .menuHistory: return "History..."
                case .menuOpenFolder: return "Open Screenshots Folder..."
                case .menuSettings: return "Settings & Preferences..."
                case .menuCheckUpdates: return "Check for Updates..."
                case .menuQuit: return "Quit SnapMaster"
                    
                // Settings General
                case .settingsTitle: return "SnapMaster Settings"
                case .tabGeneral: return "General"
                case .tabShortcuts: return "Shortcuts"
                case .tabPersonalization: return "Personalization"
                case .sectionAppearanceLanguage: return "Appearance & Language"
                case .labelLanguage: return "Language:"
                case .labelTheme: return "Theme:"
                case .sectionSaveDirectory: return "Save Directory"
                case .buttonChooseDirectory: return "Choose Folder..."
                case .buttonOpenInFinder: return "Open in Finder"
                case .sectionCaptureOptions: return "Capture Options"
                case .toggleAutoCopy: return "Auto-copy screenshot to Clipboard"
                case .toggleThumbnail: return "Show Floating Thumbnail"
                case .toggleSound: return "Play shutter sound when capturing"
                case .labelThumbnailDuration: return "Thumbnail duration:"
                case .secondsSuffix: return "sec"
                    
                // Settings Shortcuts
                case .shortcutsHeader: return "Global Hotkeys"
                case .shortcutArea: return "Capture Area"
                case .shortcutFull: return "Capture Full Screen"
                case .shortcutWindow: return "Capture Window"
                case .shortcutRecord: return "Toggle Screen Recording"
                case .shortcutText: return "Capture Text (OCR)"
                case .shortcutQR: return "Scan QR / Barcode"
                case .shortcutHistory: return "Open History"
                case .shortcutsNote: return "💡 These shortcuts work globally even when you are using other apps."
                    
                // Settings Personalization
                case .sectionWatermark: return "Watermark"
                case .toggleWatermark: return "Enable automatic watermark"
                case .placeholderWatermark: return "Watermark text..."
                case .labelOpacity: return "Opacity:"
                case .sectionBeautify: return "Beautify Framing"
                case .labelPadding: return "Padding:"
                case .labelCornerRadius: return "Corner Radius:"
                    
                // History
                case .historyTitle: return "Activity History"
                case .historyItemsCount(let count): return "(\(count) items)"
                case .filterAll: return "All"
                case .filterScreenshot: return "Screenshots"
                case .filterText: return "Text"
                case .filterQR: return "QR / Barcode"
                case .filterVideo: return "Videos"
                case .searchPlaceholder: return "Search history..."
                case .buttonClearAll: return "Clear All"
                case .emptyHistory: return "No history items yet"
                case .emptyHistorySub: return "Captured screenshots, extracted text, and scanned QR codes will appear here."
                case .clearAlertTitle: return "Clear All History?"
                case .clearAlertMessage: return "This will clear all screenshot history, OCR text, and QR scan records. Files stored on your disk will remain safe."
                case .clearAlertConfirm: return "Clear History"
                case .clearAlertCancel: return "Cancel"
                case .actionCopy: return "Copy"
                case .actionCopied: return "Copied!"
                case .actionOpenLink: return "Open Link"
                case .actionEdit: return "Edit"
                case .actionShowInFinder: return "Show in Finder"
                case .actionDelete: return "Delete"
                    
                // HUD & Toasts
                case .hudTextExtracted: return "Text Extracted & Copied"
                case .hudLinkCopied: return "Link Copied"
                case .hudCopiedToClipboard: return "Copied to Clipboard"
                case .hudCopiedAndOpened: return "Copied & Opened Link"
                case .hudNoTextFound: return "No Text Found"
                case .hudNoTextFoundTip: return "💡 Tip: Make a clear selection including some padding around the text."
                case .hudNoCodeFound: return "No Code Detected"
                case .hudNoCodeFoundTip: return "💡 Tip: Make a wider selection including white margins around the code."
                case .hudReopenLink: return "Open Link"
                case .hudCopyAgain: return "Copy Again"
                    
                // Editor
                case .editorOCR: return "OCR Copy Text"
                case .editorCopy: return "Copy Image"
                case .editorSave: return "Save Image"
                case .editorClose: return "Close"
                case .editorCopiedImage: return "Image copied to Clipboard!"
                case .editorSavedImage: return "Image saved to SnapMaster folder!"
                case .editorNoText: return "No text detected in image."
                case .editorCopiedChars(let count): return "Copied \(count) characters from image!"
                
                // Auto Update
                case .sectionSoftwareUpdate: return "Software Update"
                case .toggleAutoCheckUpdates: return "Automatically check for updates on startup"
                case .buttonCheckUpdatesNow: return "Check for Updates Now..."
                case .labelCurrentVersion(let v): return "Current version: v\(v)"
                case .updateModalTitle: return "SnapMaster Software Update"
                case .updateAvailableHeader(let v): return "New version available: \(v)"
                case .updateCurrentVersionInfo(let v): return "Your current version: v\(v)"
                case .updateReleaseNotes: return "What's new in this release:"
                case .updateButtonNow: return "Download & Update Now"
                case .updateButtonLater: return "Later"
                case .updateDownloading: return "Downloading update..."
                case .updateInstalling: return "Installing update and relaunching..."
                case .updateUpToDateTitle: return "You're Up to Date"
                case .updateUpToDateMessage(let v): return "SnapMaster v\(v) is currently the newest version available."
                case .updateCheckFailedTitle: return "Update Check Failed"
                case .updateCheckFailedMessage: return "Could not connect to GitHub update server. Please check your internet connection."
                }
            }
        }
    }
}
