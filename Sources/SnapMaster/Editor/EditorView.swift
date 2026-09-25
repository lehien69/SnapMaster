import Foundation
import AppKit
import SwiftUI

final class EditorViewModel: ObservableObject {
    @Published var baseImage: NSImage
    @Published var blurredBaseImage: NSImage?
    @Published var canvasSize: CGSize = .zero
    @Published var annotations: [AnnotationItem] = []
    @Published var undoneAnnotations: [AnnotationItem] = []
    
    @Published var currentTool: AnnotationTool = .arrow
    @Published var currentColor: Color = .red
    @Published var strokeWidth: CGFloat = 4.0
    @Published var nextStepNumber: Int = 1
    
    // Beautify Framing
    @Published var isBeautifyEnabled: Bool = false
    @Published var selectedGradientIndex: Int = 0
    @Published var beautifyPadding: CGFloat = 40.0
    
    // Canvas & Interaction State
    @Published var dragStart: CGPoint?
    @Published var currentDrag: CGPoint?
    @Published var currentPoints: [CGPoint] = []
    @Published var textInput: String = ""
    @Published var isShowingTextPrompt: Bool = false
    @Published var textPromptPosition: CGPoint = .zero
    
    @Published var statusMessage: String = ""
    
    init(image: NSImage) {
        self.baseImage = image
        self.blurredBaseImage = ImageProcessor.shared.generateObfuscatedImage(from: image)
    }
    
    /// Cắt phần ảnh đã được làm mờ đúng bằng kích thước vùng rect
    func cropBlurredImage(rect: CGRect, canvasSize: CGSize) -> NSImage? {
        guard let fullBlurred = blurredBaseImage, canvasSize.width > 0, canvasSize.height > 0 else { return nil }
        guard let cgImage = fullBlurred.cgImage(forProposedRect: nil, context: nil, hints: nil) ??
              (fullBlurred.tiffRepresentation.flatMap { NSBitmapImageRep(data: $0)?.cgImage }) else {
            return nil
        }
        
        let scaleX = CGFloat(cgImage.width) / canvasSize.width
        let scaleY = CGFloat(cgImage.height) / canvasSize.height
        
        let rawCropRect = CGRect(
            x: rect.origin.x * scaleX,
            y: rect.origin.y * scaleY,
            width: rect.width * scaleX,
            height: rect.height * scaleY
        )
        
        let imageBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        let cropRect = rawCropRect.intersection(imageBounds)
        
        guard !cropRect.isNull && cropRect.width > 0 && cropRect.height > 0 else { return nil }
        guard let cropped = cgImage.cropping(to: cropRect) else { return nil }
        
        return NSImage(cgImage: cropped, size: CGSize(width: cropRect.width / scaleX, height: cropRect.height / scaleY))
    }
    
    var currentNSColor: NSColor {
        NSColor(currentColor)
    }
    
    func undo() {
        guard let last = annotations.popLast() else { return }
        undoneAnnotations.append(last)
        if last.type == .stepNumber && nextStepNumber > 1 {
            nextStepNumber -= 1
        }
    }
    
    func redo() {
        guard let next = undoneAnnotations.popLast() else { return }
        annotations.append(next)
        if next.type == .stepNumber {
            nextStepNumber += 1
        }
    }
    
    func clearAll() {
        annotations.removeAll()
        undoneAnnotations.removeAll()
        nextStepNumber = 1
    }
    
    /// Xuất ảnh hoàn chỉnh bao gồm tất cả các nét vẽ và khung nền thẩm mỹ nếu có
    func renderFinalImage() -> NSImage {
        let size = baseImage.size
        guard size.width > 0 && size.height > 0 else { return baseImage }
        
        let scaleX = canvasSize.width > 0 ? (size.width / canvasSize.width) : 1.0
        let scaleY = canvasSize.height > 0 ? (size.height / canvasSize.height) : 1.0
        
        // Vẽ với hệ tọa độ flipped: true (gốc trên-trái, tương thích 1:1 với SwiftUI)
        let rendered = NSImage(size: size, flipped: true) { [weak self] bounds in
            guard let self = self, let context = NSGraphicsContext.current?.cgContext else { return false }
            
            // 1. Vẽ ảnh gốc (tự động đúng chiều trong flipped context)
            self.baseImage.draw(in: bounds)
            
            // 2. Vẽ các Annotation lên ảnh
            for item in self.annotations {
                self.drawItem(item, in: context, imageSize: size, scaleX: scaleX, scaleY: scaleY)
            }
            
            return true
        }
        
        var canvasImage: NSImage = rendered
        if let tiff = rendered.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) {
            let bitmapImage = NSImage(size: size)
            bitmapImage.addRepresentation(rep)
            canvasImage = bitmapImage
        }
        
