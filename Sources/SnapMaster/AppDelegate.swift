import Foundation
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var overlayWindows: [SelectionOverlayWindow] = []
    private var currentThumbnailController: FloatingThumbnailWindowController?
    private var activeEditorController: EditorWindowController?
    private var recordingBarController: RecordingOverlayBarController?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Chạy ứng dụng dưới dạng Agent (không hiện icon to ở Dock trừ khi mở cửa sổ)
        NSApp.setActivationPolicy(.accessory)
        
        // 1. Khởi tạo Menu Bar
        setupMenuBar()
        
        // 2. Cài đặt Phím tắt toàn cầu
        setupHotkeys()
        
        // 3. Kiểm tra quyền chụp màn hình
        checkPermissionsOnStartup()
        
        // 4. Lắng nghe sự kiện ghi hình kết thúc
        ScreenRecorder.shared.onRecordingFinished = { [weak self] videoURL in
            self?.handleRecordingFinished(url: videoURL)
        }
        
        // 5. Khởi động ấm mô hình Vision OCR trong nền để không bị lag ở lần quét đầu tiên
        OCRManager.shared.warmUp()
    }
    
    // MARK: - Menu Bar Setup
    private func setupMenuBar() {
        let menuBar = MenuBarManager.shared
        menuBar.setupMenuBar()
        
        menuBar.onCaptureArea = { [weak self] in
            self?.startAreaCapture(mode: .captureImage)
        }
        
        menuBar.onCaptureFullScreen = { [weak self] in
            self?.startFullScreenCapture()
        }
        
        menuBar.onCaptureWindow = { [weak self] in
            self?.startAreaCapture(mode: .captureImage)
        }
        
        menuBar.onCaptureText = { [weak self] in
            self?.startAreaCapture(mode: .captureText)
        }
        
        menuBar.onScanQR = { [weak self] in
            self?.startAreaCapture(mode: .scanQR)
        }
        
        menuBar.onToggleRecord = { [weak self] in
            self?.toggleRecording()
        }
        
        menuBar.onOpenHistory = { [weak self] in
            self?.openHistory()
        }
    }
    
    // MARK: - Hotkey Setup
    private func setupHotkeys() {
        let hotkeys = HotkeyManager.shared
        hotkeys.setupDefaultHotkeys()
        
        hotkeys.onCaptureArea = { [weak self] in
            self?.startAreaCapture(mode: .captureImage)
        }
        
        hotkeys.onCaptureFullScreen = { [weak self] in
            self?.startFullScreenCapture()
        }
        
        hotkeys.onCaptureWindow = { [weak self] in
            self?.startAreaCapture(mode: .captureImage)
        }
        
        hotkeys.onCaptureText = { [weak self] in
            self?.startAreaCapture(mode: .captureText)
        }
        
        hotkeys.onScanQR = { [weak self] in
            self?.startAreaCapture(mode: .scanQR)
        }
        
        hotkeys.onRecordScreen = { [weak self] in
            self?.toggleRecording()
        }
        
        hotkeys.onOpenHistory = { [weak self] in
            self?.openHistory()
        }
    }
    
    private func checkPermissionsOnStartup() {
        if !PermissionsManager.shared.hasScreenRecordingPermission {
            PermissionsManager.shared.requestScreenRecordingPermission()
        }
    }
    
    // MARK: - Capture Actions
    func startAreaCapture(mode: SelectionMode = .captureImage) {
        guard PermissionsManager.shared.hasScreenRecordingPermission else {
            showPermissionAlert()
            return
        }
        
        // Kích hoạt app ra phía trước
        NSApp.activate(ignoringOtherApps: true)
        
        // Chụp màn hình tương tác người dùng theo chuẩn macOS (như TextSniper & CleanShot X)
        ScreenCaptureManager.shared.captureAreaInteractively { [weak self] capturedImage in
            guard let self = self else { return }
            guard let image = capturedImage else {
                // Người dùng nhấn ESC hoặc huỷ chọn
                return
            }
            self.handleCapturedArea(image: image, mode: mode)
        }
    }
    
    func startFullScreenCapture() {
        guard PermissionsManager.shared.hasScreenRecordingPermission else {
            showPermissionAlert()
            return
        }
        
        ScreenCaptureManager.shared.captureFullScreen { [weak self] captured in
            guard let self = self, let image = captured else { return }
            self.processCapturedImage(image)
        }
    }
    
    private func closeOverlays() {
        for win in overlayWindows {
            win.orderOut(nil)
        }
        overlayWindows.removeAll()
    }
    
    private func processCapturedImage(_ image: NSImage) {
        SoundManager.shared.playShutterSound()
        
        // Tự động copy vào clipboard
        if PreferencesManager.shared.autoCopyToClipboard {
            ScreenCaptureManager.shared.copyImageToClipboard(image)
        }
        
        // Tự động lưu file và thêm vào lịch sử
        let savedURL = PreferencesManager.shared.generateTimestampedFilename()
        _ = ScreenCaptureManager.shared.saveImage(image, to: savedURL)
        HistoryManager.shared.addScreenshot(filePath: savedURL.path, dimensions: image.size)
        
        // Hiển thị Floating Thumbnail
        if PreferencesManager.shared.showFloatingThumbnail {
            currentThumbnailController?.dismiss()
            let thumb = FloatingThumbnailWindowController(
                image: image,
                onEdit: { [weak self] img in
                    self?.openEditor(for: img)
                }
            )
            self.currentThumbnailController = thumb
            thumb.show()
        } else {
            // Mở thẳng trình chỉnh sửa nếu không dùng floating thumbnail
            openEditor(for: image)
        }
    }
    
    func openEditor(for image: NSImage) {
        let editor = EditorWindowController(image: image)
        self.activeEditorController = editor
        editor.showWindow(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    
    func openHistory() {
        HistoryWindowController.shared.showWindow()
    }
    
    // MARK: - Recording Actions
    func toggleRecording() {
        let recorder = ScreenRecorder.shared
        if recorder.isRecording {
            Task { @MainActor [weak self] in
                await recorder.stopRecording()
                self?.recordingBarController?.stopTimer()
                self?.recordingBarController?.close()
                self?.recordingBarController = nil
                MenuBarManager.shared.rebuildMenu(isRecording: false)
            }
        } else {
            guard PermissionsManager.shared.hasScreenRecordingPermission else {
                showPermissionAlert()
                return
            }
            
            Task { @MainActor [weak self] in
                do {
                    try await recorder.startRecording()
                    MenuBarManager.shared.rebuildMenu(isRecording: true)
                    
                    let bar = RecordingOverlayBarController(
                        onStop: { [weak self] in
                            self?.toggleRecording()
                        },
                        onTogglePause: { isPaused in
                            if isPaused {
                                recorder.pauseRecording()
                            } else {
                                recorder.resumeRecording()
                            }
                        }
                    )
                    self?.recordingBarController = bar
                    bar.start()
                } catch {
                    print("Lỗi khi bắt đầu quay: \(error)")
                }
            }
        }
    }
    
    private func handleRecordingFinished(url: URL) {
        HistoryManager.shared.addRecording(filePath: url.path)
        // Tự động hiện file trong Finder
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }
    
    private func showPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Cần quyền Ghi Màn Hình"
        alert.informativeText = """
        SnapMaster cần quyền 'Ghi Màn Hình & Hệ Thống' để có thể chụp ảnh và quay video.

        💡 Lưu ý quan trọng: Nếu bạn thấy công tắc 'SnapMaster' đã BẬT sẵn trong Cài đặt Hệ Thống:
        1. Vui lòng gạt TẮT rồi BẬT LẠI công tắc cho SnapMaster (hoặc bấm dấu '-' để xoá rồi gạt bật lại).
        2. Nhấn nút 'Thử chụp lại' bên dưới để hệ thống áp dụng chứng chỉ mới.
        """
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Mở Cài đặt")
        alert.addButton(withTitle: "Thử chụp lại")
        alert.addButton(withTitle: "Hủy")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            PermissionsManager.shared.openSystemPrivacySettings()
        } else if response == .alertSecondButtonReturn {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.startAreaCapture()
            }
        }
    }

    // MARK: - Capture Handlers
    func handleCapturedArea(image: NSImage, mode: SelectionMode) {
        switch mode {
        case .captureImage:
            processCapturedImage(image)
            
        case .captureText:
            SoundManager.shared.playShutterSound()
            OCRManager.shared.recognizeAndCopyText(from: image) { text in
                if let recognized = text, !recognized.isEmpty {
                    HistoryManager.shared.addTextCapture(recognized)
                    
                    // Nếu là liên kết web hợp lệ, kiểm tra mở nếu cần
                    let detectedURL = BarcodeManager.extractURL(from: recognized)
                    let isLink = detectedURL != nil
                    
                    NotificationHUDController.shared.show(
                        icon: isLink ? "link.circle.fill" : "text.viewfinder",
                        title: isLink ? L10n.tr(.hudLinkCopied) : L10n.tr(.hudTextExtracted),
                        message: recognized,
                        isSuccess: true,
                        actionTitle: isLink ? L10n.tr(.actionOpenLink) : L10n.tr(.hudCopyAgain),
                        action: {
                            if let url = detectedURL {
                                NSWorkspace.shared.open(url)
                            } else {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(recognized, forType: .string)
                            }
                        }
                    )
                } else {
                    NotificationHUDController.shared.show(
                        icon: "exclamationmark.triangle",
                        title: L10n.tr(.hudNoTextFound),
                        message: L10n.tr(.hudNoTextFoundTip),
                        isSuccess: false
                    )
                }
            }
            
        case .scanQR:
            SoundManager.shared.playShutterSound()
            BarcodeManager.shared.scanFirstBarcodeAndCopy(from: image) { result in
                if let barcode = result {
                    HistoryManager.shared.addBarcodeScan(payload: barcode.payload, symbology: barcode.symbology)
                    
                    // Kiểm tra URL theo chuẩn TextSniper
                    let detectedURL = BarcodeManager.extractURL(from: barcode.payload)
                    if let url = detectedURL {
                        // Tự động mở liên kết trên trình duyệt web mặc định (Hành vi đặc trưng của TextSniper)
                        NSWorkspace.shared.open(url)
                    }
                    
                    let isLink = detectedURL != nil
                    NotificationHUDController.shared.show(
                        icon: isLink ? "link.circle.fill" : "qrcode",
                        title: isLink ? L10n.tr(.hudCopiedAndOpened) : L10n.tr(.hudCopiedToClipboard),
                        message: barcode.payload,
                        isSuccess: true,
                        actionTitle: isLink ? L10n.tr(.hudReopenLink) : L10n.tr(.hudCopyAgain),
                        action: {
                            if let url = detectedURL {
                                NSWorkspace.shared.open(url)
                            } else {
                                let pb = NSPasteboard.general
                                pb.clearContents()
                                pb.setString(barcode.payload, forType: .string)
                            }
                        }
                    )
                } else {
                    NotificationHUDController.shared.show(
                        icon: "exclamationmark.triangle",
                        title: L10n.tr(.hudNoCodeFound),
                        message: L10n.tr(.hudNoCodeFoundTip),
                        isSuccess: false
                    )
                }
            }
        }
    }
}

// MARK: - SelectionOverlayDelegate
extension AppDelegate: SelectionOverlayDelegate {
    func didSelectArea(image: NSImage, rect: CGRect, on screen: NSScreen, mode: SelectionMode) {
        closeOverlays()
        handleCapturedArea(image: image, mode: mode)
    }
    
    func didCancelSelection() {
        closeOverlays()
    }
}
