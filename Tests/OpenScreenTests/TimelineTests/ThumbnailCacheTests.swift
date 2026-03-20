import XCTest
import CoreMedia
import Metal
@testable import OpenScreen

final class ThumbnailCacheTests: XCTestCase {
    var cache: ThumbnailCache!
    var mockTexture: MTLTexture!

    override func setUp() {
        super.setUp()
        cache = ThumbnailCache(maxSize: 5)

        // Create a mock texture (will be nil in tests but that's OK for cache logic)
        mockTexture = nil
    }

    override func tearDown() {
        cache = nil
        mockTexture = nil
        super.tearDown()
    }

    func testInsertAndRetrieveThumbnail() async {
        // Test basic insert and retrieve
        let time = CMTime(seconds: 1.0, preferredTimescale: 600)
        let thumbnail = Thumbnail(id: UUID(), time: time, texture: mockTexture, isLoading: false)

        await cache.insert(thumbnail)
        let retrieved = await cache[time]

        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.time, time)
        XCTAssertEqual(retrieved?.isLoading, false)
    }

    func testLRUEviction() async {
        // Test that least recently used items are evicted when cache is full
        let times = [
            CMTime(seconds: 1.0, preferredTimescale: 600),
            CMTime(seconds: 2.0, preferredTimescale: 600),
            CMTime(seconds: 3.0, preferredTimescale: 600),
            CMTime(seconds: 4.0, preferredTimescale: 600),
            CMTime(seconds: 5.0, preferredTimescale: 600),
            CMTime(seconds: 6.0, preferredTimescale: 600)
        ]

        // Insert 6 items into cache with max size 5
        for time in times {
            let thumbnail = Thumbnail(id: UUID(), time: time, texture: mockTexture, isLoading: false)
            await cache.insert(thumbnail)
        }

        // First item should be evicted
        let firstItem = await cache[times[0]]
        XCTAssertNil(firstItem)

        // Last 5 items should be present
        for i in 1..<times.count {
            let item = await cache[times[i]]
            XCTAssertNotNil(item, "Item at index \(i) should be in cache")
        }
    }

    func testRemoveSpecificItem() async {
        // Test removing a specific item
        let time1 = CMTime(seconds: 1.0, preferredTimescale: 600)
        let time2 = CMTime(seconds: 2.0, preferredTimescale: 600)

        let thumbnail1 = Thumbnail(id: UUID(), time: time1, texture: mockTexture, isLoading: false)
        let thumbnail2 = Thumbnail(id: UUID(), time: time2, texture: mockTexture, isLoading: false)

        await cache.insert(thumbnail1)
        await cache.insert(thumbnail2)

        // Remove first item
        await cache.remove(time1)

        let item1 = await cache[time1]
        let item2 = await cache[time2]

        XCTAssertNil(item1)
        XCTAssertNotNil(item2)
    }

    func testClearAllItems() async {
        // Test clearing all items
        let times = [
            CMTime(seconds: 1.0, preferredTimescale: 600),
            CMTime(seconds: 2.0, preferredTimescale: 600),
            CMTime(seconds: 3.0, preferredTimescale: 600)
        ]

        for time in times {
            let thumbnail = Thumbnail(id: UUID(), time: time, texture: mockTexture, isLoading: false)
            await cache.insert(thumbnail)
        }

        await cache.removeAll()

        for time in times {
            let item = await cache[time]
            XCTAssertNil(item)
        }
    }

    func testCacheSizeLimit() async {
        // Test that cache respects size limit
        let initialCount = await cache.count
        XCTAssertEqual(initialCount, 0)

        for i in 0..<10 {
            let time = CMTime(seconds: Double(i), preferredTimescale: 600)
            let thumbnail = Thumbnail(id: UUID(), time: time, texture: mockTexture, isLoading: false)
            await cache.insert(thumbnail)
        }

        // Cache should not exceed max size
        let finalCount = await cache.count
        XCTAssertLessThanOrEqual(finalCount, 5)
    }
}
