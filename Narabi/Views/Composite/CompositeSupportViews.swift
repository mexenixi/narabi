import AVFoundation
import StoreKit
import SwiftUI

struct CompositeZoomLayers: View {
    let pages: [ProjectPage]
    let paperSize: CGSize
    @Environment(\.dismiss) private var dismiss

    private var previewImage: UIImage? {
        ExportService.compositeImage(
            pages: pages,
            transparent: false,
            longEdge: .px2048,
            colorPolicy: .perPage
        )
    }

    var body: some View {
        NavigationStack {
            Group {
                if let previewImage {
                    StandardZoomImageView(image: previewImage)
                        .background(Color.black)
                        .accessibilityHint(
                            L10n.text("preview.zoomGestureHint", "ピンチまたはダブルタップで拡大し、ドラッグで移動できます。"))
                } else {
                    Color.black
                }
            }
            .toolbar { Button(L10n.text("common.done", "完了")) { dismiss() } }
        }
    }
}

struct CompositeSharePayload: Identifiable {
    let id = UUID()
    let url: URL
}

struct CompositePaperConfiguration: Equatable {
    let preset: PaperPreset
    let orientation: PaperOrientation
    let customWidthMM: Double
    let customHeightMM: Double
    let unit: PaperUnit
}
