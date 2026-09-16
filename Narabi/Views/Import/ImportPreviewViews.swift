import PDFKit
import SwiftUI
import UIKit

struct ImportPreviewItem: Identifiable {
    let id = UUID()
    let data: Data
    let kind: ImportItem.Kind
    let title: String
}

struct ImportItemPreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let item: ImportPreviewItem

    var body: some View {
        NavigationStack {
            Group {
                switch item.kind {
                case .pdf:
                    ZoomablePDFPreview(data: item.data)

                case .image:
                    if let image = UIImage(data: item.data) {
                        ZoomableImagePreview(image: image)
                    } else {
                        ContentUnavailableView(
                            L10n.text("common.unavailable", "表示できません"),
                            systemImage: "exclamationmark.triangle"
                        )
                    }
                }
            }
            .background(Color.black)
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("common.back", "戻る")) {
                        dismiss()
                    }
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
}

struct ZoomablePDFPreview: UIViewRepresentable {
    let data: Data

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.backgroundColor = .black
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.usePageViewController(false)
        view.document = PDFDocument(data: data)
        return view
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        if uiView.document?.dataRepresentation() != data {
            uiView.document = PDFDocument(data: data)
        }
    }
}

struct ZoomableImagePreview: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = .black
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.bouncesZoom = true

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)

        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
        ])

        context.coordinator.imageView = imageView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        context.coordinator.scrollView = scrollView

        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            imageView
        }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView else { return }

            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let location = gesture.location(in: imageView)
                let zoomScale: CGFloat = 2.5
                let width = scrollView.bounds.width / zoomScale
                let height = scrollView.bounds.height / zoomScale
                let rect = CGRect(
                    x: location.x - width / 2,
                    y: location.y - height / 2,
                    width: width,
                    height: height
                )
                scrollView.zoom(to: rect, animated: true)
            }
        }
    }
}
