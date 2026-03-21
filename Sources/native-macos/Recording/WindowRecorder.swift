import Foundation
import AVFoundation
import CoreGraphics
import AppKit

/// Records individual windows using Core Graphics capture
@MainActor
final class WindowRecorder: Recorder {
    struct Config: Sendable {
        let windowIDs: [CGWindowID]
        let settings: WindowRecordingSettings
    }

    private var captureSession: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var captureTimer: Timer?
    private var frameBuffer: [CGWindowID: [CGImage]] = [:]
    private var isPaused = false
    private var consecutiveFailures: [CGWindowID: Int] = [:]
    private var startTime = CMTime.zero
    private var frameCount = 0

    private var _isRecording = false
    var isRecording: Bool { _isRecording }

    private let ciContext = CIContext()

    func startRecording(to url: URL, config: Config) async throws {
        guard config.settings.isValid else {
            throw WindowError.invalidSettings
        }

        // Setup AVAssetWriter
        let outputSettings: [String: Any] = [
            AVVideoCodecKey: config.settings.codec.avCodecKey,
            AVVideoWidthKey: config.settings.qualityPreset.resolution!.width,
            AVVideoHeightKey: config.settings.qualityPreset.resolution!.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.settings.qualityPreset.bitrate ?? 10_000_000
            ]
        ]

        captureSession = try AVAssetWriter(outputURL: url, fileType: .mov)
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: outputSettings)
        videoInput?.expectsMediaDataInRealTime = true

        let pixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: config.settings.qualityPreset.resolution!.width,
            kCVPixelBufferHeightKey as String: config.settings.qualityPreset.resolution!.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: pixelBufferAttributes
        )

        guard let videoInput = videoInput, captureSession?.canAdd(videoInput) == true else {
            throw WindowError.recordingNotActive
        }

        captureSession?.add(videoInput)

        // Start session
        captureSession?.startWriting()
        captureSession?.startSession(atSourceTime: .zero)

        _isRecording = true
        consecutiveFailures.removeAll()

        // Start capture loop
        startCaptureLoop(config: config)
    }

    func stopRecording() async throws -> URL {
        guard let session = captureSession else {
            throw WindowError.recordingNotActive
        }

        // Stop capture loop
        captureTimer?.invalidate()
        captureTimer = nil

        // Finish session
        videoInput?.markAsFinished()
        await session.finishWriting()

        _isRecording = false

        let outputURL = session.outputURL

        // Verify file exists
        guard FileManager.default.fileExists(atPath: outputURL.path) else {
            throw WindowError.outputFileNotFound
        }

        return outputURL
    }

    // MARK: - Private

    private func startCaptureLoop(config: Config) {
        let fps = config.settings.qualityPreset.framerate
        let interval = 1.0 / Double(fps)

        captureTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.captureFrame(config: config)
            }
        }
    }

    private func captureFrame(config: Config) async {
        guard !isPaused else { return }

        var frames: [CGWindowID: CGImage] = [:]

        // Capture each window
        for windowID in config.windowIDs {
            guard let bounds = queryWindowBounds(windowID),
                  let image = captureWindowImage(windowID, bounds: bounds) else {
                consecutiveFailures[windowID, default: 0] += 1

                // Stop recording after 10 consecutive failures for any window
                if consecutiveFailures[windowID] ?? 0 >= 10 {
                    await stopRecordingForUnavailableWindow(windowID)
                }
                continue
            }

            consecutiveFailures[windowID] = 0
            frames[windowID] = image
        }

        guard !frames.isEmpty else { return }

        // Composite if multiple windows
        let finalImage: CGImage
        if frames.count > 1 {
            finalImage = await composeWindows(frames, mode: config.settings.compositingMode, outputSize: config.settings.qualityPreset.resolution!)
        } else if let singleFrame = frames.values.first {
            finalImage = singleFrame
        } else {
            return
        }

        // Encode frame
        await encodeFrame(finalImage, fps: config.settings.qualityPreset.framerate)
    }

    private func queryWindowBounds(_ windowID: CGWindowID) -> CGRect? {
        guard let windowList = CGWindowListCopyWindowInfo(.optionIncludingWindow, windowID) as? [[String: Any]] else {
            return nil
        }

        guard let windowInfo = windowList.first,
              let boundsDict = windowInfo[kCGWindowBounds as String] as? [String: Any] else {
            return nil
        }

        guard let x = boundsDict["X"] as? CGFloat,
              let y = boundsDict["Y"] as? CGFloat,
              let width = boundsDict["Width"] as? CGFloat,
              let height = boundsDict["Height"] as? CGFloat else {
            return nil
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    private func captureWindowImage(_ windowID: CGWindowID, bounds: CGRect) -> CGImage? {
        guard let image = CGWindowListCreateImage(
            .null,
            .optionIncludingWindow,
            windowID,
            .boundsIgnoreFraming
        ) else {
            return nil
        }

        return image
    }

    private func composeWindows(_ frames: [CGWindowID: CGImage], mode: PipMode, outputSize: CGSize) async -> CGImage {
        let compositor = PipCompositor()
        let sortedWindowIDs = Array(frames.keys).sorted()

        let context = CGContext(
            data: nil,
            width: Int(outputSize.width),
            height: Int(outputSize.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        )!

        context.setFillColor(CGColor.black)
        context.fill(CGRect(origin: .zero, size: outputSize))

        for (index, windowID) in sortedWindowIDs.enumerated() {
            guard let image = frames[windowID] else { continue }

            let rect = compositor.calculateRect(for: index, mode: mode, in: outputSize)
            context.draw(image, in: rect)
        }

        return context.makeImage()!
    }

    private func stopRecordingForUnavailableWindow(_ windowID: CGWindowID) async {
        // Pause recording when window unavailable
        isPaused = true
        captureTimer?.invalidate()

        // In production, would trigger notification to UI
        print("⚠️ Window \(windowID) unavailable, pausing recording")

        // Note: Actual pause/resume with WindowTracker integration
        // happens in Chunk 3 with UI implementation
    }

    private func encodeFrame(_ image: CGImage, fps: Float) async {
        guard let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else {
            return
        }

        let presentationTime = CMTime(
            seconds: Double(frameCount) / Double(fps),
            preferredTimescale: 600
        )

        guard let pixelBuffer = createPixelBuffer(from: image) else {
            return
        }

        pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: presentationTime)
        frameCount += 1
    }

    private func createPixelBuffer(from image: CGImage) -> CVPixelBuffer? {
        let width = image.width
        let height = image.height

        let attributes: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            kCVPixelFormatType_32ARGB,
            attributes as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else {
            return nil
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        return buffer
    }
}

enum WindowError: LocalizedError {
    case invalidSettings
    case recordingNotActive
    case outputFileNotFound
    case windowUnavailable(CGWindowID)

    var errorDescription: String? {
        switch self {
        case .invalidSettings:
            return "Recording settings are invalid"
        case .recordingNotActive:
            return "No recording is currently active"
        case .outputFileNotFound:
            return "Could not locate output file"
        case .windowUnavailable(let id):
            return "Window \(id) is no longer available"
        }
    }
}
