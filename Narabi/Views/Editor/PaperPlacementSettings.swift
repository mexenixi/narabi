import SwiftUI
import UIKit

struct PaperPlacementSettings: View {
    @Binding var preset: PaperPreset
    @Binding var orientation: PaperOrientation
    @Binding var customWidthMM: Double
    @Binding var customHeightMM: Double
    @Binding var unit: PaperUnit
    @Binding var placementRatio: Double
    @Binding var horizontalOffset: Double
    @Binding var verticalOffset: Double
    @Binding var rotationDegrees: Double
    let numericFieldFocus: FocusState<Bool>.Binding

    let sourcePage: ProjectPage
    let cropInsets: PageCropInsets
    let colorMode: ProjectPage.ColorMode
    let image: UIImage

    @State private var showPreview = false

    private var previewPage: ProjectPage {
        var page = sourcePage
        page.outputStyle = .a4Centered
        page.paperPreset = preset
        page.paperOrientation = orientation
        page.customPaperWidthMM = customWidthMM
        page.customPaperHeightMM = customHeightMM
        page.paperUnit = unit
        page.a4WidthRatio = placementRatio
        page.placementOffsetX = horizontalOffset
        page.placementOffsetY = verticalOffset
        page.placementRotationDegrees = rotationDegrees
        page.cropInsets = cropInsets
        page.colorMode = colorMode
        return page
    }

    private var livePreviewImage: UIImage {
        PageRenderer.render(image: image, page: previewPage, maximumLongEdge: 1200, background: .white)
            ?? UIImage()
    }

    private var zoomPreviewImage: UIImage {
        PageRenderer.render(image: image, page: previewPage, maximumLongEdge: 2400, background: .white)
            ?? UIImage()
    }

    private var pageSize: CGSize {
        preset.sizeMM(
            orientation: orientation,
            customWidthMM: customWidthMM,
            customHeightMM: customHeightMM
        )
    }

    private var isCustomSizeValid: Bool {
        (10...2000).contains(customWidthMM) && (10...2000).contains(customHeightMM)
    }

    var body: some View {
        VStack(spacing: 12) {
            Picker(
                L10n.text("paper.size", "用紙サイズ"),
                selection: $preset
            ) {
                ForEach(PaperPreset.allCases) { paper in
                    Text(L10n.text(paper.titleKey, fallbackName(for: paper)))
                        .tag(paper)
                }
            }
            .frame(minHeight: 46, alignment: .center)

            if preset == .custom {
                customSizeControls
            } else {
                orientationPicker
            }

            PaperPlacementPreview(image: livePreviewImage)
                .frame(height: 260)
                .overlay {
                    PlacementGestureSurface(
                        scale: $placementRatio, offsetX: $horizontalOffset, offsetY: $verticalOffset,
                        rotation: $rotationDegrees,
                        scaleRange: 0.0205...3.28, offsetLimits: { movementLimits },
                        openPreview: { showPreview = true }
                    )
                }
                .contentShape(Rectangle())
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(
                    L10n.text("paper.preview", "用紙プレビュー")
                )

            placementSliderRow(
                symbol: "arrow.up.left.and.arrow.down.right",
                value: $placementRatio,
                range: 0.0205...3.28,
                valueText: placementRatio.formatted(.percent.precision(.fractionLength(0))),
                accessibilityLabel: L10n.text("paper.widthRatio", "用紙幅に対する大きさ")
            )
            placementSliderRow(
                symbol: "arrow.left.and.right",
                value: $horizontalOffset,
                range: -movementLimits.x...movementLimits.x,
                valueText: positionText(horizontalOffset, limit: movementLimits.x),
                accessibilityLabel: L10n.text("paper.horizontalPosition", "左右位置")
            )
            placementSliderRow(
                symbol: "arrow.up.and.down",
                value: $verticalOffset,
                range: -movementLimits.y...movementLimits.y,
                valueText: positionText(verticalOffset, limit: movementLimits.y),
                accessibilityLabel: L10n.text("paper.verticalPosition", "上下位置")
            )
            placementSliderRow(
                symbol: "rotate.right",
                value: $rotationDegrees,
                range: -180...180,
                step: 1,
                valueText: "\(Int(rotationDegrees))°",
                accessibilityLabel: L10n.text("paper.imageRotation", "画像の回転")
            )

            Button(L10n.text("paper.rotationReset", "回転を0°に戻す")) { rotationDegrees = 0 }

            Button {
                horizontalOffset = 0
                verticalOffset = 0
            } label: {
                Label(L10n.text("paper.centerReset", "中央に戻す"), systemImage: "scope")
            }
        }
        .fullScreenCover(isPresented: $showPreview) {
            PaperZoomPreview(image: zoomPreviewImage)
        }
    }

