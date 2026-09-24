import Foundation
import AppKit
import Vision
import CoreImage
import ImageIO

struct BarcodeResult {
    let payload: String
    let symbology: String
    let boundingBox: CGRect
}

final class BarcodeManager {
    static let shared = BarcodeManager()
    
    private let ciContext = CIContext()
    
    private init() {}
    
    // MARK: - URL Detection (TextSniper Parity)
    
    /// Kiểm tra chuỗi có phải là URL hợp lệ không (dùng NSDataDetector & URLComponents như TextSniper)
    static func extractURL(from string: String) -> URL? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        if let url = URL(string: trimmed), let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" {
            return url
        }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let matches = detector.matches(in: trimmed, options: [], range: NSRange(location: 0, length: trimmed.utf16.count))
            if let first = matches.first, let url = first.url {
                return url
            }
        }
        return nil
    }
    
    /// Trích xuất CGImage từ NSImage một cách nguyên bản không bị suy giảm độ phân giải Retina
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
    
    /// Quét tất cả mã QR / Barcode có trong ảnh qua quy trình Multi-Pass chuyên sâu
    func scanBarcodes(from image: NSImage, completion: @escaping ([BarcodeResult]) -> Void) {
        guard let cgImage = getCGImage(from: image) else {
            completion([])
            return
        }
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            
            // Pass 1: Quét trực tiếp trên ảnh gốc
            if let results = self.detectBarcodes(in: cgImage), !results.isEmpty {
                DispatchQueue.main.async { completion(results) }
                return
            }
            
            // Pass 2: Thêm khoảng trắng viền xung quanh (Quiet Zone) - Rất quan trọng khi khoanh sát viền mã
            if let padded = self.addWhitePadding(to: cgImage, padding: 24) {
                if let results = self.detectBarcodes(in: padded), !results.isEmpty {
                    DispatchQueue.main.async { completion(results) }
                    return
                }
            }
            
            // Pass 3: Đảo ngược màu sắc (CIColorInvert) để nhận diện mã QR nền tối / Dark Mode
            if let inverted = self.invertColors(cgImage: cgImage) {
                if let results = self.detectBarcodes(in: inverted), !results.isEmpty {
                    DispatchQueue.main.async { completion(results) }
                    return
                }
                
                if let paddedInverted = self.addWhitePadding(to: inverted, padding: 24) {
                    if let results = self.detectBarcodes(in: paddedInverted), !results.isEmpty {
                        DispatchQueue.main.async { completion(results) }
                        return
                    }
                }
            }
            
            // Pass 4: Phóng to 2x chất lượng cao nếu ảnh crop nhỏ (< 160px)
            if cgImage.width < 160 || cgImage.height < 160 {
                if let upscaled = self.upscale(cgImage: cgImage, scale: 2.0) {
                    if let results = self.detectBarcodes(in: upscaled), !results.isEmpty {
                        DispatchQueue.main.async { completion(results) }
                        return
                    }
                    if let paddedUpscaled = self.addWhitePadding(to: upscaled, padding: 30) {
                        if let results = self.detectBarcodes(in: paddedUpscaled), !results.isEmpty {
                            DispatchQueue.main.async { completion(results) }
                            return
                        }
                    }
                }
            }
            
            // Pass 5 (Smart Fallback): Nếu người dùng quét trúng vùng chữ thay vì mã QR, tự động trích xuất chữ!
            if let fallbackText = OCRManager.shared.performDirectOCR(on: cgImage), !fallbackText.isEmpty {
                let fallbackResult = BarcodeResult(
                    payload: fallbackText,
                    symbology: "Văn bản (OCR)",
                    boundingBox: .zero
                )
                DispatchQueue.main.async { completion([fallbackResult]) }
                return
            }
            
            DispatchQueue.main.async { completion([]) }
        }
    }
    
    /// Quét mã đầu tiên và tự động copy vào Clipboard
    func scanFirstBarcodeAndCopy(from image: NSImage, completion: @escaping (BarcodeResult?) -> Void) {
        scanBarcodes(from: image) { results in
            guard let first = results.first else {
                completion(nil)
                return
            }
            
            // Nếu có nhiều mã được tìm thấy, nối các payload lại bằng dấu xuống dòng (TextSniper parity)
            let combined = results.count > 1 ? results.map { $0.payload }.joined(separator: "\n") : first.payload
            
            // Tự động sao chép nội dung quét được vào Clipboard
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(combined, forType: .string)
            
            let finalResult = BarcodeResult(
                payload: combined,
                symbology: first.symbology,
                boundingBox: first.boundingBox
            )
            completion(finalResult)
        }
    }
    
    // MARK: - Core Vision Detection
    private func detectBarcodes(in cgImage: CGImage) -> [BarcodeResult]? {
        let request = VNDetectBarcodesRequest()
        
        // Sử dụng toàn bộ symbologies được hệ điều hành hỗ trợ
        if #available(macOS 12.0, *) {
            if let supported = try? request.supportedSymbologies() {
                request.symbologies = supported
            }
        } else {
            request.symbologies = [
                .qr,
                .ean13,
                .ean8,
                .code128,
                .code39,
                .code93,
                .upce,
                .aztec,
                .dataMatrix,
                .pdf417,
                .itf14
            ]
        }
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        do {
            try handler.perform([request])
            guard let results = request.results, !results.isEmpty else { return nil }
            
            let detected = results.compactMap { obs -> BarcodeResult? in
                guard let payload = self.extractPayload(from: obs) else { return nil }
                
                var symbologyName = "Mã vạch"
                if obs.symbology == .qr {
                    symbologyName = "Mã QR"
                } else if obs.symbology == .ean13 || obs.symbology == .ean8 {
                    symbologyName = "EAN Barcode"
                } else if obs.symbology == .code128 || obs.symbology == .code39 {
                    symbologyName = "Code 128/39"
                } else if obs.symbology == .dataMatrix {
                    symbologyName = "DataMatrix"
                } else if obs.symbology == .aztec {
                    symbologyName = "Aztec"
                } else if obs.symbology == .pdf417 {
                    symbologyName = "PDF417"
                }
                
                return BarcodeResult(
                    payload: payload,
                    symbology: symbologyName,
                    boundingBox: obs.boundingBox
                )
            }
            
            return detected.isEmpty ? nil : detected
        } catch {
            return nil
        }
    }
    
    /// Trích xuất toàn bộ dữ liệu có thể có từ Observation (String, UTF-8, Latin1, ASCII)
    private func extractPayload(from observation: VNBarcodeObservation) -> String? {
        // 1. Chuỗi chuỗi đã giải mã trực tiếp
        if let str = observation.payloadStringValue, !str.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return str.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        
        // 2. Dữ liệu nhị phân payloadData (macOS 14.0+)
        if #available(macOS 14.0, *) {
            if let data = observation.payloadData, !data.isEmpty {
                if let str = String(data: data, encoding: .utf8), !str.isEmpty {
                    return str.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let str = String(data: data, encoding: .isoLatin1), !str.isEmpty {
                    return str.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                if let str = String(data: data, encoding: .ascii), !str.isEmpty {
                    return str.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return nil
    }
    
    // MARK: - Image Helpers
    private func addWhitePadding(to image: CGImage, padding: CGFloat) -> CGImage? {
        let padInt = Int(padding)
        let newWidth = image.width + (padInt * 2)
        let newHeight = image.height + (padInt * 2)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue
        
        guard let ctx = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else { return nil }
        
        ctx.setFillColor(NSColor.white.cgColor)
        ctx.fill(CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        ctx.draw(image, in: CGRect(x: padding, y: padding, width: CGFloat(image.width), height: CGFloat(image.height)))
        return ctx.makeImage()
    }
    
    private func invertColors(cgImage: CGImage) -> CGImage? {
        let filter = CIFilter(name: "CIColorInvert")
        filter?.setValue(CIImage(cgImage: cgImage), forKey: kCIInputImageKey)
        guard let outCI = filter?.outputImage else { return nil }
        return ciContext.createCGImage(outCI, from: outCI.extent)
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
