import AVFoundation
import StoreKit
import SwiftUI

struct CompositeLayoutEditor: View {
    @Environment(\.requestReview) var requestReview
    @Binding var outputName: String
    let onCancel: () -> Void
    let onSave: ([ProjectPage]) -> Void
    @State var pages: [ProjectPage]
    @State var selectedID: UUID?
    @State var actionPage: ProjectPage?
    @State var editing: ProjectPage?
    @State var zoomPage: ProjectPage?
    @State var showDiscard = false
    @State var showCompositeZoom = false
    @State var paperPreset: PaperPreset
    @State var paperOrientation: PaperOrientation
    @State var customWidthMM: Double
    @State var customHeightMM: Double
    @State var paperUnit: PaperUnit
    @State var sharePayload: CompositeSharePayload?
    @State var isPreparingShare = false
    @State var showPhotoSavedToast = false
    @State var showNameRequest = false
    @State var showExportError = false
    @State var exportErrorMessage = ""
    @FocusState var focusedDimension: Bool
    @State var previewImages: [UUID: UIImage]
    let initialPages: [ProjectPage]

    static func initialPaper(from first: ProjectPage?) -> (
        PaperPreset, PaperOrientation, Double, Double, PaperUnit
    ) {
        guard let first, let image = PageImagePipeline.baseImage(for: first) else {
            return (.custom, .portrait, 300, 300, .millimeter)
        }
        let choice = PageRenderGeometry.paperChoice(for: first, baseImageSize: image.size)
        return (choice.preset, choice.orientation, choice.widthMM, choice.heightMM, choice.unit)
    }

    init(
        pages: [ProjectPage], outputName: Binding<String>, onCancel: @escaping () -> Void,
        onSave: @escaping ([ProjectPage]) -> Void
    ) {
        _outputName = outputName
        let first = pages.first
        let initial = Self.initialPaper(from: first)
        let initialPreset = initial.0
        let initialOrientation = initial.1
        let initialWidthMM = initial.2
        let initialHeightMM = initial.3
        let initialUnit = initial.4
        let workingPages = CompositeLayoutPolicy.workingPages(
            from: pages,
            paperPreset: initialPreset,
            paperOrientation: initialOrientation,
            customWidthMM: initialWidthMM,
            customHeightMM: initialHeightMM,
            paperUnit: initialUnit
        )
        _pages = State(initialValue: workingPages)
        _selectedID = State(initialValue: first?.id)
        _previewImages = State(
            initialValue: Dictionary(
                uniqueKeysWithValues: workingPages.compactMap { page in
                    Self.liveSourceImage(for: page).map { (page.id, $0) }
                }))
        initialPages = workingPages
        _paperPreset = State(initialValue: initialPreset)
        _paperOrientation = State(initialValue: initialOrientation)
        _customWidthMM = State(initialValue: initialWidthMM)
        _customHeightMM = State(initialValue: initialHeightMM)
        _paperUnit = State(initialValue: initialUnit)
        self.onCancel = onCancel
        self.onSave = onSave
    }
    var paperSize: CGSize {
        paperPreset.sizeMM(
            orientation: paperOrientation, customWidthMM: customWidthMM, customHeightMM: customHeightMM)
    }

