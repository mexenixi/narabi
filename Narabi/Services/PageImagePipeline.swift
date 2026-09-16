import Foundation
import PDFKit
import SwiftUI
import UIKit

/// Single source of truth for page-image normalization.
/// UI cell backgrounds and paper placement are never baked into working image data.
nonisolated enum PageImagePipeline {
    static func baseImage(for page: ProjectPage) -> UIImage? {
        if let data = page.editBaseData, let image = UIImage(data: data) { return image }
        return UIImage(data: page.renderedData) ?? UIImage(data: page.originalData)
    }

    static func displayedImage(for page: ProjectPage) -> UIImage? {
        guard let base = baseImage(for: page) else { return nil }
        return cropped(base, insets: page.cropInsets)
    }

    static func cropped(_ image: UIImage, insets: PageCropInsets) -> UIImage {
        let left = min(max(insets.left, 0), 0.95)
        let right = min(max(insets.right, 0), 0.95 - left)
        let top = min(max(insets.top, 0), 0.95)
        let bottom = min(max(insets.bottom, 0), 0.95 - top)
        guard left + right > 0.0001 || top + bottom > 0.0001,
            let cg = normalizedOrientation(image).cgImage
        else { return normalizedOrientation(image) }
        let w = CGFloat(cg.width)
        let h = CGFloat(cg.height)
        let rect = CGRect(
            x: w * left, y: h * top, width: max(1, w * (1 - left - right)),
            height: max(1, h * (1 - top - bottom))
        ).integral
        guard let cut = cg.cropping(to: rect) else { return normalizedOrientation(image) }
        return UIImage(cgImage: cut, scale: 1, orientation: .up)
    }
    static let projectMaximumLongEdge: CGFloat = 1400
    static let pdfMaximumLongEdge: CGFloat = 1697

    static func normalizedOrientation(_ image: UIImage) -> UIImage {
        guard image.imageOrientation != .up else { return image }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !hasAlpha(image)
        return UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: image.size))
        }
    }

    static func hasAlpha(_ image: UIImage) -> Bool {
        guard let alpha = image.cgImage?.alphaInfo else { return false }
        switch alpha {
        case .first, .last, .premultipliedFirst, .premultipliedLast:
            return true
        default:
            return false
        }
    }

    static func resizedPreservingContent(_ input: UIImage, maximumLongEdge: CGFloat) -> UIImage {
        let image = normalizedOrientation(input)
        guard maximumLongEdge > 0 else { return image }
        let longest = max(image.size.width, image.size.height)
        guard longest > maximumLongEdge else { return image }
        let scale = maximumLongEdge / max(longest, 1)
        let target = CGSize(
            width: max(1, floor(image.size.width * scale)),
            height: max(1, floor(image.size.height * scale))
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = !hasAlpha(image)
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }

    static func workingData(
        from image: UIImage, maximumLongEdge: CGFloat = projectMaximumLongEdge, jpegQuality: CGFloat = 0.82
    ) -> Data? {
        let resized = resizedPreservingContent(image, maximumLongEdge: maximumLongEdge)
        return hasAlpha(resized) ? resized.pngData() : resized.jpegData(compressionQuality: jpegQuality)
    }

    static func editedData(from image: UIImage) -> Data? {
        let normalized = normalizedOrientation(image)
        return hasAlpha(normalized) ? normalized.pngData() : normalized.jpegData(compressionQuality: 0.90)
    }

    static func image(for page: PDFPage) -> UIImage? {
        let bounds = page.bounds(for: .mediaBox)
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let scale = pdfMaximumLongEdge / max(bounds.width, bounds.height)
        let target = CGSize(
            width: max(1, floor(bounds.width * scale)),
            height: max(1, floor(bounds.height * scale))
        )
        return page.thumbnail(of: target, for: .mediaBox)
    }

    static func opaqueImage(_ image: UIImage, background: UIColor = .white) -> UIImage {
        let normalized = normalizedOrientation(image)
        if !hasAlpha(normalized) { return normalized }
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: normalized.size, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: normalized.size))
            normalized.draw(in: CGRect(origin: .zero, size: normalized.size))
        }
    }
}

/// Standard reusable zoom viewer. It never changes output placement values.
struct StandardZoomImageView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.delegate = context.coordinator
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 8
        scroll.bouncesZoom = true
        scroll.backgroundColor = .clear

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.isUserInteractionEnabled = true
        scroll.addSubview(imageView)
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        context.coordinator.imageView = imageView
        context.coordinator.scrollView = scroll
        let tap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        tap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(tap)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
        scroll.setZoomScale(scroll.minimumZoomScale, animated: false)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let scale: CGFloat = 2.5
                let point = gesture.location(in: imageView)
                let size = CGSize(
                    width: scrollView.bounds.width / scale, height: scrollView.bounds.height / scale)
                scrollView.zoom(
                    to: CGRect(
                        x: point.x - size.width / 2, y: point.y - size.height / 2, width: size.width,
                        height: size.height), animated: true)
            }
        }
    }
}
