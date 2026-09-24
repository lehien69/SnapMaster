import Foundation
import AppKit
import AVFoundation
import ImageIO
import UniformTypeIdentifiers

final class GIFExporter {
    static let shared = GIFExporter()
    
    private init() {}
    
    /// Chuyển đổi video MP4 thành ảnh động GIF tối ưu
    func convertVideoToGIF(
        videoURL: URL,
        outputURL: URL,
        fps: Int = 10,
        scaleWidth: CGFloat = 640,
        completion: @escaping (Bool) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let asset = AVAsset(url: videoURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: scaleWidth, height: 0)
            
            let durationSeconds = CMTimeGetSeconds(asset.duration)
            guard durationSeconds > 0 else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let frameInterval = 1.0 / Double(fps)
            var times: [NSValue] = []
            var currentTime: Double = 0
            while currentTime < durationSeconds {
                times.append(NSValue(time: CMTime(seconds: currentTime, preferredTimescale: 600)))
                currentTime += frameInterval
            }
            
            guard let destination = CGImageDestinationCreateWithURL(
                outputURL as CFURL,
                UTType.gif.identifier as CFString,
                times.count,
                nil
            ) else {
                DispatchQueue.main.async { completion(false) }
                return
            }
            
            let gifProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFLoopCount as String: 0
                ]
            ]
            CGImageDestinationSetProperties(destination, gifProperties as CFDictionary)
            
            let frameProperties: [String: Any] = [
                kCGImagePropertyGIFDictionary as String: [
                    kCGImagePropertyGIFDelayTime as String: frameInterval
                ]
            ]
            
            for timeValue in times {
                let time = timeValue.timeValue
                if let cgImage = try? generator.copyCGImage(at: time, actualTime: nil) {
                    CGImageDestinationAddImage(destination, cgImage, frameProperties as CFDictionary)
                }
            }
            
            let success = CGImageDestinationFinalize(destination)
            DispatchQueue.main.async {
                completion(success)
            }
        }
    }
}
