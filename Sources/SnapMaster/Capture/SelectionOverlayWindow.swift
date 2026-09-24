import Foundation
import AppKit
import CoreGraphics

@MainActor
enum SelectionMode {
    case captureImage
    case captureText
    case scanQR
    
    var bannerText: String {
        switch self {
        case .captureImage:
            return "✨ Kéo chuột để chọn vùng chụp  •  ESC để hủy  •  Nhấp đúp toàn màn hình"
        case .captureText:
            return "📝 Kéo chọn vùng để trích xuất văn bản (OCR)  •  ESC để hủy"
        case .scanQR:
            return "📱 Kéo chọn vùng chứa mã QR / Barcode để quét  •  ESC để hủy"
        }
    }
    
    var themeColor: NSColor {
        switch self {
        case .captureImage:
            return NSColor(red: 0.1, green: 0.5, blue: 1.0, alpha: 0.9)
        case .captureText:
            return NSColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 0.9)
        case .scanQR:
            return NSColor(red: 0.15, green: 0.8, blue: 0.4, alpha: 0.9)
        }
    }
}

@MainActor
protocol SelectionOverlayDelegate: AnyObject {
    func didSelectArea(image: NSImage, rect: CGRect, on screen: NSScreen, mode: SelectionMode)
    func didCancelSelection()
}

final class SelectionOverlayWindow: NSWindow {
    weak var selectionDelegate: SelectionOverlayDelegate?
    let mode: SelectionMode
    let preCapturedImage: CGImage?
    
    init(screen: NSScreen, mode: SelectionMode = .captureImage, preCapturedImage: CGImage? = nil) {
        self.mode = mode
        self.preCapturedImage = preCapturedImage
        super.init(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        self.setFrame(screen.frame, display: true)
        
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .screenSaver
        self.ignoresMouseEvents = false
        self.acceptsMouseMovedEvents = true
        self.hasShadow = false
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        let overlayView = SelectionOverlayView(
            frame: NSRect(origin: .zero, size: screen.frame.size),
            screen: screen,
            mode: mode,
            preCapturedImage: preCapturedImage
        )
        overlayView.delegate = self
        self.contentView = overlayView
    }
    
    override var canBecomeKey: Bool {
        return true
    }
    
    override var canBecomeMain: Bool {
        return true
    }
}

extension SelectionOverlayWindow: SelectionOverlayViewDelegate {
    func overlayView(_ view: SelectionOverlayView, didFinishWithImage image: NSImage, rect: CGRect) {
        guard let screen = self.screen else { return }
        self.orderOut(nil)
        selectionDelegate?.didSelectArea(image: image, rect: rect, on: screen, mode: self.mode)
    }
    
    func overlayViewDidCancel(_ view: SelectionOverlayView) {
        self.orderOut(nil)
        selectionDelegate?.didCancelSelection()
    }
}

@MainActor
protocol SelectionOverlayViewDelegate: AnyObject {
    func overlayView(_ view: SelectionOverlayView, didFinishWithImage image: NSImage, rect: CGRect)
    func overlayViewDidCancel(_ view: SelectionOverlayView)
}

final class SelectionOverlayView: NSView {
    weak var delegate: SelectionOverlayViewDelegate?
    
    private let targetScreen: NSScreen
    private let mode: SelectionMode
    private let preCapturedImage: CGImage?
    private var startPoint: NSPoint?
    private var currentPoint: NSPoint = .zero
    private var isDragging = false
    private var trackingArea: NSTrackingArea?
    
    // Zoom / Color picker loupe
    private let loupeRadius: CGFloat = 50.0
    private var showLoupe = true
    
    init(frame: NSRect, screen: NSScreen, mode: SelectionMode = .captureImage, preCapturedImage: CGImage? = nil) {
        self.targetScreen = screen
        self.mode = mode
        self.preCapturedImage = preCapturedImage
        super.init(frame: frame)
        wantsLayer = true
        
        // Khởi tạo ngay tọa độ con trỏ chuột hiện tại để không bị giật lag khung hình đầu
        let mouseLocation = NSEvent.mouseLocation
        self.currentPoint = NSPoint(
            x: mouseLocation.x - screen.frame.origin.x,
            y: mouseLocation.y - screen.frame.origin.y
        )
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    // Nhận ngay sự kiện click chuột đầu tiên từ app chạy nền mà không bị hệ điều hành nuốt mất click
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func resetCursorRects() {
        super.resetCursorRects()
        addCursorRect(bounds, cursor: .crosshair)
    }
    
    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let existing = trackingArea {
            removeTrackingArea(existing)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect, .cursorUpdate],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }
    
