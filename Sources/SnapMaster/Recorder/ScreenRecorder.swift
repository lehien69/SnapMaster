import Foundation
import AppKit
import ScreenCaptureKit
import AVFoundation

final class ScreenRecorder: NSObject, ObservableObject {
    static let shared = ScreenRecorder()
    
    @Published var isRecording: Bool = false
    @Published var isPaused: Bool = false
    
    private var stream: SCStream?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var currentVideoURL: URL?
    
    private let videoQueue = DispatchQueue(label: "com.snapmaster.recorder.video")
    private let audioQueue = DispatchQueue(label: "com.snapmaster.recorder.audio")
    
    private var sessionStarted = false
    private var firstSampleTime: CMTime = .zero
    
    var onRecordingFinished: ((URL) -> Void)?
    
    override private init() {
        super.init()
    }
    
    func startRecording(displayID: CGDirectDisplayID = CGMainDisplayID()) async throws {
        guard !isRecording else { return }
        
        let outputURL = PreferencesManager.shared.generateTimestampedFilename(prefix: "Recording", ext: "mp4")
        self.currentVideoURL = outputURL
        
        // 1. Lấy thông tin màn hình từ ScreenCaptureKit
        let shareableContent = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let display = shareableContent.displays.first(where: { $0.displayID == displayID }) ?? shareableContent.displays.first else {
            throw NSError(domain: "SnapMaster", code: 404, userInfo: [NSLocalizedDescriptionKey: "Không tìm thấy màn hình hiển thị"])
        }
        
        let filter = SCContentFilter(display: display, excludingWindows: [])
        
        // 2. Cấu hình luồng quay
        let config = SCStreamConfiguration()
        config.width = display.width * 2
        config.height = display.height * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
        config.showsCursor = true
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2
        
        // 3. Khởi tạo AVAssetWriter để ghi file MP4
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        
        // Video Settings (H.264)
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: config.width,
            AVVideoHeightKey: config.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: 8_000_000,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]
        
        let vInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        vInput.expectsMediaDataInRealTime = true
        if writer.canAdd(vInput) {
            writer.add(vInput)
        }
        self.videoInput = vInput
        
        // Audio Settings (AAC)
        let audioSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 48000,
            AVEncoderBitRateKey: 128000
        ]
        
        let aInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        aInput.expectsMediaDataInRealTime = true
        if writer.canAdd(aInput) {
            writer.add(aInput)
        }
        self.audioInput = aInput
        
        self.assetWriter = writer
        self.sessionStarted = false
        
        // 4. Bắt đầu luồng ScreenCaptureKit
        let newStream = SCStream(filter: filter, configuration: config, delegate: nil)
        try newStream.addStreamOutput(self, type: .screen, sampleHandlerQueue: videoQueue)
        try newStream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        
        try await newStream.startCapture()
        self.stream = newStream
        
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = true
            self?.isPaused = false
        }
    }
    
    func pauseRecording() {
        isPaused = true
    }
    
    func resumeRecording() {
        isPaused = false
    }
    
    func stopRecording() async {
        guard isRecording else { return }
        
        if let s = stream {
            try? await s.stopCapture()
            self.stream = nil
        }
        
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()
        
        await withCheckedContinuation { continuation in
            assetWriter?.finishWriting {
                continuation.resume()
            }
        }
        
        let videoURL = self.currentVideoURL
        DispatchQueue.main.async { [weak self] in
            self?.isRecording = false
            self?.isPaused = false
            if let url = videoURL {
                self?.onRecordingFinished?(url)
            }
        }
    }
}

extension ScreenRecorder: SCStreamOutput {
    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid, !isPaused else { return }
        
        let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
        
        if !sessionStarted {
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: pts)
            firstSampleTime = pts
            sessionStarted = true
        }
        
        switch type {
        case .screen:
            if videoInput?.isReadyForMoreMediaData == true {
                videoInput?.append(sampleBuffer)
            }
        case .audio, .microphone:
            if audioInput?.isReadyForMoreMediaData == true {
                audioInput?.append(sampleBuffer)
            }
        @unknown default:
            break
        }
    }
}
