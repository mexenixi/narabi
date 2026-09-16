import CoreImage
import SwiftUI
import UIKit
import Vision

struct DocumentCorrectionView: View {
    @Environment(\.dismiss) private var dismiss
    let image: UIImage
    let completion: (UIImage) -> Void
    @State private var normalizedImage: UIImage
    @State private var candidates: [EditableQuad] = []
    @State private var candidateIndex = 0
    @State private var quad = EditableQuad.insetDefault
    @State private var detecting = true
    @State private var applying = false
    @State private var message = ""

    init(image: UIImage, completion: @escaping (UIImage) -> Void) {
        let normalized = image.normalizedForDocumentCorrection()
        self.image = image
        self.completion = completion
        _normalizedImage = State(initialValue: normalized)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 10) {
                Text(message).font(.caption).foregroundStyle(.secondary)
                QuadEditor(image: normalizedImage, quad: $quad)
                    .environment(\.layoutDirection, .leftToRight)
                    .padding(8)
                HStack {
                    Button(L10n.text("scan.redetect", "再検出")) { detect() }
                    if candidates.count > 1 {
                        Button(L10n.text("scan.nextCandidate", "次の候補")) {
                            candidateIndex = (candidateIndex + 1) % candidates.count
                            quad = candidates[candidateIndex]
                        }
                    }
                    Spacer()
                    Button(L10n.text("scan.correct.apply", "補正を適用")) { apply() }
                        .buttonStyle(.borderedProminent)
                        .disabled(detecting || applying)
                }.padding(.horizontal)
            }
            .navigationTitle(L10n.text("scan.correct.title", "四隅を調整"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.text("common.cancel", "キャンセル")) { dismiss() }
                }
            }
            .overlay {
                if detecting || applying {
                    ProgressView()
                        .padding(24)
                        .background(
                            .regularMaterial,
                            in: RoundedRectangle(cornerRadius: 12)
                        )
                }
            }
            .task { detect() }
        }
    }

    private func detect() {
        detecting = true
        message = L10n.text("scan.detecting", "書類の四角形を検出しています")
        let input = normalizedImage
        guard let imageData = input.pngData() else {
            candidates = []
            candidateIndex = 0
            quad = .insetDefault
            message = L10n.text("scan.notDetected", "自動検出できませんでした。四隅を合わせてください")
            detecting = false
            return
        }
        Task { @MainActor in
            let found = await Task.detached(priority: .userInitiated) {
                guard let backgroundImage = UIImage(data: imageData) else { return [EditableQuad]() }
                return DocumentRectangleDetector.detect(in: backgroundImage)
            }.value
            guard !Task.isCancelled else { return }
            candidates = found
            candidateIndex = 0
            if let first = found.first {
                quad = first
                message = L10n.text("scan.detected", "四隅を確認し、必要なら丸を動かしてください")
            } else {
                quad = .insetDefault
                message = L10n.text("scan.notDetected", "自動検出できませんでした。四隅を合わせてください")
            }
            detecting = false
        }
    }

    private func apply() {
        guard !applying,
            let inputData = normalizedImage.pngData()
        else { return }
        applying = true
        let selectedQuad = quad

        Task { @MainActor in
            let correctedData = await Task.detached(priority: .userInitiated) {
                guard let backgroundImage = UIImage(data: inputData),
                    let corrected = DocumentPerspectiveCorrector.correct(
                        backgroundImage,
                        quad: selectedQuad
                    )
                else { return nil as Data? }
                return corrected.pngData()
            }.value

            guard !Task.isCancelled else { return }
            applying = false
            guard let correctedData,
                let correctedImage = UIImage(data: correctedData)
            else { return }
            completion(correctedImage)
            dismiss()
        }
    }
}

private struct QuadEditor: View {
    let image: UIImage
    @Binding var quad: EditableQuad
    var body: some View {
        GeometryReader { geo in
            let fit = aspectFit(image.size, geo.size)
            ZStack {
                Color.black.opacity(0.92)
                Image(uiImage: image).resizable().scaledToFit()
                path(in: fit).stroke(.yellow, lineWidth: 3)
                handle($quad.topLeft, in: fit)
                handle($quad.topRight, in: fit)
                handle($quad.bottomLeft, in: fit)
                handle($quad.bottomRight, in: fit)
            }.clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
    private func handle(_ point: Binding<CGPoint>, in rect: CGRect) -> some View {
        Circle().fill(.yellow).overlay(Circle().stroke(.black, lineWidth: 2)).frame(width: 34, height: 34)
            .position(
                x: rect.minX + point.wrappedValue.x * rect.width,
                y: rect.minY + point.wrappedValue.y * rect.height
            ).gesture(
                DragGesture().onChanged { v in
                    point.wrappedValue = CGPoint(
                        x: min(max((v.location.x - rect.minX) / max(rect.width, 1), 0), 1),
                        y: min(max((v.location.y - rect.minY) / max(rect.height, 1), 0), 1))
                })
    }
    private func path(in r: CGRect) -> Path {
        Path { p in
            func q(_ v: CGPoint) -> CGPoint { CGPoint(x: r.minX + v.x * r.width, y: r.minY + v.y * r.height) }
            p.move(to: q(quad.topLeft))
            p.addLine(to: q(quad.topRight))
            p.addLine(to: q(quad.bottomRight))
            p.addLine(to: q(quad.bottomLeft))
            p.closeSubpath()
        }
    }
    private func aspectFit(_ image: CGSize, _ container: CGSize) -> CGRect {
        let scale = min(container.width / max(image.width, 1), container.height / max(image.height, 1))
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2, y: (container.height - size.height) / 2, width: size.width,
            height: size.height)
    }
}
