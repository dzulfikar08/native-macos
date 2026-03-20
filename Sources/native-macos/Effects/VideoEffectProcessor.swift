// native-macos/Sources/native-macos/Effects/VideoEffectProcessor.swift
import Foundation
import CoreImage
import AVFoundation
import Metal

/// Core Image-based real-time video effect processor.
///
/// Provides GPU-accelerated video effect processing using Core Image filters.
/// Supports both synchronous and asynchronous processing for optimal performance.
@MainActor
final class VideoEffectProcessor {
    // MARK: - Properties

    private var filterCache: [String: CIFilter] = [:]
    private let ciContext: CIContext
    private let processingQueue = DispatchQueue(label: "video.effect.processing", qos: .userInteractive)

    // MARK: - Initialization

    init() {
        // Create GPU-accelerated context for real-time performance
        let options: [CIContextOption: Any] = [
            .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
            .useSoftwareRenderer: false  // Use GPU
        ]
        ciContext = CIContext(options: options)
    }

    // MARK: - Public Methods

    /// Apply effects to image synchronously.
    ///
    /// - Parameters:
    ///   - image: The input image to process
    ///   - effects: Array of video effects to apply
    /// - Returns: Processed image, or nil if processing fails
    func applyEffects(to image: CIImage, effects: [VideoEffect]) -> CIImage? {
        var processedImage = image

        for effect in effects where effect.isEnabled {
            guard let filter = getOrCreateFilter(for: effect) else { continue }
            filter.setValue(processedImage, forKey: kCIInputImageKey)
            processedImage = filter.outputImage ?? processedImage
        }

        return processedImage
    }

    /// Apply effects asynchronously for real-time preview.
    ///
    /// - Parameters:
    ///   - pixelBuffer: The input pixel buffer to process
    ///   - effects: Array of video effects to apply
    ///   - completion: Handler called with processed image on main queue
    func applyEffectsAsync(
        to pixelBuffer: CVPixelBuffer,
        effects: [VideoEffect],
        completion: @escaping (CIImage?) -> Void
    ) {
        processingQueue.async { [weak self] in
            guard let self = self else { return }

            let image = CIImage(cvPixelBuffer: pixelBuffer)
            let processed = self.applyEffects(to: image, effects: effects)

            DispatchQueue.main.async {
                completion(processed)
            }
        }
    }

    /// Clear filter cache when effect stack changes significantly.
    ///
    /// Call this method when adding, removing, or significantly modifying effects
    /// to ensure fresh filter instances are created.
    func invalidateFilterCache() {
        filterCache.removeAll()
    }

    // MARK: - Private Methods

    private func getOrCreateFilter(for effect: VideoEffect) -> CIFilter? {
        let cacheKey = "\(effect.type.rawValue)-\(effect.id.uuidString)"

        if let cached = filterCache[cacheKey] {
            return cached
        }

        let filter: CIFilter?
        switch effect.type {
        case .brightness, .contrast, .saturation:
            filter = CIFilter(name: "CIColorControls")
            if let f = filter {
                configureFilter(f, for: effect)
                filterCache[cacheKey] = f
            }
        }

        return filter
    }

    private func configureFilter(_ filter: CIFilter, for effect: VideoEffect) {
        switch effect.parameters {
        case .brightness(let value):
            filter.setValue(value, forKey: kCIInputBrightnessKey)
        case .contrast(let value):
            filter.setValue(value, forKey: kCIInputContrastKey)
        case .saturation(let value):
            filter.setValue(value, forKey: kCIInputSaturationKey)
        }
    }
}