    private func placementSliderRow(
        symbol: String,
        value: Binding<Double>,
        range: ClosedRange<Double>,
        step: Double = 0.001,
        valueText: String,
        accessibilityLabel: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .frame(width: 34, alignment: .center)
            Slider(value: value, in: range, step: step)
            Text(valueText)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(width: 54, alignment: .trailing)
        }
        .environment(\.layoutDirection, .leftToRight)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var movementLimits: (x: Double, y: Double) {
        let image = PageImagePipeline.normalizedOrientation(self.image)
        let limits = PagePlacementPolicy.placementOffsetLimits(
            paperSize: pageSize,
            normalizedImageSize: image.size,
            placementScale: placementRatio,
            rotationDegrees: rotationDegrees
        )
        return (Double(limits.width), Double(limits.height))
    }

    private func positionText(_ offset: Double, limit: Double) -> String {
        String(PagePlacementPolicy.positionDisplayValue(offset: offset, limit: limit))
    }

    private var orientationPicker: some View {
        Picker(
            L10n.text("paper.orientation", "向き"),
            selection: $orientation
        ) {
            Label(
                L10n.text("paper.portrait", "縦"),
                systemImage: "rectangle.portrait"
            )
            .tag(PaperOrientation.portrait)

            Label(
                L10n.text("paper.landscape", "横"),
                systemImage: "rectangle"
            )
            .tag(PaperOrientation.landscape)
        }
        .pickerStyle(.segmented)
    }

    private var customSizeControls: some View {
        VStack(spacing: 10) {
            Picker(
                L10n.text("paper.unit", "単位"),
                selection: $unit
            ) {
                ForEach(PaperUnit.allCases) { paperUnit in
                    Text(paperUnit.rawValue)
                        .tag(paperUnit)
                }
            }
            .pickerStyle(.segmented)

            customSizeField(
                L10n.text("paper.width", "幅"),
                millimeters: $customWidthMM
            )

            customSizeField(
                L10n.text("paper.height", "高さ"),
                millimeters: $customHeightMM
            )

            if !isCustomSizeValid {
                Text(
                    L10n.text(
                        "paper.invalidSize",
                        "10〜2000 mmの範囲で入力してください。"
                    )
                )
                .font(.footnote)
                .foregroundStyle(.red)
            }
        }
    }

    private func customSizeField(
        _ title: String,
        millimeters: Binding<Double>
    ) -> some View {
        HStack {
            Text(title)
            Spacer()

            TextField(
                title,
                value: Binding(
                    get: { unit.displayValue(fromMM: millimeters.wrappedValue) },
                    set: { millimeters.wrappedValue = unit.millimeters(from: $0) }
                ),
                format: .number.precision(.fractionLength(0...2))
            )
            .keyboardType(.decimalPad)
            .focused(numericFieldFocus)
            .multilineTextAlignment(.trailing)
            .frame(maxWidth: 140)

            Text(unit.rawValue)
                .foregroundStyle(.secondary)
        }
    }

    private func fallbackName(for paper: PaperPreset) -> String {
        switch paper {
        case .a3:
            return "A3"
        case .a4:
            return "A4"
        case .a5:
            return "A5"
        case .b4:
            return "B4"
        case .b5:
            return "B5"
        case .letter:
            return "Letter"
        case .legal:
            return "Legal"
        case .postcard:
            return "Postcard"
        case .photo4x6:
            return "4 × 6 in"
        case .custom:
            return "Custom"
        }
    }
}
