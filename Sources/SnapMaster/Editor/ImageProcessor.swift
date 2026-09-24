import Foundation
import AppKit
import CoreImage
import CoreGraphics

struct GradientPreset {
    let name: String
    let startColor: NSColor
    let endColor: NSColor
    
    static let presets: [GradientPreset] = [
        GradientPreset(
            name: "Ocean Blue",
            startColor: NSColor(red: 0.12, green: 0.45, blue: 0.95, alpha: 1.0),
            endColor: NSColor(red: 0.05, green: 0.15, blue: 0.45, alpha: 1.0)
        ),
        GradientPreset(
            name: "Sunset Purple",
            startColor: NSColor(red: 0.95, green: 0.25, blue: 0.45, alpha: 1.0),
            endColor: NSColor(red: 0.45, green: 0.15, blue: 0.75, alpha: 1.0)
        ),
        GradientPreset(
            name: "Emerald Glow",
            startColor: NSColor(red: 0.1, green: 0.75, blue: 0.55, alpha: 1.0),
            endColor: NSColor(red: 0.05, green: 0.35, blue: 0.35, alpha: 1.0)
        ),
        GradientPreset(
            name: "Dark Obsidian",
            startColor: NSColor(red: 0.18, green: 0.18, blue: 0.22, alpha: 1.0),
            endColor: NSColor(red: 0.08, green: 0.08, blue: 0.1, alpha: 1.0)
        ),
        GradientPreset(
            name: "Minimalist Gray",
            startColor: NSColor(red: 0.92, green: 0.93, blue: 0.95, alpha: 1.0),
            endColor: NSColor(red: 0.82, green: 0.84, blue: 0.88, alpha: 1.0)
        )
    ]
}

final class ImageProcessor {
    static let shared = ImageProcessor()
    private let ciContext = CIContext()
    
    private init() {}
    
    /// Áp dụng bộ lọc Pixelate (che mờ ô vuông) lên vùng chỉ định trên ảnh
    func applyPixelate(to image: NSImage, targetRect: CGRect, scale: CGFloat = 12.0) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        
        let filter = CIFilter(name: "CIPixellate")
        filter?.setValue(ciImage, forKey: kCIInputImageKey)
        filter?.setValue(scale, forKey: kCIInputScaleKey)
        
        guard let outputCI = filter?.outputImage,
              let fullPixelatedCG = ciContext.createCGImage(outputCI, from: ciImage.extent) else {
            return nil
        }
        
        // Hòa trộn: Chỉ áp dụng pixelate lên vùng targetRect
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: cgImage.width,
            height: cgImage.height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }
        
        let fullBounds = CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height)
        context.draw(cgImage, in: fullBounds)
        
        // Vẽ phần pixelated trong targetRect
        context.saveGState()
        context.clip(to: targetRect)
        context.draw(fullPixelatedCG, in: fullBounds)
        context.restoreGState()
        
        guard let finalCG = context.makeImage() else { return nil }
        return NSImage(cgImage: finalCG, size: image.size)
    }
    
    /// Thêm khung nền thẩm mỹ (Gradient, bo góc tròn, đổ bóng đẹp mắt như CleanShot / Xnapper)
    func beautifyImage(
        _ originalImage: NSImage,
        padding: CGFloat = 40.0,
        cornerRadius: CGFloat = 16.0,
        shadowRadius: CGFloat = 20.0,
        gradient: GradientPreset = GradientPreset.presets[0],
        watermark: String? = nil
    ) -> NSImage {
        let origSize = originalImage.size
        let newWidth = origSize.width + padding * 2
        let newHeight = origSize.height + padding * 2
        let newSize = NSSize(width: newWidth, height: newHeight)
        
        let resultImage = NSImage(size: newSize)
        resultImage.lockFocus()
        
        guard let context = NSGraphicsContext.current?.cgContext else {
            resultImage.unlockFocus()
            return originalImage
        }
        
        // 1. Vẽ nền Gradient
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let colors = [gradient.startColor.cgColor, gradient.endColor.cgColor] as CFArray
        let locations: [CGFloat] = [0.0, 1.0]
        if let cgGradient = CGGradient(colorsSpace: colorSpace, colors: colors, locations: locations) {
            context.drawLinearGradient(
                cgGradient,
                start: CGPoint(x: 0, y: newHeight),
                end: CGPoint(x: newWidth, y: 0),
                options: []
            )
        }
        
        // 2. Vẽ ảnh gốc có bo góc và đổ bóng
        context.saveGState()
        context.setShadow(
            offset: CGSize(width: 0, height: -10),
            blur: shadowRadius,
            color: NSColor.black.withAlphaComponent(0.4).cgColor
        )
        
        let imageRect = CGRect(x: padding, y: padding, width: origSize.width, height: origSize.height)
        let clipPath = CGPath(roundedRect: imageRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        
        context.addPath(clipPath)
        context.clip()
        
        originalImage.draw(in: imageRect, from: .zero, operation: .sourceOver, fraction: 1.0)
        context.restoreGState()
        
        // 3. Vẽ Watermark cá nhân hóa nếu có
        if let wm = watermark, !wm.isEmpty {
            let attr: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 11, weight: .medium),
                .foregroundColor: NSColor.white.withAlphaComponent(0.7)
            ]
            let size = (wm as NSString).size(withAttributes: attr)
            (wm as NSString).draw(at: CGPoint(x: newWidth - size.width - 16, y: 12), withAttributes: attr)
        }
        
        resultImage.unlockFocus()
        return resultImage
    }
}
