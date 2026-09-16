import SwiftUI
import UIKit

struct PageEditView: View {
    @Environment(\.dismiss) private var dismiss
    let item: ProjectPage
    let save: (ProjectPage) -> Void

    @State private var workingImage: UIImage
    @State private var outputStyle: ProjectPage.OutputStyle
    @State private var a4WidthRatio: Double
    @State private var paperPreset: PaperPreset
    @State private var paperOrientation: PaperOrientation
    @State private var customPaperWidthMM: Double
    @State private var customPaperHeightMM: Double
    @State private var paperUnit: PaperUnit
    @State private var placementOffsetX: Double
    @State private var placementOffsetY: Double
    @State private var placementRotationDegrees: Double
    @State private var leftCrop: Double
    @State private var rightCrop: Double
    @State private var topCrop: Double
    @State private var bottomCrop: Double
    @State private var colorMode: ProjectPage.ColorMode
    @State private var showDocumentCorrection = false
    @State private var showZoomPreview = false
    @FocusState private var placementNumberFocused: Bool

    init(item: ProjectPage, save: @escaping (ProjectPage) -> Void) {
        self.item = item
        self.save = save
        _workingImage = State(initialValue: PageImagePipeline.baseImage(for: item) ?? UIImage())
        _outputStyle = State(initialValue: item.outputStyle)
        _a4WidthRatio = State(initialValue: item.a4WidthRatio)
        _paperPreset = State(initialValue: item.paperPreset)
        _paperOrientation = State(initialValue: item.paperOrientation)
        _customPaperWidthMM = State(initialValue: item.customPaperWidthMM)
        _customPaperHeightMM = State(initialValue: item.customPaperHeightMM)
        _paperUnit = State(initialValue: item.paperUnit)
        _placementOffsetX = State(initialValue: item.placementOffsetX)
        _placementOffsetY = State(initialValue: item.placementOffsetY)
        _placementRotationDegrees = State(initialValue: item.placementRotationDegrees)
        _leftCrop = State(initialValue: item.cropInsets.left)
        _rightCrop = State(initialValue: item.cropInsets.right)
        _topCrop = State(initialValue: item.cropInsets.top)
        _bottomCrop = State(initialValue: item.cropInsets.bottom)
        _colorMode = State(initialValue: item.colorMode)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    cropPreview
                        .frame(height: 390)
                        .contentShape(Rectangle())
                        .onTapGesture { showZoomPreview = true }
                        .accessibilityAddTraits(.isButton)
                        .accessibilityLabel(L10n.text("edit.zoomPreview", "拡大表示"))
                        .accessibilityHint(L10n.text("edit.zoomPreviewHint", "タップして切り取り範囲を拡大表示します。"))

                    GroupBox(L10n.text("edit.crop", "切り取り範囲")) {
                        VStack(spacing: 6) {
                            cropSlider(
                                "←", accessibilityKey: "direction.left", accessibilityFallback: "左",
                                edge: .left, value: $leftCrop)
                            cropSlider(
                                "→", accessibilityKey: "direction.right", accessibilityFallback: "右",
                                edge: .right, value: $rightCrop)
                            cropSlider(
                                "↑", accessibilityKey: "direction.top", accessibilityFallback: "上",
                                edge: .top, value: $topCrop)
                            cropSlider(
                                "↓", accessibilityKey: "direction.bottom", accessibilityFallback: "下",
                                edge: .bottom, value: $bottomCrop)
                        }
                        .environment(\.layoutDirection, .leftToRight)
                    }

                    Button {
                        showDocumentCorrection = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "viewfinder.rectangular")
                            Text(L10n.text("scan.correct.action", "書類として補正"))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    GroupBox(L10n.text("output.color", "出力カラー")) {
                        Picker(L10n.text("output.color", "出力カラー"), selection: $colorMode) {
                            Text(L10n.text("scan.color", "カラー")).tag(ProjectPage.ColorMode.color)
                            Text(L10n.text("scan.gray", "グレー")).tag(ProjectPage.ColorMode.grayscale)
                            Text(L10n.text("scan.mono", "白黒")).tag(ProjectPage.ColorMode.monochrome)
                        }.pickerStyle(.segmented)
                        Text(L10n.text("output.color.note", "元画像は変更せず、表示と出力時に適用します。"))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    HStack {
                        Button(L10n.text("edit.rotateLeft", "左へ90度")) { rotate(clockwise: false) }
                        Spacer()
                        Button(L10n.text("edit.rotateRight", "右へ90度")) { rotate(clockwise: true) }
                    }
                    .environment(\.layoutDirection, .leftToRight)

                    Picker(L10n.text("edit.saveMethod", "保存方法"), selection: $outputStyle) {
                        Text(L10n.text("edit.original", "そのまま")).tag(ProjectPage.OutputStyle.original)
                        Text(L10n.text("page.placement", "配置")).tag(ProjectPage.OutputStyle.a4Centered)
                    }
                    .pickerStyle(.segmented)

                    if outputStyle == .a4Centered {
                        GroupBox(L10n.text("paper.place", "用紙に配置")) {
                            PaperPlacementSettings(
                                preset: $paperPreset,
                                orientation: $paperOrientation,
                                customWidthMM: $customPaperWidthMM,
                                customHeightMM: $customPaperHeightMM,
                                unit: $paperUnit,
                                placementRatio: $a4WidthRatio,
                                horizontalOffset: $placementOffsetX,
                                verticalOffset: $placementOffsetY,
                                rotationDegrees: $placementRotationDegrees,
                                numericFieldFocus: $placementNumberFocused,
                                sourcePage: item,
                                cropInsets: PageCropInsets(
                                    left: leftCrop, right: rightCrop, top: topCrop, bottom: bottomCrop),
                                colorMode: colorMode,
                                image: workingImage
                            )
                        }
                    }

                    Button(L10n.text("edit.restoreOriginal", "オリジナルに戻す")) {
                        workingImage = UIImage(data: item.originalData) ?? UIImage()
                        leftCrop = 0
                        rightCrop = 0
                        topCrop = 0
                        bottomCrop = 0
                        outputStyle = .original
                        a4WidthRatio = 0.41
                        paperPreset = .a4
                        paperOrientation = .portrait
                        customPaperWidthMM = 210
                        customPaperHeightMM = 297
                        paperUnit = .millimeter
                        placementOffsetX = 0
                        placementOffsetY = 0
                        placementRotationDegrees = 0
                        colorMode = .color
                    }
                    .foregroundStyle(.orange)
                }
                .padding()
            }
            .navigationTitle(L10n.text("edit.pageTitle", "ページを編集"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("common.cancel", "キャンセル")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if placementNumberFocused {
                        Button(L10n.text("common.done", "完了")) {
                            placementNumberFocused = false
                        }
                    } else {
                        Button {
                            saveChanges()
                        } label: {
                            Image(systemName: "checkmark")
                        }
                        .accessibilityLabel(L10n.text("common.save", "保存"))
                    }
                }
            }
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $showDocumentCorrection) {
                DocumentCorrectionView(image: workingImage) { corrected in
                    workingImage = corrected
                    leftCrop = 0
                    rightCrop = 0
                    topCrop = 0
                    bottomCrop = 0
                }
            }
            .fullScreenCover(isPresented: $showZoomPreview) {
                CropZoomPreview(
                    image: PageColorRenderer.render(workingImage, mode: colorMode),
                    leftCrop: leftCrop, rightCrop: rightCrop,
                    topCrop: topCrop, bottomCrop: bottomCrop
                )
            }
        }
    }

    private var cropPreview: some View {
        GeometryReader { geometry in
            let fitted = aspectFitRect(imageSize: workingImage.size, containerSize: geometry.size)
            let selection = displayedCropRect(in: fitted)

            ZStack {
                Color.secondary.opacity(0.08)
                Image(uiImage: PageColorRenderer.render(workingImage, mode: colorMode))
                    .resizable()
                    .scaledToFit()
                    .frame(width: geometry.size.width, height: geometry.size.height)

                Path { path in
                    path.addRect(fitted)
                    path.addRect(selection)
                }
                .fill(Color.black.opacity(0.38), style: FillStyle(eoFill: true))
                .allowsHitTesting(false)

                Path { path in path.addRect(selection) }
                    .stroke(.yellow, style: StrokeStyle(lineWidth: 3, dash: [8, 5]))
                    .allowsHitTesting(false)
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    private func cropSlider(
        _ symbol: String,
        accessibilityKey: String,
        accessibilityFallback: String,
        edge: PageCropEdge,
        value: Binding<Double>
    ) -> some View {
        HStack(spacing: 12) {
            Text(symbol).font(.title3).frame(width: 28)
            Slider(
                value: constrainedCropBinding(value, edge: edge), in: 0...PagePlacementPolicy.maximumCropSum)
            Text(value.wrappedValue, format: .percent.precision(.fractionLength(0)))
                .monospacedDigit().frame(width: 52, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.text(accessibilityKey, accessibilityFallback))
    }

    private func displayedCropRect(in imageRect: CGRect) -> CGRect {
        CGRect(
            x: imageRect.minX + imageRect.width * leftCrop,
            y: imageRect.minY + imageRect.height * topCrop,
            width: imageRect.width * (1 - leftCrop - rightCrop),
            height: imageRect.height * (1 - topCrop - bottomCrop)
        )
    }

    private func aspectFitRect(imageSize: CGSize, containerSize: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else { return .zero }
        let scale = min(containerSize.width / imageSize.width, containerSize.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (containerSize.width - size.width) / 2,
            y: (containerSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    private func rotate(clockwise: Bool) {
        let oldImage = workingImage
        let oldSize = oldImage.size
        let newSize = CGSize(width: oldSize.height, height: oldSize.width)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        workingImage = UIGraphicsImageRenderer(size: newSize, format: format).image { context in
            UIColor.white.setFill()
            context.fill(CGRect(origin: .zero, size: newSize))
            context.cgContext.translateBy(x: newSize.width / 2, y: newSize.height / 2)
            context.cgContext.rotate(by: clockwise ? .pi / 2 : -.pi / 2)
            oldImage.draw(
                in: CGRect(
                    x: -oldSize.width / 2,
                    y: -oldSize.height / 2,
                    width: oldSize.width,
                    height: oldSize.height
                ))
        }

        leftCrop = 0
        rightCrop = 0
        topCrop = 0
        bottomCrop = 0
    }

    private func constrainedCropBinding(
        _ value: Binding<Double>, edge: PageCropEdge
    ) -> Binding<Double> {
        Binding(
            get: { value.wrappedValue },
            set: { proposed in
                var crop = PageCropInsets(
                    left: leftCrop,
                    right: rightCrop,
                    top: topCrop,
                    bottom: bottomCrop
                )
                crop.set(proposed, for: edge)
                leftCrop = crop.left
                rightCrop = crop.right
                topCrop = crop.top
                bottomCrop = crop.bottom
            }
        )
    }

    private func saveChanges() {
        // The editing base and crop rectangle must share the same coordinate space.
        // Never bake the crop into the next editing base.
        guard let baseData = PageImagePipeline.editedData(from: workingImage) else { return }
        let changed = PageEditResultPolicy.applying(
            to: item,
            editedData: baseData,
            settings: .init(
                outputStyle: outputStyle,
                a4WidthRatio: a4WidthRatio,
                paperPreset: paperPreset,
                paperOrientation: paperOrientation,
                customPaperWidthMM: customPaperWidthMM,
                customPaperHeightMM: customPaperHeightMM,
                paperUnit: paperUnit,
                placementOffsetX: placementOffsetX,
                placementOffsetY: placementOffsetY,
                placementRotationDegrees: placementRotationDegrees,
                colorMode: colorMode,
                cropInsets: PageCropInsets(
                    left: leftCrop,
                    right: rightCrop,
                    top: topCrop,
                    bottom: bottomCrop
                )
            )
        )
        save(changed)
        dismiss()
    }
}
