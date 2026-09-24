import Foundation
import AppKit
import Vision
import CoreImage
import ImageIO

final class OCRManager {
    static let shared = OCRManager()
    
    private var isWarmedUp = false
    
    private init() {}
    
    /// Trích xuất CGImage từ NSImage với độ sắc nét cao nhất
    private func getCGImage(from image: NSImage) -> CGImage? {
        if let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return cg
        }
        guard let tiffData = image.tiffRepresentation,
              let source = CGImageSourceCreateWithData(tiffData as CFData, nil) else {
            return nil
        }
        return CGImageSourceCreateImageAtIndex(source, 0, nil)
    }
    
    /// Khởi động ấm mô hình Vision trên luồng nền lúc khởi động app
    /// Giúp lần quét đầu tiên của người dùng chạy ngay lập tức (< 0.1s) thay vì bị lag
    func warmUp() {
        guard !isWarmedUp else { return }
        isWarmedUp = true
        
        DispatchQueue.global(qos: .background).async {
            let dummySize = 16
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            guard let ctx = CGContext(
                data: nil,
                width: dummySize,
                height: dummySize,
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return }
            
            ctx.setFillColor(NSColor.white.cgColor)
            ctx.fill(CGRect(x: 0, y: 0, width: dummySize, height: dummySize))
            guard let dummyCG = ctx.makeImage() else { return }
            
            let req = VNRecognizeTextRequest()
            req.recognitionLevel = .fast
            let handler = VNImageRequestHandler(cgImage: dummyCG, options: [:])
            try? handler.perform([req])
            
            let reqAccurate = VNRecognizeTextRequest()
            reqAccurate.recognitionLevel = .accurate
            reqAccurate.recognitionLanguages = ["vi-VN", "en-US"]
            let handlerAccurate = VNImageRequestHandler(cgImage: dummyCG, options: [:])
            try? handlerAccurate.perform([reqAccurate])
        }
    }
    
    /// Nhận diện văn bản từ ảnh và tự động copy vào Clipboard
    func recognizeAndCopyText(from image: NSImage, completion: ((String?) -> Void)? = nil) {
        recognizeText(from: image) { recognizedText in
            guard let text = recognizedText, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                completion?(nil)
                return
            }
            
            // Sao chép văn bản nhận diện được vào Clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(text, forType: .string)
            
            completion?(text)
        }
    }
    
    /// Chạy OCR trực tiếp trên CGImage (cho BarcodeManager fallback gọi)
    func performDirectOCR(on cgImage: CGImage) -> String? {
        if let text = performOCR(on: cgImage, level: .accurate, useCorrection: true), !text.isEmpty {
            return text
        }
        if let text = performOCR(on: cgImage, level: .accurate, useCorrection: false), !text.isEmpty {
            return text
        }
        if let text = performOCR(on: cgImage, level: .fast, useCorrection: false), !text.isEmpty {
            return text
        }
        return nil
    }
    
    /// Quét văn bản từ ảnh qua quy trình Multi-Pass chuyên sâu (như TextSniper & CleanShot X)
    func recognizeText(from image: NSImage, completion: @escaping (String?) -> Void) {
        guard let cgImage = getCGImage(from: image) else {
            completion(nil)
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Pass 1: Nhận diện chính xác cao có từ điển tiếng Việt & tiếng Anh
            if let text = self.performOCR(on: cgImage, level: .accurate, useCorrection: true), !text.isEmpty {
                DispatchQueue.main.async { completion(text) }
                return
            }
            
            // Pass 2: Nhận diện chính xác KHÔNG dùng sửa lỗi từ điển (rất tốt cho URL, Code, Mật khẩu, ID, Số điện thoại)
            if let text = self.performOCR(on: cgImage, level: .accurate, useCorrection: false), !text.isEmpty {
                DispatchQueue.main.async { completion(text) }
                return
            }
            
            // Pass 3: Nhận diện siêu tốc (.fast)
            if let text = self.performOCR(on: cgImage, level: .fast, useCorrection: false), !text.isEmpty {
                DispatchQueue.main.async { completion(text) }
                return
            }
            
            // Pass 4: Phóng to 2x nội suy chất lượng cao nếu ảnh quá nhỏ (< 140px)
            if cgImage.width < 140 || cgImage.height < 60 {
                if let upscaled = self.upscale(cgImage: cgImage, scale: 2.0) {
                    if let text = self.performOCR(on: upscaled, level: .accurate, useCorrection: false), !text.isEmpty {
                        DispatchQueue.main.async { completion(text) }
                        return
                    }
                }
            }
            
            // Pass 5 (Smart Fallback): Nếu người dùng quét trúng mã QR bằng tính năng OCR, tự động đọc mã QR!
            let req = VNDetectBarcodesRequest()
            if #available(macOS 12.0, *) {
                if let supported = try? req.supportedSymbologies() {
                    req.symbologies = supported
                }
            }
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            if (try? handler.perform([req])) != nil, let barcodes = req.results, !barcodes.isEmpty {
                let payloads = barcodes.compactMap { $0.payloadStringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if !payloads.isEmpty {
                    let result = payloads.joined(separator: "\n")
                    DispatchQueue.main.async { completion(result) }
                    return
                }
            }
            
            DispatchQueue.main.async { completion(nil) }
        }
    }
    
    private func performOCR(on cgImage: CGImage, level: VNRequestTextRecognitionLevel, useCorrection: Bool) -> String? {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = level
        request.usesLanguageCorrection = useCorrection
        if #available(macOS 13.0, *) {
            request.automaticallyDetectsLanguage = true
        }
        request.recognitionLanguages = ["vi-VN", "en-US"]
        
        let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try requestHandler.perform([request])
            guard let observations = request.results, !observations.isEmpty else {
                return nil
            }
            
            var fullText = ""
            for observation in observations {
                if let candidate = observation.topCandidates(1).first {
                    fullText += candidate.string + "\n"
                }
            }
            let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        } catch {
            return nil
        }
    }
    
    private func upscale(cgImage: CGImage, scale: CGFloat) -> CGImage? {
        let newWidth = Int(CGFloat(cgImage.width) * scale)
        let newHeight = Int(CGFloat(cgImage.height) * scale)
        guard let ctx = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        ctx.interpolationQuality = .high
        ctx.draw(cgImage, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        return ctx.makeImage()
    }
}