    var selectionRect: NSRect? {
        guard let start = startPoint else { return nil }
        let minX = min(start.x, currentPoint.x)
        let maxX = max(start.x, currentPoint.x)
        let minY = min(start.y, currentPoint.y)
        let maxY = max(start.y, currentPoint.y)
        return NSRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }
        
        // 1. Phủ mờ toàn màn hình
        context.setFillColor(NSColor.black.withAlphaComponent(0.35).cgColor)
        context.fill(bounds)
        
        // 2. Nếu đang chọn vùng -> Khoét rỗng vùng chọn và vẽ viền
        if let rect = selectionRect, rect.width > 2 && rect.height > 2 {
            context.clear(rect)
            
            // Vẽ viền vùng chọn theo màu của chế độ
            context.setStrokeColor(mode.themeColor.cgColor)
            context.setLineWidth(2.0)
            context.stroke(rect)
            
            // Vẽ kích thước (Dimensions Badge)
            drawDimensionBadge(for: rect)
        } else {
            // Vẽ thước ngắm crosshair theo con trỏ chuột
            drawCrosshair(context: context, at: currentPoint)
            
            // Vẽ Kính lúp (Magnifier Loupe)
            if showLoupe {
                drawLoupe(context: context, at: currentPoint)
            }
        }
        
        // 3. Vẽ thanh hướng dẫn ở phía trên màn hình
        drawInstructionBanner()
    }
    
