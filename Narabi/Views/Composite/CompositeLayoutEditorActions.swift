import StoreKit
import SwiftUI
import UIKit

extension CompositeLayoutEditor {
    var paperConfiguration: CompositePaperConfiguration {
        CompositePaperConfiguration(
            preset: paperPreset,
            orientation: paperOrientation,
            customWidthMM: customWidthMM,
            customHeightMM: customHeightMM,
            unit: paperUnit
        )
    }

    var selectedPage: ProjectPage? {
        guard let index = selectedIndex else { return nil }
        return pages[index]
    }
    func toggleSelectedVisibility() {
        guard let selectedID else { return }
        pages = CompositeLayoutPolicy.togglingVisibility(in: pages, id: selectedID)
    }
    func editSelectedPage() {
        guard let page = selectedPage else { return }
        editing = page
    }
    var paperControls: some View {
        HStack(spacing: 6) {
            Menu {
                ForEach([PaperPreset.custom, .a3, .a4, .a5, .b4, .b5, .letter, .legal, .postcard, .photo4x6])
                { preset in
                    Button(L10n.text(preset.titleKey, preset.rawValue)) { paperPreset = preset }
                }
            } label: {
                if paperPreset == .custom {
                    Image(systemName: "doc")
                        .frame(width: 44, height: 46, alignment: .center)
                        .contentShape(Rectangle())
                        .accessibilityLabel(L10n.text("paper.free", "自由"))
                } else {
                    Label(L10n.text(paperPreset.titleKey, paperPreset.rawValue), systemImage: "doc")
                        .frame(minHeight: 46, alignment: .center)
                        .contentShape(Rectangle())
                }
            }
            .fixedSize(horizontal: true, vertical: false)

            if paperPreset == .custom {
                Picker(selection: $paperUnit) {
                    ForEach(PaperUnit.allCases) { unit in
                        Text(unit.rawValue).lineLimit(1).fixedSize(horizontal: true, vertical: false).tag(
                            unit)
                    }
                } label: {
                    EmptyView()
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(3)

                Spacer(minLength: 8)

                HStack(spacing: 5) {
                    Text(verbatim: "W").font(.caption2).foregroundStyle(.secondary)
                    compactNumberField(value: $customWidthMM)
                    Text(verbatim: "×")
                    Text(verbatim: "H").font(.caption2).foregroundStyle(.secondary)
                    compactNumberField(value: $customHeightMM)
                }
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(2)
            } else {
                Button {
                    paperOrientation = .portrait
                } label: {
                    Image(systemName: "rectangle.portrait").symbolVariant(
                        paperOrientation == .portrait ? .fill : .none)
                }.accessibilityLabel(L10n.text("paper.portrait", "縦"))
                Button {
                    paperOrientation = .landscape
                } label: {
                    Image(systemName: "rectangle").symbolVariant(
                        paperOrientation == .landscape ? .fill : .none)
                }.accessibilityLabel(L10n.text("paper.landscape", "横"))
                Spacer(minLength: 0)
            }
        }
        .font(.subheadline)
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .padding(.horizontal, 2)
        .frame(height: 46)
    }

    func numeric(_ value: Binding<Double>) -> some View {
        TextField(
            value: Binding(
                get: { paperUnit.displayValue(fromMM: value.wrappedValue) },
                set: { value.wrappedValue = paperUnit.millimeters(from: $0) }),
            format: .number.precision(.fractionLength(0...2))
        ) { EmptyView() }.keyboardType(.decimalPad).focused($focusedDimension).textFieldStyle(.roundedBorder)
            .frame(minWidth: 72, idealWidth: 80, maxWidth: 96)
    }
    func placementControls(_ page: Binding<ProjectPage>) -> some View {
        let limits = movementLimits(for: page.wrappedValue)
        return VStack(spacing: 4) {
            alignedSliderRow(
                symbol: "arrow.up.left.and.arrow.down.right", value: page.a4WidthRatio, range: 0.05...8,
                valueText: "\(Int(page.wrappedValue.a4WidthRatio*100))%")
            alignedSliderRow(
                symbol: "arrow.left.and.right", value: page.placementOffsetX, range: -limits.x...limits.x,
                valueText: positionText(page.wrappedValue.placementOffsetX, limit: limits.x))
            alignedSliderRow(
                symbol: "arrow.up.and.down", value: page.placementOffsetY, range: -limits.y...limits.y,
                valueText: positionText(page.wrappedValue.placementOffsetY, limit: limits.y))
            alignedSliderRow(
                symbol: "rotate.right", value: page.placementRotationDegrees, range: -180...180, step: 1,
                valueText: "\(Int(page.wrappedValue.placementRotationDegrees))°")
        }
    }

    func alignedSliderRow(
        symbol: String, value: Binding<Double>, range: ClosedRange<Double>, step: Double = 0.001,
        valueText: String
    ) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).frame(width: 34, alignment: .center)
            Slider(value: value, in: range, step: step)
            Text(valueText).monospacedDigit().lineLimit(1).minimumScaleFactor(0.8).frame(
                width: 54, alignment: .trailing)
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    func movementLimits(for page: ProjectPage) -> (x: Double, y: Double) {
        guard let raw = PageImagePipeline.baseImage(for: page) else { return (1, 1) }
        let image = PageImagePipeline.normalizedOrientation(raw)
        let limits = PagePlacementPolicy.placementOffsetLimits(
            paperSize: paperSize,
            normalizedImageSize: image.size,
            placementScale: page.a4WidthRatio,
            rotationDegrees: page.placementRotationDegrees
        )
        return (Double(limits.width), Double(limits.height))
    }
    func positionText(_ offset: Double, limit: Double) -> String {
        String(PagePlacementPolicy.positionDisplayValue(offset: offset, limit: limit))
    }
    func compactNumberField(value: Binding<Double>) -> some View {
        TextField(
            value: Binding(
                get: { paperUnit.displayValue(fromMM: value.wrappedValue) },
                set: { value.wrappedValue = paperUnit.millimeters(from: $0) }
            ), format: .number.precision(.fractionLength(0...2))
        ) {
            EmptyView()
        }
        .keyboardType(.decimalPad)
        .focused($focusedDimension)
        .multilineTextAlignment(.trailing)
        .textFieldStyle(.roundedBorder)
        .frame(width: 72)
        .fixedSize(horizontal: true, vertical: false)
    }

