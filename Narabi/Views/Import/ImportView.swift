import PDFKit
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

struct ImportView: View {
    @EnvironmentObject private var store: ProjectStore

    let cancel: () -> Void
    let confirmed: (UUID) -> Void

    @State private var items: [ImportItem] = []
    @State private var photos: [PhotosPickerItem] = []
    @State private var files = false
    @State private var previewItem: ImportPreviewItem?
    @State private var selected: [UUID] = []
    @State private var reordering = false
    @State private var processing = false
    @State private var importingPhotos = false
    @State private var photoImportCompleted = 0
    @State private var photoImportTotal = 0
    @State private var scanner = false
    @StateObject private var importProgress = ImportProgressState()
    @State private var importResultMessage = ""
    @State private var showImportResult = false

    var body: some View {
        ZStack {
            NavigationStack {
                VStack(spacing: 0) {
                    List {
                        ForEach(items) { item in
                            importRow(item)
                        }
                        .onMove { source, destination in
                            items = ImportSelectionPolicy.moved(
                                items: items,
                                fromOffsets: source,
                                toOffset: destination
                            )
                        }
                        .onDelete { offsets in
                            let state = ImportSelectionPolicy.deleting(
                                offsets: offsets,
                                items: items,
                                selected: selected
                            )
                            items = state.items
                            selected = state.selected
                        }
                    }
                    .environment(
                        \.editMode,
                        .constant(reordering ? .active : .inactive)
                    )

                    HStack {
                        PhotosPicker(
                            selection: $photos,
                            maxSelectionCount: nil,
                            matching: .images
                        ) {
                            Image(systemName: "photo.badge.plus").font(.title2)
                        }
                        .disabled(importingPhotos || processing)

                        Spacer()

                        Button {
                            beginScannerPermissionFlow()
                        } label: {
                            Image(systemName: "doc.viewfinder").font(.title2)
                        }
                        .disabled(importingPhotos || processing)

                        Spacer()

                        Button {
                            files = true
                        } label: {
                            Image(systemName: "doc.badge.plus").font(.title2)
                        }
                        .accessibilityLabel(L10n.text("import.file", "ファイルを追加"))
                        .disabled(importingPhotos || processing)
                    }
                    .padding()

                    if importingPhotos {
                        VStack(spacing: 6) {
                            ProgressView(
                                value: Double(photoImportCompleted), total: Double(max(photoImportTotal, 1)))
                            Text(verbatim: "\(photoImportCompleted) / \(photoImportTotal)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 8)
                        .accessibilityElement(children: .combine)
                    }

                    Button {
                        Task { await confirm() }
                    } label: {
                        Text(
                            processing
                                ? L10n.text("import.preparing", "準備しています")
                                : L10n.text("import.editThese", "これらを編集する")
                        )
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(items.isEmpty || processing || importingPhotos)
                    .padding(.bottom)
                }
                .navigationTitle(L10n.text("import.newProject", "新規プロジェクト"))
                .navigationBarBackButtonHidden(true)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(L10n.text("common.back", "戻る"), action: cancel)
                            .accessibilityIdentifier("import.back")
                            .disabled(processing || importingPhotos)
                    }

                    ToolbarItem(placement: .topBarTrailing) {
                        Button(
                            reordering ? L10n.text("common.done", "完了") : L10n.text("common.reorder", "並べ替え")
                        ) {
                            reordering.toggle()
                        }
                        .disabled(items.isEmpty || processing || importingPhotos)
                    }

                    ToolbarItem(placement: .bottomBar) {
                        if !selected.isEmpty {
                            Button(L10n.text("selection.delete", "選択項目を削除"), role: .destructive) {
                                let state = ImportSelectionPolicy.deletingSelected(
                                    items: items,
                                    selected: selected
                                )
                                items = state.items
                                selected = state.selected
                            }
                        }
                    }
                }
                .onChange(of: photos) { _, value in
                    guard !value.isEmpty, !importingPhotos, !processing else { return }
                    importingPhotos = true
                    photoImportCompleted = 0
                    photoImportTotal = value.count
                    Task { await addPhotos(value) }
                }
                .fileImporter(
                    isPresented: $files,
                    allowedContentTypes: [.pdf, .image, .plainText, .content],
                    allowsMultipleSelection: true,
                    onCompletion: { result in Task { await addFiles(result) } }
                )
                .fullScreenCover(item: $previewItem) { item in ImportItemPreviewView(item: item) }
                .fullScreenCover(isPresented: $scanner) {
                    DocumentScanner { images in
                        for (index, image) in images.enumerated() {
                            if let data = image.jpegData(compressionQuality: 0.88) {
                                items.append(
                                    ImportItem(
                                        kind: .image,
                                        data: data,
                                        displayName: "Scan \(index + 1)"
                                    )
                                )
                            }
                        }
                        scanner = false
                    }
                }
            }
            ImportProgressOverlay(progress: importProgress)
        }
        .alert(L10n.text("import.result.title", "読み込み結果"), isPresented: $showImportResult) {
            Button(L10n.text("common.ok", "OK")) {}
        } message: {
            Text(importResultMessage)
        }
    }

    private func beginScannerPermissionFlow() {
        switch CameraPermissionFlow.current() {
        case .allowed: scanner = true
        case .needsSystemPrompt: Task { if await CameraPermissionFlow.request() { scanner = true } }
        case .denied: CameraPermissionFlow.openSettings()
        }
    }

    private func importRow(_ item: ImportItem) -> some View {
        HStack(spacing: 10) {
            if let number = selected.firstIndex(of: item.id).map({ $0 + 1 }) {
                Text(verbatim: String(number))
                    .font(.caption.bold())
                    .frame(width: 26, height: 26)
                    .background(.tint)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }

            Image(systemName: item.kind == .pdf ? "doc.richtext" : "photo")

            Text(item.displayName)
                .lineLimit(1)

            Spacer()

            // PDFが1ページでも、画像でも、すべて確認できます。
            Button(L10n.text("common.preview", "確認")) {
                showPreview(item)
            }
            .buttonStyle(.borderless)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            toggle(item.id)
        }
    }

    private func showPreview(_ item: ImportItem) {
        previewItem = ImportPreviewItem(
            data: item.data,
            kind: item.kind,
            title: item.displayName
        )
    }

    private func toggle(_ id: UUID) {
        selected = ImportSelectionPolicy.toggled(id, selected: selected)
    }

    @MainActor
    private func addPhotos(_ value: [PhotosPickerItem]) async {
        for photo in value {
            if let data = try? await photo.loadTransferable(type: Data.self) {
                items.append(
                    ImportItem(
                        kind: .image,
                        data: data,
                        displayName: L10n.text("import.photoName", "写真")
                    )
                )
            }
            photoImportCompleted += 1
            await Task.yield()
        }
        photos = []
        importingPhotos = false
    }

    @MainActor
    private func addFiles(_ result: Result<[URL], Error>) async {
        guard case .success(let urls) = result else { return }
        importProgress.begin(totalFiles: urls.count)
        defer { importProgress.finish() }
        for (fileIndex, url) in urls.enumerated() {
            if importProgress.cancellationRequested { return }
            importProgress.currentFile = fileIndex + 1
            importProgress.phase = L10n.text(
                "import.progress.reading",
                "文書の内容を読み取っています"
            )
            do {
                items.append(contentsOf: try await NewProjectImportItemLoader.load(from: url))
            } catch is DocumentImportSafetyError {
                return
            } catch {
                continue
            }
        }
    }
    @MainActor
    private func confirm() async {
        guard !processing, !importingPhotos else { return }
        processing = true

        importProgress.beginProjectPreparation(
            totalItems: items.count,
            totalPages: NewProjectCreationService.estimatedPageCount(for: items)
        )
        defer {
            importProgress.finish()
            processing = false
        }

        let result = await NewProjectCreationService.createPages(from: items) { progress in
            importProgress.updateProjectPreparation(
                item: progress.currentItem,
                completedPages: progress.completedPages
            )
        }
        guard !result.pages.isEmpty else {
            importResultMessage = L10n.text(
                "import.result.failed", "選択した項目を読み込めませんでした。ファイル形式、内容、ファイルサイズを確認してください。")
            showImportResult = true
            return
        }
        let pages = result.pages

        importProgress.phase = L10n.text(
            "import.progress.savingProject",
            "プロジェクトを保存しています"
        )
        await Task.yield()

        var project = NarabiProject()
        project.pages = pages
        store.add(project)
        if result.isPartialSuccess {
            importResultMessage = String(
                format: L10n.text("import.result.partial", "%1$lld件中%2$lld件を追加しました。%3$lld件は読み込めませんでした。"),
                result.inputItemCount,
                result.successfulItemCount,
                result.failedItemCount
            )
            showImportResult = true
        }
        confirmed(project.id)
    }
}

// MARK: - 新規作成リストの読み取り専用プレビュー