        // 3. Nếu bật chế độ làm đẹp (Beautify Framing)
        if isBeautifyEnabled {
            let preset = GradientPreset.presets[selectedGradientIndex % GradientPreset.presets.count]
            let watermark = PreferencesManager.shared.watermarkEnabled ? PreferencesManager.shared.watermarkText : nil
            canvasImage = ImageProcessor.shared.beautifyImage(
                canvasImage,
                padding: beautifyPadding,
                cornerRadius: 16.0,
                shadowRadius: 24.0,
                gradient: preset,
                watermark: watermark
            )
        }
        
        return canvasImage
    }
    
    private func drawItem(_ item: AnnotationItem, in context: CGContext, imageSize: CGSize, scaleX: CGFloat, scaleY: CGFloat) {
        context.saveGState()
        context.setStrokeColor(item.color.cgColor)
        context.setFillColor(item.color.cgColor)
        context.setLineWidth(max(1.0, item.lineWidth * scaleX))
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        let scaledRect = CGRect(
            x: item.rect.origin.x * scaleX,
            y: item.rect.origin.y * scaleY,
            width: max(1.0, item.rect.size.width * scaleX),
            height: max(1.0, item.rect.size.height * scaleY)
        )
        
        switch item.type {
        case .select:
            break
            
        case .arrow:
            let start = CGPoint(x: item.startPoint.x * scaleX, y: item.startPoint.y * scaleY)
            let end = CGPoint(x: item.endPoint.x * scaleX, y: item.endPoint.y * scaleY)
            drawArrow(from: start, to: end, in: context, width: max(1.0, item.lineWidth * scaleX))
            
        case .rectangle:
            context.stroke(scaledRect)
            
        case .oval:
            context.strokeEllipse(in: scaledRect)
            
        case .pen:
            guard item.points.count > 1 else { break }
            context.beginPath()
            context.move(to: CGPoint(x: item.points[0].x * scaleX, y: item.points[0].y * scaleY))
            for pt in item.points.dropFirst() {
                context.addLine(to: CGPoint(x: pt.x * scaleX, y: pt.y * scaleY))
            }
            context.strokePath()
            
        case .stepNumber:
            let center = CGPoint(x: item.startPoint.x * scaleX, y: item.startPoint.y * scaleY)
            let radius: CGFloat = max(14 * scaleX, item.lineWidth * 3.5 * scaleX)
            let circleRect = CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
            
            // Vẽ vòng tròn nền
            context.fillEllipse(in: circleRect)
            
            // Vẽ số bên trong
            let numText = "\(item.stepIndex)"
            let attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: radius * 1.1),
                .foregroundColor: NSColor.white
            ]
            let textSize = (numText as NSString).size(withAttributes: attr)
            let textOrigin = CGPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2)
            (numText as NSString).draw(at: textOrigin, withAttributes: attr)
            
        case .text:
            let text = item.text.isEmpty ? "Văn bản" : item.text
            let fontSize = max(16 * scaleX, item.lineWidth * 4 * scaleX)
            let attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: fontSize),
                .foregroundColor: item.color
            ]
            let origin = CGPoint(x: item.startPoint.x * scaleX, y: item.startPoint.y * scaleY)
            (text as NSString).draw(at: origin, withAttributes: attr)
            
        case .pixelate:
            // Phủ mờ vùng chọn bằng ảnh đã obfuscate thực tế
            let blurImg = blurredBaseImage ?? ImageProcessor.shared.generateObfuscatedImage(from: baseImage, scale: 18.0)
            if let blurImg = blurImg {
                context.saveGState()
                context.clip(to: scaledRect)
                blurImg.draw(in: CGRect(origin: .zero, size: imageSize))
                context.restoreGState()
                
                // Viền nhẹ phân tách vùng mờ
                context.setStrokeColor(NSColor.white.withAlphaComponent(0.3).cgColor)
                context.setLineWidth(max(1.0, 1.0 * scaleX))
                context.stroke(scaledRect)
            } else {
                context.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
                context.fill(scaledRect)
            }
            
        case .spotlight:
            // Vùng spotlight giữ sáng, xung quanh mờ
            context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
            let path = CGMutablePath()
            path.addRect(CGRect(origin: .zero, size: imageSize))
            path.addRect(scaledRect)
            context.addPath(path)
            context.drawPath(using: .eoFill)
        }
        
        context.restoreGState()
    }
    
    private func drawArrow(from start: CGPoint, to end: CGPoint, in context: CGContext, width: CGFloat) {
        // Thân mũi tên
        context.move(to: start)
        context.addLine(to: end)
        context.strokePath()
        
        // Đầu mũi tên
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = max(16.0, width * 4.0)
        let arrowAngle: CGFloat = .pi / 6
        
        let p1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        context.beginPath()
        context.move(to: end)
        context.addLine(to: p1)
        context.addLine(to: p2)
        context.closePath()
        context.fillPath()
    }
}

