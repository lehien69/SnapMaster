import Foundation
import AppKit
import SwiftUI

enum HistoryFilter: String, CaseIterable, Identifiable {
    case all = "all"
    case screenshot = "screenshot"
    case text = "text"
    case qrBarcode = "qrBarcode"
    case recording = "recording"
    
    var id: String { rawValue }
    
    var title: String {
        switch self {
        case .all: return L10n.tr(.filterAll)
        case .screenshot: return L10n.tr(.filterScreenshot)
        case .text: return L10n.tr(.filterText)
        case .qrBarcode: return L10n.tr(.filterQR)
        case .recording: return L10n.tr(.filterVideo)
        }
    }
}

@MainActor
final class HistoryViewState: ObservableObject {
    @Published var searchText: String = ""
    @Published var selectedFilter: HistoryFilter = .all
    @Published var isShowingClearAlert: Bool = false
    @Published var copiedItemId: UUID? = nil
}

struct HistoryView: View {
    @ObservedObject var historyManager = HistoryManager.shared
    @ObservedObject var prefs = PreferencesManager.shared
    @ObservedObject var state = HistoryViewState()
    
    var filteredItems: [HistoryItem] {
        var list = historyManager.items
        
        // Lọc theo loại
        if state.selectedFilter != .all {
            list = list.filter { $0.type.rawValue == state.selectedFilter.rawValue }
        }
        
        // Tìm kiếm theo từ khóa
        let query = state.searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !query.isEmpty {
            list = list.filter {
                $0.title.lowercased().contains(query) ||
                $0.content.lowercased().contains(query) ||
                ($0.secondaryInfo?.lowercased().contains(query) ?? false)
            }
        }
        
        return list
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Header & Search Bar
            headerBar
            
            Divider()
            
            // MARK: - Filter Tabs
            filterBar
            
            Divider()
            
            // MARK: - Items List
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredItems) { item in
                            HistoryCardView(
                                item: item,
                                isCopied: state.copiedItemId == item.id,
                                onCopy: {
                                    copyItem(item)
                                },
                                onDelete: {
                                    historyManager.removeItem(id: item.id)
                                }
                            )
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(minWidth: 680, minHeight: 480)
        .preferredColorScheme(prefs.appTheme.colorScheme)
        .alert(isPresented: $state.isShowingClearAlert) {
            Alert(
                title: Text(L10n.tr(.clearAlertTitle)),
                message: Text(L10n.tr(.clearAlertMessage)),
                primaryButton: .destructive(Text(L10n.tr(.clearAlertConfirm))) {
                    historyManager.clearHistory()
                },
                secondaryButton: .cancel(Text(L10n.tr(.clearAlertCancel)))
            )
        }
    }
    
    // MARK: - Subviews
    
    private var headerBar: some View {
        HStack(spacing: 12) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.accentColor)
            
            Text(L10n.tr(.historyTitle))
                .font(.headline)
            
            Text(L10n.tr(.historyItemsCount(historyManager.items.count)))
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            // Ô tìm kiếm
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField(L10n.tr(.searchPlaceholder), text: $state.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                if !state.searchText.isEmpty {
                    Button(action: { state.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)
            .frame(width: 220)
            
            // Nút Clear History
            Button(action: {
                state.isShowingClearAlert = true
            }) {
                Label(L10n.tr(.buttonClearAll), systemImage: "trash")
                    .foregroundColor(historyManager.items.isEmpty ? .secondary : .red)
            }
            .buttonStyle(BorderedButtonStyle())
            .disabled(historyManager.items.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    private var filterBar: some View {
        HStack {
            Picker("", selection: $state.selectedFilter) {
                ForEach(HistoryFilter.allCases) { filter in
                    Text(filter.title).tag(filter)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .frame(maxWidth: 450)
            
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.5))
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 40))
                .foregroundColor(.secondary.opacity(0.6))
            Text(state.searchText.isEmpty ? L10n.tr(.emptyHistory) : (prefs.appLanguage == .vietnamese ? "Không tìm thấy kết quả phù hợp" : "No matching results found"))
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.secondary)
            Text(state.searchText.isEmpty ? L10n.tr(.emptyHistorySub) : (prefs.appLanguage == .vietnamese ? "Hãy thử nhập từ khóa tìm kiếm khác." : "Try searching for a different keyword."))
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.8))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    private func copyItem(_ item: HistoryItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        
        if item.type == .screenshot, let path = item.filePath, let img = NSImage(contentsOfFile: path) {
            ScreenCaptureManager.shared.copyImageToClipboard(img)
        } else {
            pasteboard.setString(item.content, forType: .string)
        }
        
        state.copiedItemId = item.id
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if state.copiedItemId == item.id {
                state.copiedItemId = nil
            }
        }
    }
}

