import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    var onPresented: () -> Void = {}
    var onCompleted: (UIActivity.ActivityType?, Bool, Error?) -> Void = { _, _, _ in }

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        controller.completionWithItemsHandler = { activity, completed, _, error in
            onCompleted(activity, completed, error)
        }
        DispatchQueue.main.async {
            onPresented()
        }
        return controller
    }

    func updateUIViewController(
        _ uiViewController: UIActivityViewController,
        context: Context
    ) {}

    static func paperPointSize(for item: ProjectPage) -> CGSize {
        let millimeters = item.paperPreset.sizeMM(
            orientation: item.paperOrientation,
            customWidthMM: item.customPaperWidthMM,
            customHeightMM: item.customPaperHeightMM
        )
        return CGSize(
            width: millimeters.width / 25.4 * 72,
            height: millimeters.height / 25.4 * 72
        )
    }
}
