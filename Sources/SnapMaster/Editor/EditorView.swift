import Foundation
import AppKit
import SwiftUI

final class EditorViewModel: ObservableObject {
    @Published var baseImage: NSImage
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
        var canvasImage = baseImage
        
        let size = canvasImage.size
        let rendered = NSImage(size: size)
        rendered.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            rendered.unlockFocus()
            return canvasImage
        }
        
        // 1. Vẽ ảnh gốc
        canvasImage.draw(in: CGRect(origin: .zero, size: size))
        
        // 2. Vẽ các Annotation lên ảnh
        for item in annotations {
            drawItem(item, in: context, imageSize: size)
        }
        
        rendered.unlockFocus()
        canvasImage = rendered
        
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
    
    private func drawItem(_ item: AnnotationItem, in context: CGContext, imageSize: CGSize) {
        context.saveGState()
        context.setStrokeColor(item.color.cgColor)
        context.setFillColor(item.color.cgColor)
        context.setLineWidth(item.lineWidth)
        context.setLineCap(.round)
        context.setLineJoin(.round)
        
        switch item.type {
        case .select:
            break
            
        case .arrow:
            drawArrow(from: item.startPoint, to: item.endPoint, in: context, width: item.lineWidth)
            
        case .rectangle:
            let rect = item.rect
            context.stroke(rect)
            
        case .oval:
            let rect = item.rect
            context.strokeEllipse(in: rect)
            
        case .pen:
            guard item.points.count > 1 else { break }
            context.beginPath()
            context.move(to: item.points[0])
            for pt in item.points.dropFirst() {
                context.addLine(to: pt)
            }
            context.strokePath()
            
        case .stepNumber:
            let center = item.startPoint
            let radius: CGFloat = max(14, item.lineWidth * 3.5)
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
            let textOrigin = CGPoint(x: center.x - textSize.width / 2, y: center.y - textSize.height / 2 + 1)
            (numText as NSString).draw(at: textOrigin, withAttributes: attr)
            
        case .text:
            let text = item.text.isEmpty ? "Văn bản" : item.text
            let attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.boldSystemFont(ofSize: max(16, item.lineWidth * 4)),
                .foregroundColor: item.color
            ]
            (text as NSString).draw(at: item.startPoint, withAttributes: attr)
            
        case .pixelate:
            // Phủ mờ ô vuông
            context.setFillColor(NSColor.black.withAlphaComponent(0.6).cgColor)
            context.fill(item.rect)
            let patternAttr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .bold),
                .foregroundColor: NSColor.white.withAlphaComponent(0.8)
            ]
            let label = "REDACTED"
            let lSize = (label as NSString).size(withAttributes: patternAttr)
            (label as NSString).draw(
                at: CGPoint(x: item.rect.midX - lSize.width / 2, y: item.rect.midY - lSize.height / 2),
                withAttributes: patternAttr
            )
            
        case .spotlight:
            // Vùng spotlight giữ sáng, xung quanh mờ
            context.setFillColor(NSColor.black.withAlphaComponent(0.5).cgColor)
            let path = CGMutablePath()
            path.addRect(CGRect(origin: .zero, size: imageSize))
            path.addRect(item.rect)
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
        let arrowLength: CGFloat = max(16, width * 4.0)
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
                viewModel.statusMessage = L10n.tr(.editorCopiedImage)
            }) {
                Label(L10n.tr(.editorCopy), systemImage: "doc.on.doc")
            }
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
            ZStack {
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
                
                // Hiển thị các nét vẽ đã hoàn thành
                ForEach(viewModel.annotations) { item in
                    AnnotationItemView(item: item)
                }
                
                // Hiển thị nét vẽ xem trước khi đang kéo chuột
                if let start = viewModel.dragStart, let curr = viewModel.currentDrag, viewModel.currentTool != .pen && viewModel.currentTool != .stepNumber {
                    AnnotationItemView(
                        item: AnnotationItem(
                            type: viewModel.currentTool,
                            startPoint: start,
                            endPoint: curr,
                            color: viewModel.currentNSColor,
                            lineWidth: viewModel.strokeWidth
                        )
                    )
                }
            }
        }
    }
}

struct AnnotationItemView: View {
    let item: AnnotationItem
    
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
                Rectangle()
                    .fill(Color.black.opacity(0.6))
                    .frame(width: item.rect.width, height: item.rect.height)
                    .position(x: item.rect.midX, y: item.rect.midY)
                    .overlay(
                        Text("REDACTED")
                            .font(.caption2.bold())
                            .foregroundColor(.white.opacity(0.8))
                            .position(x: item.rect.midX, y: item.rect.midY)
                    )
            case .spotlight:
                Rectangle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: item.rect.width, height: item.rect.height)
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
