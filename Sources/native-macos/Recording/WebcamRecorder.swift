@preconcurrency import AVFoundation
import CoreVideo
import Foundation

/// Records from webcams using AVCaptureSession + AVAssetWriter
@MainActor
final class WebcamRecorder: NSObject, Recorder {
    typealias Config = WebcamRecordingConfig

    /// Configuration for webcam recording
    struct WebcamRecordingConfig: Sendable {
        let cameras: [CameraDevice]
        let compositingMode: PipMode
        let videoSettings: VideoSettings
        let audioSettings: AudioSettings
        let codec: VideoCodec
    }

    /// Video quality settings
    struct VideoSettings: Sendable {
        var resolution: CGSize?
        var frameRate: Float?
        var bitrate: Int?
    }

    // MARK: - Properties

    nonisolated(unsafe) private let session: AVCaptureSession
    private let sessionQueue = DispatchQueue(label: "com.openscreen.webcam.session")
    private var videoOutputs: [Int: AVCaptureVideoDataOutput] = [:]
    private var audioOutput: AVCaptureAudioDataOutput?

    private var writer: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?

    private let audioMixer: AudioMixer
    private let pipCompositor: PipCompositor

    nonisolated(unsafe) private var frameBuffer: [Int: CVPixelBuffer] = [:]
    private var frameBufferQueue = DispatchQueue(label: "com.openscreen.webcam.buffer")
    private let maxBufferedFrames = 3  // 100ms at 30fps

    private var currentOutputURL: URL?
    private var currentConfig: Config?
    private var frameCount: Int = 0
    private var startTime: CMTime?

    // MARK: - Initialization

    override init() {
        self.session = AVCaptureSession()
        self.session.sessionPreset = .high

        self.audioMixer = AudioMixer()
        self.pipCompositor = PipCompositor()
    }

    // MARK: - Recorder Protocol

    var isRecording: Bool {
        writer?.status == .writing
    }

    func startRecording(to url: URL, config: Config) async throws {
        currentConfig = config
        currentOutputURL = url

        // Setup session
        try setupSession(with: config)

        // Setup writer
        try setupWriter(at: url, config: config)

        // Start session
        sessionQueue.async {
            self.session.startRunning()
        }

        // Wait for session to start
        try await Task.sleep(nanoseconds: 500_000_000)  // 0.5 seconds

        // Start writing
        writer?.startWriting()
        writer?.startSession(atSourceTime: CMTime.zero)
    }

    func stopRecording() async throws -> URL {
        // Stop session
        sessionQueue.async {
            self.session.stopRunning()
        }

        // Wait for session to stop
        try await Task.sleep(nanoseconds: 500_000_000)

        // Finish writing
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await writer?.finishWriting()

        guard let url = currentOutputURL else {
            throw RecordingError.recordingInterrupted
        }

        // Verify file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw RecordingError.recordingInterrupted
        }