// MARK: - History Card View

struct HistoryCardView: View {
    let item: HistoryItem
    let isCopied: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm • dd/MM/yyyy"
        return formatter.string(from: item.timestamp)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Card Header
            HStack(spacing: 8) {
                Image(systemName: item.type.iconName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(colorForType(item.type))
                
                Text(item.title)
                    .font(.system(size: 13, weight: .bold))
                
                if let sec = item.secondaryInfo {
                    Text("• \(sec)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Text(formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            // Content
            if item.type == .screenshot, let path = item.filePath, FileManager.default.fileExists(atPath: path), let img = NSImage(contentsOfFile: path) {
                HStack(spacing: 12) {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 160, maxHeight: 90)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(path)
                            .font(.system(size: 11, design: .monospaced))
                            .lineLimit(2)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
            } else {
                Text(item.content)
                    .font(.system(size: 12, design: item.type == .qrBarcode ? .monospaced : .default))
                    .lineLimit(4)
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(nsColor: .windowBackgroundColor).opacity(0.7))
                    .cornerRadius(6)
            }
            
            // Action Buttons
            HStack(spacing: 10) {
                // Nút Copy
                Button(action: onCopy) {
                    Label(isCopied ? L10n.tr(.actionCopied) : L10n.tr(.actionCopy), systemImage: isCopied ? "checkmark" : "doc.on.doc")
                        .font(.caption)
                        .foregroundColor(isCopied ? .green : .primary)
                }
                .buttonStyle(BorderedButtonStyle())
                
                // Mở liên kết nếu là URL
                if item.isURL, let url = URL(string: item.content.trimmingCharacters(in: .whitespacesAndNewlines)) {
                    Button(action: {
                        NSWorkspace.shared.open(url)
                    }) {
                        Label(L10n.tr(.actionOpenLink), systemImage: "arrow.up.right.square")
                            .font(.caption)
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                
                // Mở Editor nếu là ảnh
                if item.type == .screenshot, let path = item.filePath, let img = NSImage(contentsOfFile: path) {
                    Button(action: {
                        let editor = EditorWindowController(image: img)
                        editor.showWindow(nil)
                        NSApp.activate(ignoringOtherApps: true)
                    }) {
                        Label(L10n.tr(.actionEdit), systemImage: "pencil.tip.crop.circle")
                            .font(.caption)
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                
                // Mở Finder nếu có file
                if let path = item.filePath, FileManager.default.fileExists(atPath: path) {
                    Button(action: {
                        let url = URL(fileURLWithPath: path)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }) {
                        Label(L10n.tr(.actionShowInFinder), systemImage: "folder")
                            .font(.caption)
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
                
                Spacer()
                
                // Nút xóa item
                Button(action: onDelete) {
                    Image(systemName: "trash")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .help(L10n.tr(.actionDelete))
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
    
    private func colorForType(_ type: HistoryItemType) -> Color {
        switch type {
        case .screenshot: return .blue
        case .text: return .orange
        case .qrBarcode: return .green
        case .recording: return .purple
        }
    }
}
