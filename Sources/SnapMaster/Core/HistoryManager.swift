import Foundation
import AppKit

enum HistoryItemType: String, Codable, CaseIterable {
    case screenshot = "screenshot"
    case text = "text"
    case qrBarcode = "qrBarcode"
    case recording = "recording"
    
    var displayName: String {
        switch self {
        case .screenshot: return "Ảnh chụp"
        case .text: return "Văn bản (OCR)"
        case .qrBarcode: return "Mã QR / Barcode"
        case .recording: return "Video quay"
        }
    }
    
    var iconName: String {
        switch self {
        case .screenshot: return "photo"
        case .text: return "text.viewfinder"
        case .qrBarcode: return "qrcode"
        case .recording: return "video"
        }
    }
}

struct HistoryItem: Identifiable, Codable, Equatable {
    let id: UUID
    let type: HistoryItemType
    let timestamp: Date
    var title: String
    var content: String
    var secondaryInfo: String?
    var filePath: String?
    
    init(
        id: UUID = UUID(),
        type: HistoryItemType,
        timestamp: Date = Date(),
        title: String,
        content: String,
        secondaryInfo: String? = nil,
        filePath: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.title = title
        self.content = content
        self.secondaryInfo = secondaryInfo
        self.filePath = filePath
    }
    
    var isURL: Bool {
        guard let url = URL(string: content.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }
}

@MainActor
final class HistoryManager: ObservableObject {
    static let shared = HistoryManager()
    
    @Published var items: [HistoryItem] = []
    
    private let fileURL: URL
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appFolder = appSupport.appendingPathComponent("SnapMaster", isDirectory: true)
        
        if !FileManager.default.fileExists(atPath: appFolder.path) {
            try? FileManager.default.createDirectory(at: appFolder, withIntermediateDirectories: true)
        }
        
        self.fileURL = appFolder.appendingPathComponent("history.json")
        loadHistory()
    }
    
    // MARK: - History Adding Methods
    
    func addScreenshot(filePath: String, dimensions: CGSize) {
        let title = "Ảnh chụp màn hình"
        let sec = "\(Int(dimensions.width)) × \(Int(dimensions.height)) px"
        let item = HistoryItem(
            type: .screenshot,
            title: title,
            content: filePath,
            secondaryInfo: sec,
            filePath: filePath
        )
        insert(item)
    }
    
    func addTextCapture(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        let title = "Trích xuất văn bản"
        let charCount = "\(trimmed.count) ký tự"
        let item = HistoryItem(
            type: .text,
            title: title,
            content: trimmed,
            secondaryInfo: charCount
        )
        insert(item)
    }
    
    func addBarcodeScan(payload: String, symbology: String) {
        let isQR = symbology.lowercased().contains("qr")
        let title = isQR ? "Mã QR" : "Mã Barcode (\(symbology))"
        let item = HistoryItem(
            type: .qrBarcode,
            title: title,
            content: payload,
            secondaryInfo: symbology
        )
        insert(item)
    }
    
    func addRecording(filePath: String, durationText: String? = nil) {
        let title = "Video quay màn hình"
        let item = HistoryItem(
            type: .recording,
            title: title,
            content: filePath,
            secondaryInfo: durationText ?? "MP4 Video",
            filePath: filePath
        )
        insert(item)
    }
    
    private func insert(_ item: HistoryItem) {
        items.insert(item, at: 0)
        // Giới hạn lưu tối đa 500 mục gần nhất
        if items.count > 500 {
            items = Array(items.prefix(500))
        }
        saveHistory()
    }
    
    // MARK: - Removal & Clear
    
    func removeItem(id: UUID) {
        items.removeAll(where: { $0.id == id })
        saveHistory()
    }
    
    func clearHistory() {
        items.removeAll()
        saveHistory()
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: fileURL, options: .atomic)
        } catch {
            print("Lỗi lưu lịch sử: \(error)")
        }
    }
    
    private func loadHistory() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let data = try Data(contentsOf: fileURL)
            let loaded = try JSONDecoder().decode([HistoryItem].self, from: data)
            self.items = loaded
        } catch {
            print("Lỗi đọc lịch sử: \(error)")
        }
    }
}
