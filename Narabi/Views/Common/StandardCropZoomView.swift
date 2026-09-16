import SwiftUI
import UIKit

struct StandardCropZoomView: UIViewRepresentable {
    let image: UIImage
    let cropInsets: UIEdgeInsets

    func makeCoordinator() -> Coordinator { Coordinator() }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.backgroundColor = .black
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 8
        scroll.bouncesZoom = true
        scroll.alwaysBounceVertical = false
        scroll.alwaysBounceHorizontal = false
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false
        scroll.delegate = context.coordinator

        let canvas = CropOverlayCanvas()
        canvas.translatesAutoresizingMaskIntoConstraints = false
        scroll.addSubview(canvas)
        NSLayoutConstraint.activate([
            canvas.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            canvas.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            canvas.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            canvas.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            canvas.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
            canvas.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
        context.coordinator.canvas = canvas
        context.coordinator.scroll = scroll
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        canvas.configure(image: image, cropInsets: cropInsets)
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.canvas?.configure(image: image, cropInsets: cropInsets)
    }
    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var canvas: CropOverlayCanvas?
        weak var scroll: UIScrollView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { canvas }
        func scrollViewDidZoom(_ scrollView: UIScrollView) { center(scrollView) }
        private func center(_ scroll: UIScrollView) {
            let horizontal = max(0, (scroll.bounds.width - scroll.contentSize.width) / 2)
            let vertical = max(0, (scroll.bounds.height - scroll.contentSize.height) / 2)
            scroll.contentInset = UIEdgeInsets(
                top: vertical, left: horizontal, bottom: vertical, right: horizontal)
        }
        @objc func doubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scroll else { return }
            if scroll.zoomScale > scroll.minimumZoomScale + 0.01 {
                scroll.setZoomScale(scroll.minimumZoomScale, animated: true)
            } else {
                let point = gesture.location(in: canvas)
                let scale: CGFloat = 2.5
                let w = scroll.bounds.width / scale
                let h = scroll.bounds.height / scale
                scroll.zoom(
                    to: CGRect(x: point.x - w / 2, y: point.y - h / 2, width: w, height: h), animated: true)
            }
        }
    }
}

final class CropOverlayCanvas: UIView {
    private let imageView = UIImageView()
    private var cropInsets = UIEdgeInsets.zero
    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .black
        imageView.contentMode = .scaleAspectFit
        imageView.frame = bounds
        imageView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(imageView)
        isUserInteractionEnabled = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    func configure(image: UIImage, cropInsets: UIEdgeInsets) {
        imageView.image = image
        self.cropInsets = cropInsets
        setNeedsDisplay()
    }
    override func draw(_ rect: CGRect) {
        guard let image = imageView.image else { return }
        let scale = min(bounds.width / max(image.size.width, 1), bounds.height / max(image.size.height, 1))
        let size = CGSize(width: image.size.width * scale, height: image.size.height * scale)
        let fit = CGRect(
            x: (bounds.width - size.width) / 2, y: (bounds.height - size.height) / 2, width: size.width,
            height: size.height)
        let crop = CGRect(
            x: fit.minX + fit.width * cropInsets.left,
            y: fit.minY + fit.height * cropInsets.top,
            width: fit.width * max(0.001, 1 - cropInsets.left - cropInsets.right),
            height: fit.height * max(0.001, 1 - cropInsets.top - cropInsets.bottom))
        let shade = UIBezierPath(rect: fit)
        shade.append(UIBezierPath(rect: crop))
        shade.usesEvenOddFillRule = true
        UIColor.black.withAlphaComponent(0.48).setFill()
        shade.fill()
        let border = UIBezierPath(rect: crop)
        border.lineWidth = 3
        border.setLineDash([10, 7], count: 2, phase: 0)
        UIColor.systemYellow.setStroke()
        border.stroke()
    }
}