    static func liveSourceImage(for page: ProjectPage, maximumLongEdge: CGFloat = 1400) -> UIImage? {
        guard let raw = PageImagePipeline.baseImage(for: page) else { return nil }
        let base = PageImagePipeline.normalizedOrientation(raw)
        let colored = PageColorRenderer.render(base, mode: page.colorMode)
        let longest = max(colored.size.width, colored.size.height)
        guard longest > maximumLongEdge else { return colored }
        let scale = maximumLongEdge / longest
        let size = CGSize(
            width: max(1, colored.size.width * scale), height: max(1, colored.size.height * scale))
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = false
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            colored.draw(in: CGRect(origin: .zero, size: size))
        }
    }

    var selectedIndex: Int? { pages.firstIndex { $0.id == selectedID } }
    var selectedBinding: Binding<ProjectPage>? {
        guard let i = selectedIndex else { return nil }
        return Binding(get: { pages[i] }, set: { pages[i] = $0 })
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                paperControls
                GeometryReader { proxy in
                    let availableRect = CGRect(origin: .zero, size: proxy.size).insetBy(dx: 8, dy: 8)
                    let fit = AVMakeRect(aspectRatio: paperSize, insideRect: availableRect)
                    ZStack {
                        Color.secondary.opacity(0.12)
                        Canvas(opaque: true, colorMode: .nonLinear, rendersAsynchronously: false) {
                            context, size in
                            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                            context.clip(to: Path(CGRect(origin: .zero, size: size)))
                            for page in appliedPages() where !page.isHiddenFromPreviewAndOutput {
                                guard let source = previewImages[page.id] else { continue }
                                let layout = PageRenderGeometry.rasterLayout(
                                    for: page, baseImageSize: source.size, canvasSize: size)
                                var layer = context
                                let center = CGPoint(
                                    x: layout.fullImageRect.midX, y: layout.fullImageRect.midY)
                                layer.translateBy(x: center.x, y: center.y)
                                layer.rotate(by: .degrees(page.placementRotationDegrees))
                                layer.translateBy(x: -center.x, y: -center.y)
                                layer.clip(to: Path(layout.visibleImageRect))
                                layer.draw(Image(uiImage: source), in: layout.fullImageRect)
                            }
                        }
                        .frame(width: fit.width, height: fit.height)
                        .clipped()
                        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.55)))
                    }
                    .overlay {
                        if let binding = selectedBinding {
                            PlacementGestureSurface(
                                scale: binding.a4WidthRatio, offsetX: binding.placementOffsetX,
                                offsetY: binding.placementOffsetY, rotation: binding.placementRotationDegrees,
                                scaleRange: 0.05...8,
                                offsetLimits: { movementLimits(for: binding.wrappedValue) },
                                openPreview: { showCompositeZoom = true }
                            )
                        }
                    }
                    .contentShape(Rectangle())
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(L10n.text("merge.previewTitle", "重ね合わせプレビュー"))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
                if let binding = selectedBinding { placementControls(binding) }
                CompositeLayerStrip(
                    pages: $pages, selectedID: $selectedID, actionPage: $actionPage, zoomPage: $zoomPage
                )
                .frame(maxWidth: .infinity, minHeight: 124, maxHeight: 124)

                HStack {
                    Button {
                        toggleSelectedVisibility()
                    } label: {
                        Image(
                            systemName: selectedPage?.isHiddenFromPreviewAndOutput == true
                                ? "eye.slash" : "eye"
                        )
                        .font(.body)
                        .frame(width: 44, height: 32)
                    }
                    .disabled(selectedPage == nil)
                    .accessibilityLabel(
                        selectedPage?.isHiddenFromPreviewAndOutput == true
                            ? L10n.text("page.show", "表示する") : L10n.text("page.hide", "見えなくする"))

                    Spacer()

                    Button {
                        guard let index = selectedIndex else { return }
                        pages[index].placementRotationDegrees = 0
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(.body)
                            .frame(width: 44, height: 32)
                    }
                    .disabled(selectedPage == nil || selectedPage?.placementRotationDegrees == 0)
                    .accessibilityLabel(L10n.text("paper.rotationReset", "回転を0°に戻す"))

                    Spacer()

                    Button {
                        editSelectedPage()
                    } label: {
                        Image(systemName: "slider.horizontal.3")
                            .font(.body)
                            .frame(width: 44, height: 32)
                    }
                    .disabled(selectedPage == nil)
                    .accessibilityLabel(L10n.text("common.edit", "編集"))
                }
                .padding(.horizontal, 28)
                .frame(height: 36)
            }
            .padding(.horizontal)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        pages == initialPages ? onCancel() : (showDiscard = true)
                    } label: {
                        Image(systemName: "xmark")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if focusedDimension {
                        Button(L10n.text("common.done", "完了")) {
                            focusedDimension = false
                        }
                    } else {
                        Button {
                            requestCurrentCompositeShare()
                        } label: {
                            if isPreparingShare {
                                ProgressView()
                            } else {
                                Image(systemName: "square.and.arrow.up")
                            }
                        }.disabled(isPreparingShare)
                        Button {
                            onSave(appliedPages())
                        } label: {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
            .alert(L10n.text("discard.confirmTitle", "変更をすべて破棄しますか？"), isPresented: $showDiscard) {
                Button(L10n.text("common.discard", "破棄する"), role: .destructive) { onCancel() }
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
            }
            .fullScreenCover(item: $editing) { page in
                PageEditView(item: page) { updated in
                    guard let index = pages.firstIndex(where: { $0.id == updated.id }) else { return }
                    let normalized = applyingCurrentPaper(to: updated)
                    var nextPages = pages
                    nextPages[index] = normalized
                    pages = nextPages
                    previewImages[normalized.id] = Self.liveSourceImage(for: normalized)
                }
            }
            .fullScreenCover(item: $zoomPage) { page in
                CompositeZoomLayers(pages: [applyingCurrentPaper(to: page)], paperSize: paperSize)
            }
            .alert(L10n.text("export.failed", "出力に失敗しました"), isPresented: $showExportError) {
                Button(L10n.text("common.ok", "OK"), role: .cancel) {}
            } message: {
                Text(exportErrorMessage)
            }
            .alert(L10n.text("export.nameRequired", "出力名を入力してください"), isPresented: $showNameRequest) {
                TextField(L10n.text("export.name", "出力名"), text: $outputName)
                Button(L10n.text("export.action", "出力")) {
                    outputName = outputName.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !outputName.isEmpty else {
                        showNameRequest = true
                        return
                    }
                    prepareCurrentCompositeShare()
                }
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
            }
            .sheet(item: $sharePayload) { payload in
                ShareSheet(
                    items: [payload.url],
                    onCompleted: { _, completed, error in
                        defer { try? FileManager.default.removeItem(at: payload.url) }
                        if completed && error == nil {

                            recordSuccessfulCompositeExport()
                        } else {

                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showCompositeZoom) {
                CompositeZoomLayers(pages: appliedPages(), paperSize: paperSize)
            }
            .overlay(alignment: .top) {
                if showPhotoSavedToast {
                    Text(L10n.text("export.photoSaved", "写真に保存しました")).padding(.horizontal, 16).padding(
                        .vertical, 10
                    ).background(.ultraThinMaterial, in: Capsule()).padding(.top, 8)
                }
            }
            .interactiveDismissDisabled(true)
            .ignoresSafeArea(.keyboard, edges: .bottom)
            .onChange(of: paperConfiguration) { _, _ in
                syncPaperToWorkingPages()
            }
        }
    }
}