struct EditorView: View {
    @ObservedObject var viewModel: EditorViewModel
    @ObservedObject var prefs = PreferencesManager.shared
    let onClose: () -> Void
    
    let colorPalette: [Color] = [
        .red, .orange, .yellow, .green, .blue, .purple, .white, .black
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // MARK: - Top Toolbar
            editorToolbar
            
            Divider()
            
            // MARK: - Canvas Editor Workspace
            GeometryReader { geo in
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    
                    // Khung ảnh nền
                    Image(nsImage: viewModel.baseImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .overlay(
                            CanvasOverlayView(
                                viewModel: viewModel,
                                onTextRequested: { pos in
                                    viewModel.textPromptPosition = pos
                                    viewModel.textInput = ""
                                    viewModel.isShowingTextPrompt = true
                                }
                            )
                        )
                        .padding(20)
                }
            }
            
            Divider()
            
            // MARK: - Bottom Status & Action Bar
            editorBottomBar
        }
        .frame(minWidth: 850, minHeight: 600)
        .preferredColorScheme(prefs.appTheme.colorScheme)
        .sheet(isPresented: $viewModel.isShowingTextPrompt) {
            VStack(spacing: 16) {
                Text("Nhập văn bản chú thích")
                    .font(.headline)
                
                TextField("Nội dung chú thích...", text: $viewModel.textInput)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 320)
                
                HStack {
                    Button("Hủy") { viewModel.isShowingTextPrompt = false }
                    Button("Thêm") {
                        if !viewModel.textInput.isEmpty {
                            let item = AnnotationItem(
                                type: .text,
                                startPoint: viewModel.textPromptPosition,
                                endPoint: viewModel.textPromptPosition,
                                color: viewModel.currentNSColor,
                                lineWidth: viewModel.strokeWidth,
                                text: viewModel.textInput
                            )
                            viewModel.annotations.append(item)
                        }
                        viewModel.isShowingTextPrompt = false
                    }
                    .buttonStyle(BorderedProminentButtonStyle())
                }
            }
            .padding(24)
        }
    }
    
    // MARK: - Toolbar View
    private var editorToolbar: some View {
        HStack(spacing: 12) {
            // Nút chọn công cụ vẽ
            ForEach(AnnotationTool.allCases) { tool in
                Button(action: { viewModel.currentTool = tool }) {
                    Image(systemName: tool.rawValue)
                        .font(.system(size: 14, weight: .medium))
                        .frame(width: 32, height: 32)
                        .background(viewModel.currentTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(viewModel.currentTool == tool ? Color.accentColor : Color.clear, lineWidth: 1.5)
                        )
                }
                .buttonStyle(PlainButtonStyle())
                .help(tool.displayName)
            }
            
            Divider().frame(height: 24)
            
            // Bảng chọn màu sắc
            HStack(spacing: 6) {
                ForEach(colorPalette, id: \.self) { color in
                    Circle()
                        .fill(color)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle()
                                .stroke(viewModel.currentColor == color ? Color.primary : Color.gray.opacity(0.3), lineWidth: 2)
                        )
                        .onTapGesture {
                            viewModel.currentColor = color
                        }
                }
            }
            
            Divider().frame(height: 24)
            
            // Độ dày nét vẽ (Stroke Width)
            HStack(spacing: 8) {
                Text("Nét:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Picker("", selection: $viewModel.strokeWidth) {
                    Text("Nhỏ").tag(CGFloat(2.0))
                    Text("Vừa").tag(CGFloat(4.0))
                    Text("Dày").tag(CGFloat(8.0))
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 140)
            }
            
            Spacer()
            
            // Nút bật làm đẹp ảnh (Beautify Framing)
            Toggle(isOn: $viewModel.isBeautifyEnabled) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .foregroundColor(.yellow)
                    Text("Khung viền")
                        .font(.caption)
                }
            }
            .toggleStyle(.button)
            
            if viewModel.isBeautifyEnabled {
                Picker("", selection: $viewModel.selectedGradientIndex) {
                    ForEach(0..<GradientPreset.presets.count, id: \.self) { idx in
                        Text(GradientPreset.presets[idx].name).tag(idx)
                    }
                }
                .frame(width: 130)
            }
            
            Divider().frame(height: 24)
            
            // Undo / Redo
            Button(action: { viewModel.undo() }) {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(viewModel.annotations.isEmpty)
            .help("Hoàn tác (⌘Z)")
            
            Button(action: { viewModel.redo() }) {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(viewModel.undoneAnnotations.isEmpty)
            .help("Làm lại (⇧⌘Z)")
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Bottom Bar View
    private var editorBottomBar: some View {
        HStack {
            Text("\(Int(viewModel.baseImage.size.width)) × \(Int(viewModel.baseImage.size.height)) px")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if !viewModel.statusMessage.isEmpty {
                Text("• \(viewModel.statusMessage)")
                    .font(.caption)
                    .foregroundColor(.accentColor)
            }
            
            Spacer()
            
            // Nhận diện chữ OCR
            Button(action: {
                OCRManager.shared.recognizeAndCopyText(from: viewModel.baseImage) { text in
                    if let t = text {
                        viewModel.statusMessage = L10n.tr(.editorCopiedChars(t.count))
                    } else {
                        viewModel.statusMessage = L10n.tr(.editorNoText)
                    }
                }
            }) {
                Label(L10n.tr(.editorOCR), systemImage: "text.viewfinder")
            }
            .buttonStyle(BorderedButtonStyle())
            
            // Sao chép ảnh hoàn thiện
            Button(action: {
                let finalImage = viewModel.renderFinalImage()
                ScreenCaptureManager.shared.copyImageToClipboard(finalImage)
                NotificationHUDController.shared.show(
                    icon: "doc.on.doc.fill",
                    title: L10n.tr(.editorCopiedImage),
                    message: "Đã sao chép ảnh vào Clipboard",
                    isSuccess: true
                )
                onClose()
            }) {
                Label(L10n.tr(.editorCopy), systemImage: "doc.on.doc")
            }
            .keyboardShortcut("c", modifiers: .command)
            .buttonStyle(BorderedButtonStyle())
            
            // Lưu ảnh
            Button(action: {
                let finalImage = viewModel.renderFinalImage()
                let url = PreferencesManager.shared.generateTimestampedFilename(prefix: "Edited")
                if ScreenCaptureManager.shared.saveImage(finalImage, to: url) {
                    viewModel.statusMessage = L10n.tr(.editorSavedImage)
                }
            }) {
                Label(L10n.tr(.editorSave), systemImage: "square.and.arrow.down")
            }
            .buttonStyle(BorderedProminentButtonStyle())
            
            // Đóng
            Button(L10n.tr(.editorClose), action: onClose)
                .buttonStyle(PlainButtonStyle())
                .foregroundColor(.secondary)
                .padding(.leading, 8)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

// MARK: - Canvas Interactive Overlay
struct CanvasOverlayView: View {
    @ObservedObject var viewModel: EditorViewModel
    let onTextRequested: (CGPoint) -> Void
    
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Lớp nhận cử chỉ chuột trong suốt phủ toàn bộ ảnh
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let loc = value.location
                                if viewModel.dragStart == nil {
                                    viewModel.dragStart = loc
                                    if viewModel.currentTool == .pen {
                                        viewModel.currentPoints = [loc]
                                    }
                                }
                                viewModel.currentDrag = loc
                                if viewModel.currentTool == .pen {
                                    viewModel.currentPoints.append(loc)
                                }
                            }
                            .onEnded { value in
                                guard let start = viewModel.dragStart else { return }
                                let end = value.location
                                
                                switch viewModel.currentTool {
                                case .stepNumber:
                                    let item = AnnotationItem(
                                        type: .stepNumber,
                                        startPoint: end,
                                        endPoint: end,
                                        color: viewModel.currentNSColor,
                                        lineWidth: viewModel.strokeWidth,
                                        stepIndex: viewModel.nextStepNumber
                                    )
                                    viewModel.annotations.append(item)
                                    viewModel.nextStepNumber += 1
                                    
                                case .text:
                                    onTextRequested(end)
                                    
                                case .pen:
                                    let item = AnnotationItem(
                                        type: .pen,
                                        startPoint: start,
                                        endPoint: end,
                                        points: viewModel.currentPoints,
                                        color: viewModel.currentNSColor,
                                        lineWidth: viewModel.strokeWidth
                                    )
                                    viewModel.annotations.append(item)
                                    viewModel.currentPoints.removeAll()
                                    
                                default:
                                    if abs(end.x - start.x) > 3 || abs(end.y - start.y) > 3 {
                                        let item = AnnotationItem(
                                            type: viewModel.currentTool,
                                            startPoint: start,
                                            endPoint: end,
                                            color: viewModel.currentNSColor,
                                            lineWidth: viewModel.strokeWidth
                                        )
                                        viewModel.annotations.append(item)
                                    }
                                }
                                
                                viewModel.dragStart = nil
                                viewModel.currentDrag = nil
                            }
                    )
                
                // Hiển thị các nét vẽ đã hoàn thành (không chặn sự kiện chuột)
                ForEach(viewModel.annotations) { item in
                    AnnotationItemView(
                        item: item,
                        viewModel: viewModel,
                        canvasSize: geo.size,
                        isPreview: false
                    )
                    .allowsHitTesting(false)
                }
                
                // Hiển thị nét vẽ xem trước khi đang kéo chuột (không chặn sự kiện chuột)
                if let start = viewModel.dragStart, let curr = viewModel.currentDrag, viewModel.currentTool != .pen && viewModel.currentTool != .stepNumber {
                    AnnotationItemView(
                        item: AnnotationItem(
                            type: viewModel.currentTool,
                            startPoint: start,
                            endPoint: curr,
                            color: viewModel.currentNSColor,
                            lineWidth: viewModel.strokeWidth
                        ),
                        viewModel: viewModel,
                        canvasSize: geo.size,
                        isPreview: true
                    )
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                viewModel.canvasSize = geo.size
            }
            .onChange(of: geo.size) { newSize in
                viewModel.canvasSize = newSize
            }
        }
    }
}

