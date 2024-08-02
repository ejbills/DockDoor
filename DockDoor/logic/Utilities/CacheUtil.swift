import CoreGraphics
import Defaults
import Foundation

/// Cache item structure for storing captured window images.
struct CachedImage {
    let image: CGImage
    let timestamp: Date
}

final class CacheUtil {
    private static var imageCache: [CGWindowID: CachedImage] = [:]
    private static let cacheQueue = DispatchQueue(label: "com.dockdoor.cacheQueue", attributes: .concurrent)
    private static var cacheExpirySeconds: Double = Defaults[.screenCaptureCacheLifespan]
    
    /// Clears expired cache items based on cache expiry time.
    static func clearExpiredCache() {
        let now = Date()
        cacheQueue.async(flags: .barrier) {
            imageCache = imageCache.filter { now.timeIntervalSince($0.value.timestamp) <= cacheExpirySeconds }
        }
    }
    
    /// Resets the image and icon cache.
    static func resetCache() {
        cacheQueue.async(flags: .barrier) {
            imageCache.removeAll()
        }
    }
    
    static func getCachedImage(for windowID: CGWindowID) -> CGImage? {
        if let cachedImage = imageCache[windowID], Date().timeIntervalSince(cachedImage.timestamp) <= cacheExpirySeconds {
            return cachedImage.image
        }
        return nil
    }
    
    static func setCachedImage(for windowID: CGWindowID, image: CGImage){
        imageCache[windowID] = CachedImage(image: image, timestamp: Date())
    }
}
