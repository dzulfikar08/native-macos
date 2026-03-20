import Foundation
import CoreMedia

/// LRU (Least Recently Used) cache for video thumbnails
actor ThumbnailCache {
    private var storage: [CMTime: Thumbnail] = [:]
    private var accessOrder: [CMTime] = []
    private let maxSize: Int

    /// Current number of items in cache
    var count: Int {
        storage.count
    }

    /// Initialize cache with maximum size
    /// - Parameter maxSize: Maximum number of thumbnails to cache
    init(maxSize: Int = 100) {
        self.maxSize = maxSize
    }

    /// Insert thumbnail into cache
    /// - Parameter thumbnail: Thumbnail to cache
    func insert(_ thumbnail: Thumbnail) {
        // Update access order for existing item
        if let existing = storage[thumbnail.time] {
            if let index = accessOrder.firstIndex(of: thumbnail.time) {
                accessOrder.remove(at: index)
            }
        }

        // Store thumbnail
        storage[thumbnail.time] = thumbnail
        accessOrder.append(thumbnail.time)

        // Evict least recently used if over capacity
        while storage.count > maxSize {
            let lruTime = accessOrder.removeFirst()
            storage.removeValue(forKey: lruTime)
        }
    }

    /// Retrieve thumbnail for specific time
    /// - Parameter time: Time to lookup
    /// - Returns: Cached thumbnail if available
    subscript(time: CMTime) -> Thumbnail? {
        get {
            guard let thumbnail = storage[time] else {
                return nil
            }

            // Update access order - this is now most recently used
            if let index = accessOrder.firstIndex(of: time) {
                accessOrder.remove(at: index)
            }
            accessOrder.append(time)

            return thumbnail
        }
    }

    /// Remove thumbnail for specific time
    /// - Parameter time: Time to remove
    func remove(_ time: CMTime) {
        storage.removeValue(forKey: time)
        if let index = accessOrder.firstIndex(of: time) {
            accessOrder.remove(at: index)
        }
    }

    /// Remove all thumbnails from cache
    func removeAll() {
        storage.removeAll()
        accessOrder.removeAll()
    }

    /// Check if thumbnail exists for time
    /// - Parameter time: Time to check
    /// - Returns: True if cached
    func contains(_ time: CMTime) -> Bool {
        storage[time] != nil
    }
}