struct AnnotationItemView: View {
    let item: AnnotationItem
    let viewModel: EditorViewModel
    var canvasSize: CGSize = .zero
    var isPreview: Bool = false
    
    var body: some View {
        Group {
            switch item.type {
            case .arrow:
                ArrowShape(start: item.startPoint, end: item.endPoint)
                    .stroke(Color(nsColor: item.color), lineWidth: item.lineWidth)
            case .rectangle:
                Path { path in
                    path.addRect(item.rect)
                }
                .stroke(Color(nsColor: item.color), lineWidth: item.lineWidth)
            case .oval:
                Path { path in
                    path.addEllipse(in: item.rect)
                }
                .stroke(Color(nsColor: item.color), lineWidth: item.lineWidth)
            case .stepNumber:
                ZStack {
                    Circle()
                        .fill(Color(nsColor: item.color))
                        .frame(width: max(26, item.lineWidth * 6), height: max(26, item.lineWidth * 6))
                    Text("\(item.stepIndex)")
                        .font(.system(size: max(14, item.lineWidth * 3.5), weight: .bold))
                        .foregroundColor(.white)
                }
                .position(item.startPoint)
            case .text:
                Text(item.text)
                    .font(.system(size: max(16, item.lineWidth * 4), weight: .bold))
                    .foregroundColor(Color(nsColor: item.color))
                    .position(item.startPoint)
            case .pixelate:
                let cropped = viewModel.cropBlurredImage(rect: item.rect, canvasSize: canvasSize)
                ZStack {
                    if let img = cropped {
                        Image(nsImage: img)
                            .resizable()
                    } else {
                        Rectangle()
                            .fill(Color.black.opacity(0.35))
                    }
                    
                    if isPreview {
                        Rectangle()
                            .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))
                    } else {
                        Rectangle()
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    }
                }
                .frame(width: max(1, item.rect.width), height: max(1, item.rect.height))
                .position(x: item.rect.midX, y: item.rect.midY)
            case .spotlight:
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: max(1, item.rect.width), height: max(1, item.rect.height))
                    .position(x: item.rect.midX, y: item.rect.midY)
            default:
                EmptyView()
            }
        }
    }
}

struct ArrowShape: Shape {
    let start: CGPoint
    let end: CGPoint
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: start)
        path.addLine(to: end)
        
        let angle = atan2(end.y - start.y, end.x - start.x)
        let arrowLength: CGFloat = 16.0
        let arrowAngle: CGFloat = .pi / 6
        
        let p1 = CGPoint(
            x: end.x - arrowLength * cos(angle - arrowAngle),
            y: end.y - arrowLength * sin(angle - arrowAngle)
        )
        let p2 = CGPoint(
            x: end.x - arrowLength * cos(angle + arrowAngle),
            y: end.y - arrowLength * sin(angle + arrowAngle)
        )
        
        path.move(to: end)
        path.addLine(to: p1)
        path.move(to: end)
        path.addLine(to: p2)
        
        return path
    }
}
