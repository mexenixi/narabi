import SwiftUI
import UIKit

struct A4PlacementPreview: View {
    let image: UIImage
    let widthRatio: Double

    var body: some View {
        GeometryReader { geometry in
            let pageSize = a4Fit(in: geometry.size)
            let imageRatio = image.size.width / max(image.size.height, 1)
            let maximumWidth = pageSize.width * widthRatio
            let maximumHeight = pageSize.height * 0.80
            var drawSize = CGSize(width: maximumWidth, height: maximumWidth / max(imageRatio, 0.0001))
            let _ = {
                if drawSize.height > maximumHeight {
                    drawSize.height = maximumHeight
                    drawSize.width = maximumHeight * imageRatio
                }
            }()

            ZStack {
                Color.secondary.opacity(0.08)
                Rectangle()
                    .fill(.white)
                    .frame(width: pageSize.width, height: pageSize.height)
                    .shadow(radius: 2)
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: drawSize.width, height: drawSize.height)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func a4Fit(in size: CGSize) -> CGSize {
        let ratio = 210.0 / 297.0
        var width = size.width * 0.72
        var height = width / ratio
        if height > size.height * 0.95 {
            height = size.height * 0.95
            width = height * ratio
        }
        return CGSize(width: width, height: height)
    }
}

struct CropZoomPreview: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let leftCrop: Double
    let rightCrop: Double
    let topCrop: Double
    let bottomCrop: Double
    var body: some View {
        ZStack(alignment: .topLeading) {
            StandardCropZoomView(
                image: image,
                cropInsets: UIEdgeInsets(top: topCrop, left: leftCrop, bottom: bottomCrop, right: rightCrop)
            ).ignoresSafeArea()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark").font(.title2.bold()).frame(width: 48, height: 48)
            }
            .buttonStyle(.borderedProminent).buttonBorderShape(.circle).padding()
            .accessibilityLabel(L10n.text("common.close", "閉じる"))
        }.statusBarHidden(true)
    }
}