        return url
    }

    // MARK: - Session Setup

    private func setupSession(with config: Config) throws {
        guard !config.cameras.isEmpty else {
            throw RecordingError.noCameraSelected
        }

        // Add camera inputs
        for (index, camera) in config.cameras.enumerated() {
            let input = try camera.createCaptureInput()

            guard session.canAddInput(input) else {
                throw RecordingError.cameraSetupFailed(camera.name)
            }

            session.addInput(input)

            // Add video output
            let output = AVCaptureVideoDataOutput()
            output.setSampleBufferDelegate(self, queue: sessionQueue)
            output.alwaysDiscardsLateVideoFrames = false

            guard session.canAddOutput(output) else {
                throw RecordingError.cameraSetupFailed(camera.name)
            }

            session.addOutput(output)
            videoOutputs[index] = output
        }

        // Add audio capture if enabled
        if config.audioSettings.microphoneEnabled {
            guard let microphone = AVCaptureDevice.default(for: .audio) else {
                print("⚠️ No microphone available")
                return
            }

            let micInput = try AVCaptureDeviceInput(device: microphone)

            guard session.canAddInput(micInput) else {
                print("⚠️ Cannot add microphone input")
                return
            }

            session.addInput(micInput)

            // Add audio output
            let audioOutput = AVCaptureAudioDataOutput()
            audioOutput.setSampleBufferDelegate(self, queue: sessionQueue)

            guard session.canAddOutput(audioOutput) else {
                print("⚠️ Cannot add audio output")
                return
            }

            session.addOutput(audioOutput)
            self.audioOutput = audioOutput

            // Update audio mixer settings
            audioMixer.updateSettings(config.audioSettings)
        }

        // TODO: System audio capture (requires AVAudioEngine tap - separate setup)
    }

    // MARK: - Writer Setup

    private func setupWriter(at url: URL, config: Config) throws {
        // Remove existing file
        try? FileManager.default.removeItem(at: url)

        writer = try AVAssetWriter(outputURL: url, fileType: .mov)

        // Setup video input
        let resolution = config.videoSettings.resolution ?? CGSize(width: 1920, height: 1080)

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: config.codec.avCodecKey,
            AVVideoWidthKey: resolution.width,
            AVVideoHeightKey: resolution.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: config.videoSettings.bitrate ?? 10_000_000,
                AVVideoProfileLevelKey: config.codec.profileLevel ?? ""
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        guard let videoInput = videoInput, writer?.canAdd(videoInput) == true else {
            throw RecordingError.writerSetupFailed
        }

        writer?.add(videoInput)

        // Setup pixel buffer adaptor
        let adaptorOptions: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32ARGB,
            kCVPixelBufferWidthKey as String: resolution.width,
            kCVPixelBufferHeightKey as String: resolution.height
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput,
            sourcePixelBufferAttributes: adaptorOptions
        )

        // Setup audio input if enabled
        if config.audioSettings.microphoneEnabled || config.audioSettings.systemAudioEnabled {
            let audioSettings: [String: Any] = [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVNumberOfChannelsKey: 2,
                AVSampleRateKey: 48000,
                AVEncoderBitRateKey: 128000
            ]

            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true

            guard let audioInput = audioInput, writer?.canAdd(audioInput) == true else {
                throw RecordingError.writerSetupFailed
            }

            writer?.add(audioInput)
        }
    }

    // MARK: - Public Accessors

    var captureSession: AVCaptureSession? {
        session
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate & AVCaptureAudioDataOutputSampleBufferDelegate

extension WebcamRecorder: AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        // Check if this is video or audio output
        if output is AVCaptureVideoDataOutput {
            // Get frame timestamp
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

            // Suppress concurrency warning: we know CVPixelBuffer is safe to pass here
            nonisolated(unsafe) let unsafeBuffer = pixelBuffer
            nonisolated(unsafe) let unsafeOutput = output

            // Copy the buffer data we need
            Task { @MainActor in
                // Find which camera this frame came from
                let index = self.videoOutputs.first(where: { $0.value === unsafeOutput })?.key
                await self.handleVideoFrame(pixelBuffer: unsafeBuffer, timestamp: timestamp, cameraIndex: index)
            }
        } else if output is AVCaptureAudioDataOutput {
            // Suppress concurrency warning for sample buffer
            nonisolated(unsafe) let unsafeBuffer = sampleBuffer

            // For audio, we'll process directly without Task
            Task { @MainActor in
                // Process immediately on main actor
                await self.handleAudioFrameDirect(unsafeBuffer)
            }
        }
    }

    private func handleVideoFrame(pixelBuffer: CVPixelBuffer, timestamp: CMTime, cameraIndex: Int?) async {
        guard let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData,
              let index = cameraIndex,
              let config = currentConfig else {
            return
        }

        if startTime == nil {
            startTime = timestamp
        }

        // Buffer frame for compositing
        await frameBufferQueue.sync {
            self.frameBuffer[index] = pixelBuffer

            // Limit buffer size
            if self.frameBuffer.count > self.maxBufferedFrames {
                if let oldestIndex = self.frameBuffer.keys.min() {
                    self.frameBuffer.removeValue(forKey: oldestIndex)
                }
            }

            // Check if we have frames from all cameras
            guard self.frameBuffer.count == config.cameras.count else {
                return
            }

            // Compose frame
            Task { @MainActor in
                await self.composeAndWriteFrame(at: timestamp)
            }
        }
    }

    private func composeAndWriteFrame(at timestamp: CMTime) async {
        guard let config = currentConfig,
              let adaptor = pixelBufferAdaptor,
              let writer = writer else {
            return
        }

        // Create output buffer
        let resolution = config.videoSettings.resolution ?? CGSize(width: 1920, height: 1080)

        guard let outputBuffer = pixelBufferPool(
            width: Int(resolution.width),
            height: Int(resolution.height),
            pixelFormat: kCVPixelFormatType_32ARGB
        ) else {
            return
        }

        // Compose frame
        do {
            try pipCompositor.composeFrame(
                buffers: frameBuffer,
                into: outputBuffer,
                mode: config.compositingMode
            )

            // Write frame
            let presentationTime = timestamp
            adaptor.append(outputBuffer, withPresentationTime: presentationTime)

            frameCount += 1

            // Clear buffer after writing
            frameBuffer.removeAll()
        } catch {
            print("⚠️ Frame composition failed: \(error)")
        }
    }

    private func pixelBufferPool(
        width: Int,
        height: Int,
        pixelFormat: OSType
    ) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let options: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: pixelFormat,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            width,
            height,
            pixelFormat,
            options as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
            return nil
        }

        return buffer
    }

    private func handleAudioFrameDirect(_ sampleBuffer: CMSampleBuffer) async {
        guard let audioInput = audioInput,
              audioInput.isReadyForMoreMediaData else {
            return
        }

        // Process through mixer
        // For now, write directly
        // TODO: Integrate with AudioMixer for system + mic mixing
        audioInput.append(sampleBuffer)
    }
}