    private func drawCrosshair(context: CGContext, at point: NSPoint) {
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.4).cgColor)
        context.setLineWidth(1.0)
        
        // Đường ngang
        context.move(to: CGPoint(x: 0, y: point.y))
        context.addLine(to: CGPoint(x: bounds.width, y: point.y))
        
        // Đường dọc
        context.move(to: CGPoint(x: point.x, y: 0))
        context.addLine(to: CGPoint(x: point.x, y: bounds.height))
        context.strokePath()
    }
    
    private func drawLoupe(context: CGContext, at point: NSPoint) {
        // Vị trí đặt kính lúp (cách con trỏ chuột một khoảng)
        var loupeCenter = CGPoint(x: point.x + 75, y: point.y + 75)
        if loupeCenter.x + loupeRadius > bounds.width {
            loupeCenter.x = point.x - 75
        }
        if loupeCenter.y + loupeRadius > bounds.height {
            loupeCenter.y = point.y - 75
        }
        
        let loupeRect = CGRect(
            x: loupeCenter.x - loupeRadius,
            y: loupeCenter.y - loupeRadius,
            width: loupeRadius * 2,
            height: loupeRadius * 2
        )
        
        context.saveGState()
        
        // Vòng tròn kính lúp
        let clipPath = CGPath(ellipseIn: loupeRect, transform: nil)
        context.addPath(clipPath)
        context.clip()
        
        context.setFillColor(NSColor.black.withAlphaComponent(0.85).cgColor)
        context.fill(loupeRect)
        
        // Vẽ viền tâm ngắm của kính lúp
        context.setStrokeColor(NSColor.systemCyan.cgColor)
        context.setLineWidth(2.0)
        context.stroke(loupeRect)
        
        // Chữ thập tâm kính lúp
        context.setStrokeColor(NSColor.white.withAlphaComponent(0.7).cgColor)
        context.setLineWidth(1.0)
        context.move(to: CGPoint(x: loupeCenter.x - 10, y: loupeCenter.y))
        context.addLine(to: CGPoint(x: loupeCenter.x + 10, y: loupeCenter.y))
        context.move(to: CGPoint(x: loupeCenter.x, y: loupeCenter.y - 10))
        context.addLine(to: CGPoint(x: loupeCenter.x, y: loupeCenter.y + 10))
        context.strokePath()
        
        context.restoreGState()
        
        // Hiển thị tọa độ X, Y
        let coordText = "X: \(Int(point.x))  Y: \(Int(point.y))"
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = (coordText as NSString).size(withAttributes: attr)
        let badgeRect = CGRect(
            x: loupeCenter.x - textSize.width / 2 - 6,
            y: loupeCenter.y - loupeRadius - 22,
            width: textSize.width + 12,
            height: 18
        )
        
        let badgePath = NSBezierPath(roundedRect: badgeRect, xRadius: 4, yRadius: 4)
        NSColor.black.withAlphaComponent(0.8).setFill()
        badgePath.fill()
        (coordText as NSString).draw(at: CGPoint(x: badgeRect.origin.x + 6, y: badgeRect.origin.y + 2), withAttributes: attr)
    }
    
    private func drawDimensionBadge(for rect: NSRect) {
        let scale = targetScreen.backingScaleFactor
        let pixelWidth = Int(rect.width * scale)
        let pixelHeight = Int(rect.height * scale)
        let text = "\(pixelWidth) × \(pixelHeight) px"
        
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .semibold),
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attr)
        
        // Đặt badge ngay bên dưới hoặc phía trên vùng chọn
        var badgeY = rect.origin.y - 28
        if badgeY < 10 {
            badgeY = rect.origin.y + rect.height + 8
        }
        let badgeRect = NSRect(
            x: max(10, rect.origin.x + (rect.width - textSize.width) / 2 - 8),
            y: badgeY,
            width: textSize.width + 16,
            height: 22
        )
        
        let path = NSBezierPath(roundedRect: badgeRect, xRadius: 5, yRadius: 5)
        NSColor.black.withAlphaComponent(0.85).setFill()
        path.fill()
        
        NSColor.white.withAlphaComponent(0.2).setStroke()
        path.lineWidth = 1.0
        path.stroke()
        
        (text as NSString).draw(at: NSPoint(x: badgeRect.origin.x + 8, y: badgeRect.origin.y + 3), withAttributes: attr)
    }
    
    private func drawInstructionBanner() {
        let text = mode.bannerText
        let attr: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 13, weight: .medium),
            .foregroundColor: NSColor.white
        ]
        let textSize = (text as NSString).size(withAttributes: attr)
        let bannerRect = NSRect(
            x: (bounds.width - textSize.width) / 2 - 16,
            y: bounds.height - 48,
            width: textSize.width + 32,
            height: 28
        )
        
        let path = NSBezierPath(roundedRect: bannerRect, xRadius: 14, yRadius: 14)
        NSColor.black.withAlphaComponent(0.75).setFill()
        path.fill()
        
        (text as NSString).draw(at: NSPoint(x: bannerRect.origin.x + 16, y: bannerRect.origin.y + 6), withAttributes: attr)
    }
    
    // MARK: - Mouse Events
    override func mouseDown(with event: NSEvent) {
        startPoint = convert(event.locationInWindow, from: nil)
        currentPoint = startPoint!
        isDragging = true
        needsDisplay = true
    }
    
    override func mouseDragged(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseMoved(with event: NSEvent) {
        currentPoint = convert(event.locationInWindow, from: nil)
        needsDisplay = true
    }
    
    override func mouseUp(with event: NSEvent) {
        isDragging = false
        guard let rect = selectionRect else { return }
        
        if rect.width > 5 && rect.height > 5 {
            finishSelection(with: rect)
        } else if event.clickCount >= 2 {
            // Nhấp đúp chuột -> Chụp toàn màn hình
            finishSelection(with: bounds)
        } else {
            // Nhấp đơn hoặc rê chuột quá ngắn -> Reset trạng thái để khoanh vùng lại ngay
            startPoint = nil
            needsDisplay = true
        }
    }
    
    private func finishSelection(with rect: NSRect) {
        if let baseCG = preCapturedImage {
            let scaleX = CGFloat(baseCG.width) / bounds.width
            let scaleY = CGFloat(baseCG.height) / bounds.height
            
            let cropX = rect.origin.x * scaleX
            let cropY = (bounds.height - (rect.origin.y + rect.height)) * scaleY
            let cropWidth = rect.width * scaleX
            let cropHeight = rect.height * scaleY
            
            let pixelRect = CGRect(x: cropX, y: cropY, width: cropWidth, height: cropHeight)
            let safeRect = pixelRect.intersection(CGRect(x: 0, y: 0, width: CGFloat(baseCG.width), height: CGFloat(baseCG.height)))
            
            if !safeRect.isEmpty, let croppedCG = baseCG.cropping(to: safeRect) {
                let image = NSImage(cgImage: croppedCG, size: rect.size)
                delegate?.overlayView(self, didFinishWithImage: image, rect: rect)
                return
            }
        }
        
        // Fallback nếu không có preCapturedImage
        let screenNumber = (targetScreen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value ?? CGMainDisplayID()
        let cgRect = ScreenCaptureManager.shared.convertCocoaRectToCoreGraphics(rect, for: targetScreen)
        let image = ScreenCaptureManager.shared.captureRect(cgRect, displayID: CGDirectDisplayID(screenNumber)) ?? NSImage()
        delegate?.overlayView(self, didFinishWithImage: image, rect: rect)
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // ESC key
            delegate?.overlayViewDidCancel(self)
        } else {
            super.keyDown(with: event)
        }
    }
}
