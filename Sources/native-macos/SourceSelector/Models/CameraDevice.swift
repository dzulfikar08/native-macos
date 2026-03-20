import AVFoundation
import AppKit
import Foundation

/// Represents a camera device with its capabilities
struct CameraDevice: Identifiable, Sendable {
    /// Unique device identifier
    let id: String  // device uniqueID

    /// Human-readable device name
    let name: String

    /// Camera position (front/back/unspecified)
    let position: AVCaptureDevice.Position?

    /// Supported video formats for this camera
    let supportedFormats: [VideoFormat]

    /// Thumbnail preview image (optional)
    var thumbnail: NSImage?

    /// Video format capabilities
    struct VideoFormat: Sendable {
        let resolution: CGSize
        let frameRates: [Float]
        let codec: FourCharCode
    }

    /// Enumerate all available video capture devices
    static func enumerateCameras() -> [CameraDevice] {
        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        let devices = discoverySession.devices
        return devices.compactMap { device in
            try? CameraDevice(from: device)
        }
    }

    /// Convenience initializer for testing
    init(id: String, name: String, position: AVCaptureDevice.Position?, supportedFormats: [VideoFormat]) {
        self.id = id
        self.name = name
        self.position = position
        self.supportedFormats = supportedFormats
    }

    /// Create CameraDevice from AVCaptureDevice
    init(from device: AVCaptureDevice) throws {
        self.id = device.uniqueID
        self.name = device.localizedName
        self.position = device.position

        // Extract supported formats
        self.supportedFormats = device.formats.map { format in
            // Extract format description
            let formatDescription = format.formatDescription

            // Get dimensions
            let dimensions = CMVideoFormatDescriptionGetDimensions(formatDescription)
            let resolution = CGSize(width: CGFloat(dimensions.width), height: CGFloat(dimensions.height))

            // Get supported frame ranges
            let frameRanges = format.videoSupportedFrameRateRanges
            let frameRates = frameRanges.compactMap { Float($0.maxFrameRate) }

            // Get codec type
            let codec = CMFormatDescriptionGetMediaSubType(formatDescription)

            return VideoFormat(resolution: resolution, frameRates: frameRates, codec: codec)
        }
    }

    /// Create AVCaptureDeviceInput for this camera
    func createCaptureInput() throws -> AVCaptureDeviceInput {
        guard let device = AVCaptureDevice(uniqueID: id) else {
            throw CameraError.deviceNotFound(id)
        }
        return try AVCaptureDeviceInput(device: device)
    }
}

enum CameraError: LocalizedError {
    case deviceNotFound(String)

    var errorDescription: String? {
        switch self {
        case .deviceNotFound(let id):
            return "Camera device '\(id)' not found"
        }
    }
}
