@preconcurrency import UIKit

nonisolated final class WorkspaceThumbnailLoader: @unchecked Sendable {
    static let shared = WorkspaceThumbnailLoader()
    private let cache: NSCache<NSString, UIImage> = {
        let value = NSCache<NSString, UIImage>()
        value.totalCostLimit = 24 * 1024 * 1024
        value.countLimit = 96
        return value
    }()
    private let queue: OperationQueue = {
        let value = OperationQueue()
        value.name = "com.mexenixi.narabi.workspace-thumbnails"
        value.qualityOfService = .userInitiated
        value.maxConcurrentOperationCount = 2
        return value
    }()
    private let lock = NSLock()
    private var callbacks: [String: [(UIImage?) -> Void]] = [:]
    private init() {}
    func cachedImage(for key: String) -> UIImage? { cache.object(forKey: key as NSString) }
    func request(
        page: ProjectPage, key: String, maximumPixel: CGFloat, completion: @escaping (UIImage?) -> Void
    ) {
        if let image = cachedImage(for: key) {
            completion(image)
            return
        }
        lock.lock()
        if callbacks[key] != nil {
            callbacks[key]?.append(completion)
            lock.unlock()
            return
        }
        callbacks[key] = [completion]
        lock.unlock()
        queue.addOperation { [weak self] in
            guard let self else { return }
            let image = autoreleasepool {
                ExportService.workspaceThumbnail(for: page, maximumPixel: maximumPixel)
            }
            if let image {
                let scale = max(image.scale, 1)
                cache.setObject(
                    image, forKey: key as NSString,
                    cost: Int(image.size.width * scale * image.size.height * scale * 4))
            }
            lock.lock()
            let handlers = callbacks.removeValue(forKey: key) ?? []
            lock.unlock()
            DispatchQueue.main.async { handlers.forEach { $0(image) } }
        }
    }
    func prefetch(page: ProjectPage, key: String, maximumPixel: CGFloat) {
        guard cachedImage(for: key) == nil else { return }
        request(page: page, key: key, maximumPixel: maximumPixel) { _ in }
    }
    func removeAll() {
        queue.cancelAllOperations()
        lock.lock()
        callbacks.removeAll()
        lock.unlock()
        cache.removeAllObjects()
    }
}
