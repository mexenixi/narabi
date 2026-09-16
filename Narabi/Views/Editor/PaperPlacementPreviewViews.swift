import SwiftUI
import UIKit

struct PaperPlacementPreview: View {
    let image: UIImage

    var body: some View {
        ZStack {
            Color.secondary.opacity(0.08)
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .shadow(radius: 2)
                .padding(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct PaperZoomPreview: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage

    var body: some View {
        ZStack(alignment: .topLeading) {
            RenderedPaperZoomView(image: image).ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.title2.bold()).frame(width: 48, height: 48)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.circle).padding()
            .accessibilityLabel(L10n.text("common.close", "閉じる"))
        }
        .statusBarHidden(true)
    }
}

struct RenderedPaperZoomView: UIViewRepresentable {
    let image: UIImage

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.backgroundColor = .black
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 8
        scroll.bouncesZoom = true
        scroll.delegate = context.coordinator
        scroll.showsVerticalScrollIndicator = false
        scroll.showsHorizontalScrollIndicator = false

        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.translatesAutoresizingMaskIntoConstraints = false
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
        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator, action: #selector(Coordinator.doubleTap(_:)))
        doubleTap.numberOfTapsRequired = 2
        scroll.addGestureRecognizer(doubleTap)
        return scroll
    }

    func updateUIView(_ scroll: UIScrollView, context: Context) {
        context.coordinator.imageView?.image = image
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
        @objc func doubleTap(_ recognizer: UITapGestureRecognizer) {
            guard let scroll = recognizer.view as? UIScrollView else { return }
            scroll.setZoomScale(scroll.zoomScale > 1 ? 1 : min(2.5, scroll.maximumZoomScale), animated: true)
        }
    }
}
