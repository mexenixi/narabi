import AVFoundation
import CoreImage
import SwiftUI
import UIKit
import VisionKit

struct DocumentScanner: UIViewControllerRepresentable {
    let completion: ([UIImage]) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }
    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }
    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    final class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: DocumentScanner
        init(parent: DocumentScanner) { self.parent = parent }
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan
        ) {
            let images = (0..<scan.pageCount).map(scan.imageOfPage(at:))
            parent.completion(images)
            controller.dismiss(animated: true)
        }
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }
        func documentCameraViewController(
            _ controller: VNDocumentCameraViewController, didFailWithError error: Error
        ) { controller.dismiss(animated: true) }
    }
}

enum ScanImageFilter: String, CaseIterable, Identifiable {
    case color, grayscale, monochrome
    var id: String { rawValue }
}

enum ScanImageProcessor {
    static func apply(_ filter: ScanImageFilter, to image: UIImage) -> UIImage {
        guard filter != .color, let ci = CIImage(image: image) else { return image }
        let context = CIContext()
        let output: CIImage?
        switch filter {
        case .color: output = ci
        case .grayscale:
            output = ci.applyingFilter(
                "CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 1.12])
        case .monochrome:
            output = ci.applyingFilter(
                "CIColorControls",
                parameters: [
                    kCIInputSaturationKey: 0, kCIInputContrastKey: 1.65, kCIInputBrightnessKey: 0.06,
                ])
        }
        guard let output, let cg = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: image.imageOrientation)
    }
}

@MainActor
enum CameraPermissionFlow {
    enum Result { case allowed, needsSystemPrompt, denied }
    static func current() -> Result {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized: return .allowed
        case .notDetermined: return .needsSystemPrompt
        default: return .denied
        }
    }
    static func request() async -> Bool { await AVCaptureDevice.requestAccess(for: .video) }
    static func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}

nonisolated enum PageColorRenderer {
    static func resolvedMode(pageMode: ProjectPage.ColorMode, policy: ExportColorPolicy)
        -> ProjectPage.ColorMode
    {
        switch policy {
        case .perPage: return pageMode
        case .allColor: return .color
        case .allGrayscale: return .grayscale
        case .allMonochrome: return .monochrome
        }
    }
    static func render(_ image: UIImage, mode: ProjectPage.ColorMode) -> UIImage {
        guard mode != .color, let input = CIImage(image: image) else { return image }
        let output: CIImage
        switch mode {
        case .color: output = input
        case .grayscale:
            output = input.applyingFilter("CIPhotoEffectMono")
        case .monochrome:
            output =
                input
                .applyingFilter(
                    "CIColorControls",
                    parameters: [
                        kCIInputSaturationKey: 0, kCIInputContrastKey: 1.75, kCIInputBrightnessKey: 0.05,
                    ]
                )
                .applyingFilter("CIPhotoEffectNoir")
        }
        let context = CIContext(options: [.useSoftwareRenderer: false])
        guard let cg = context.createCGImage(output, from: output.extent) else { return image }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }
}
