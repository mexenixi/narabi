import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct EditorPagePreviewItem: Identifiable {
    let id = UUID()
    let page: ProjectPage
    let title: String
}

struct EditorPagePreviewView: View {
    @Environment(\.dismiss) private var dismiss
    let item: EditorPagePreviewItem

    var body: some View {
        NavigationStack {
            Group {
                if let image = PageRenderer.render(
                    page: item.page,
                    maximumLongEdge: 2400,
                    background: .white
                ) {
                    ZoomableEditorImagePreview(image: image)
                } else {
                    ContentUnavailableView(
                        L10n.text("common.unavailable", "表示できません"),
                        systemImage: "exclamationmark.triangle"
                    )
                }
            }
            .background(Color.black)
            .navigationTitle(item.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("common.back", "戻る")) { dismiss() }
                }
            }
            .interactiveDismissDisabled(true)
        }
    }
}

private struct ZoomableEditorImagePreview: UIViewRepresentable {
    let image: UIImage
    let backgroundColor: UIColor

    init(image: UIImage, backgroundColor: UIColor = .black) {
        self.image = image
        self.backgroundColor = backgroundColor
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.backgroundColor = backgroundColor
        scrollView.delegate = context.coordinator
        scrollView.minimumZoomScale = 1
        scrollView.maximumZoomScale = 6
        scrollView.bouncesZoom = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false

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
        context.coordinator.scrollView = scrollView

        let doubleTap = UITapGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handleDoubleTap(_:))
        )
        doubleTap.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTap)
        return scrollView
    }

    func updateUIView(_ uiView: UIScrollView, context: Context) {
        uiView.backgroundColor = backgroundColor
        guard context.coordinator.imageView?.image !== image else { return }
        context.coordinator.imageView?.image = image
        uiView.setZoomScale(uiView.minimumZoomScale, animated: false)
    }

    final class Coordinator: NSObject, UIScrollViewDelegate {
        weak var imageView: UIImageView?
        weak var scrollView: UIScrollView?

        func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }

        @objc func handleDoubleTap(_ gesture: UITapGestureRecognizer) {
            guard let scrollView, let imageView else { return }
            if scrollView.zoomScale > scrollView.minimumZoomScale {
                scrollView.setZoomScale(scrollView.minimumZoomScale, animated: true)
            } else {
                let scale: CGFloat = 2.5
                let point = gesture.location(in: imageView)
                let size = CGSize(
                    width: scrollView.bounds.width / scale,
                    height: scrollView.bounds.height / scale
                )
                scrollView.zoom(
                    to: CGRect(
                        x: point.x - size.width / 2,
                        y: point.y - size.height / 2,
                        width: size.width,
                        height: size.height
                    ),
                    animated: true
                )
            }
        }
    }
}

struct CompositePreviewItem: Identifiable {
    let id = UUID()
    let image: UIImage
}

struct CompositeExportPreview: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    @Binding var preset: ExportPreset
    let rebuild: (ExportPreset) -> UIImage?
    let onCancel: () -> Void
    let onExport: () -> Void
    @State private var displayedImage: UIImage

    init(
        image: UIImage,
        preset: Binding<ExportPreset>,
        rebuild: @escaping (ExportPreset) -> UIImage?,
        onCancel: @escaping () -> Void,
        onExport: @escaping () -> Void
    ) {
        self.image = image
        self._preset = preset
        self.rebuild = rebuild
        self.onCancel = onCancel
        self.onExport = onExport
        self._displayedImage = State(initialValue: image)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ZoomableEditorImagePreview(
                    image: displayedImage,
                    backgroundColor: preset == .transparentPNG
                        ? .secondarySystemBackground
                        : .white
                )
                .accessibilityLabel(L10n.text("merge.previewTitle", "重ね合わせプレビュー"))
                .accessibilityHint(L10n.text("preview.zoomGestureHint", "ピンチまたはダブルタップで拡大し、ドラッグで移動できます。"))
                HStack {
                    Menu {
                        ForEach(ExportPreset.allCases) { value in
                            Button {
                                preset = value
                                ProductSettings.shared.exportPreset = value
                                if let refreshed = rebuild(value) {
                                    displayedImage = refreshed
                                }
                            } label: {
                                Label(
                                    L10n.text(value.titleKey, value.rawValue.uppercased()),
                                    systemImage: value.symbol)
                            }
                        }
                    } label: {
                        Image(systemName: preset.symbol).frame(width: 28, height: 28)
                    }
                    .buttonStyle(.bordered)
                    Spacer()
                    Button(L10n.text("common.cancel", "キャンセル")) {
                        onCancel()
                        dismiss()
                    }
                    Button {
                        onExport()
                        dismiss()
                    } label: {
                        Label(L10n.text("export.action", "出力"), systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            }
            .navigationTitle(L10n.text("merge.previewTitle", "重ね合わせプレビュー"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