    func applyingCurrentPaper(to page: ProjectPage) -> ProjectPage {
        CompositeLayoutPolicy.applyingPaper(
            to: page,
            paperPreset: paperPreset,
            paperOrientation: paperOrientation,
            customWidthMM: customWidthMM,
            customHeightMM: customHeightMM,
            paperUnit: paperUnit
        )
    }

    func syncPaperToWorkingPages() {
        pages = appliedPages()
    }

    func appliedPages() -> [ProjectPage] {
        CompositeLayoutPolicy.applyingPaper(
            to: pages,
            paperPreset: paperPreset,
            paperOrientation: paperOrientation,
            customWidthMM: customWidthMM,
            customHeightMM: customHeightMM,
            paperUnit: paperUnit
        )
    }
    func recordSuccessfulCompositeExport() {
        if ReviewRequestTracker.recordSuccessfulExport() {
            requestReview()
        }
    }

    func requestCurrentCompositeShare() {
        if ProductSettings.shared.exportPreset == .photos {
            prepareCurrentCompositeShare()
            return
        }
        let safeName = ExportService.safeFileBaseName(outputName)
        guard !safeName.isEmpty else {
            showNameRequest = true
            return
        }
        outputName = safeName
        prepareCurrentCompositeShare()
    }

    func prepareCurrentCompositeShare() {
        guard !isPreparingShare else { return }
        isPreparingShare = true
        let snapshot = appliedPages()
        let settings = ProductSettings.shared
        let preset = settings.exportPreset
        let transparent = preset == .transparentPNG
        let colorPolicy = settings.exportColorPolicy
        let jpegQuality = settings.jpegQuality

        Task { @MainActor in
            defer { isPreparingShare = false }
            guard
                let image = ExportService.compositeImage(
                    pages: snapshot,
                    transparent: transparent,
                    longEdge: settings.effectiveLongEdge(for: preset),
                    colorPolicy: colorPolicy,
                    customPixelSize: settings.exactCustomPixelSize
                )
            else {

                return
            }

            if preset == .photos {
                do {
                    try await ExportService.saveCompositeToPhotos(image)

                    showPhotoSavedToast = true
                    Task {
                        try? await Task.sleep(for: .seconds(1.6))
                        showPhotoSavedToast = false
                    }

                    recordSuccessfulCompositeExport()
                } catch {
                    exportErrorMessage = error.localizedDescription
                    showExportError = true
                }
                return
            }

            let rootDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
                "NarabiCompositeShares", isDirectory: true)
            let directory = rootDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let data: Data
                let fileExtension: String

                switch preset {
                case .pdf:
                    data = ExportService.compositePDFData(image)
                    fileExtension = "pdf"
                case .jpeg:
                    guard let encoded = image.jpegData(compressionQuality: jpegQuality) else {

                        return
                    }
                    data = encoded
                    fileExtension = "jpg"
                case .png, .transparentPNG:
                    guard let encoded = image.pngData() else {

                        return
                    }
                    data = encoded
                    fileExtension = "png"
                case .photos:
                    return
                }

                let url = directory.appendingPathComponent(ExportService.safeFileBaseName(outputName))
                    .appendingPathExtension(fileExtension)
                try data.write(to: url, options: .atomic)

                sharePayload = CompositeSharePayload(url: url)
            } catch {
                exportErrorMessage = error.localizedDescription
                showExportError = true
            }
        }
    }
}
