import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

struct EditorView: View {
    @EnvironmentObject var store: ProjectStore
    @Environment(\.scenePhase) var scenePhase
    @Environment(\.requestReview) var requestReview

    let projectID: UUID
    let close: () -> Void

    @StateObject var importProgress = ImportProgressState()
    @State var project = NarabiProject()
    @State var outputNameDraft = ""
    @FocusState var outputNameFocused: Bool
    @State var isClosingEditor = false
    @State var orderText = ""
    @State var undoStack: [NarabiProject] = []
    @State var redoStack: [NarabiProject] = []

    @State var editorSelectionMode = false
    @State var traySelectionMode = false
    @State var editorSelection: [UUID] = []
    @State var compositeEntrySelection: [UUID] = []
    @State var traySelection: [UUID] = []

    @State var pendingTrayDrop: PendingTrayDrop?

    @State var tappedPage: ProjectPage?
    @State var tappedArea: DragArea = .editor
    @State var editingPage: EditingTarget?
    @State var showDeleted = false

    @State var photoSelections: [PhotosPickerItem] = []
    @State var showPDFPicker = false

    @State var showInvalidOrder = false
    @State var showNameRequest = false
    @State var shareURL: URL?
    @State var pagePreview: EditorPagePreviewItem?
    @State var showSettings = false
    @State var showScanner = false
    @State var exportPreset: ExportPreset = ProductSettings.shared.exportPreset
    @State var mergePages = ProductSettings.shared.mergePagesForExport
    @State var compositePreview: CompositePreviewItem?
    @State var showCompositeWarning = false
    @State var showCompositeEditor = false
    @State var shareItems: [Any] = []
    @State var normalImageExportDirectory: URL?
    @State var countPendingSharedExport = false
    @State var exportProgress: ExportProgress?
    @State var exportTask: Task<Void, Never>?
    @State var showPhotoSavedToast = false
    @State var aiMode = false
    @State var aiPromptDraft = ProductSettings.shared.aiSortingPrompt
    @State var activeAIRequest: ActiveAISortRequest?
    @State var activeAIFileURL: URL?
    @State var aiResultText = ""
    @State var aiCreationProgress: ExportProgress?
    @State var aiCreationTask: Task<Void, Never>?
    @State var aiErrorMessage = ""
    @State var showAIError = false
    @State var exportErrorMessage = ""
    @State var showExportError = false
    @State var importResultMessage = ""
    @State var showImportResult = false
    @State var pendingAIOrder: [String] = []
    @State var pendingAIReason = ""
    @State var showAIConfirmation = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 8) {
                if aiMode {
                    AISortWaitingView(
                        prompt: Binding(
                            get: { aiPromptDraft },
                            set: { value in
                                aiPromptDraft = value
                                ProductSettings.shared.setCustomAIPrompt(value)
                            }
                        ),
                        hasPackage: activeAIRequest != nil && activeAIFileURL != nil,
                        resultText: $aiResultText,
                        createAIFile: createAndShareAIFile,
                        isCreating: aiCreationTask != nil,
                        creationProgress: aiCreationProgress,
                        cancelCreation: { aiCreationTask?.cancel() },
                        apply: applyAIResult,
                        cancel: cancelAIRequest
                    )
                } else {
                    topControls
                    workspaceBoard
                    trayButtons
                }
            }
            .navigationTitle(Text(verbatim: ""))
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                if !aiMode {
                    ToolbarItem(placement: .topBarLeading) {
                        Button {
                            closeEditorImmediately()
                        } label: {
                            Image(systemName: "chevron.backward")
                        }
                        .accessibilityLabel(L10n.text("common.back", "戻る"))
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showSettings = true
                        } label: {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(L10n.text("settings.editorTitle", "編集設定"))
                    }
                }
            }
            .interactiveDismissDisabled(true)
            .overlay { ImportProgressOverlay(progress: importProgress) }
            .onAppear {
                if let stored = store.project(id: projectID) {
                    project = stored
                    outputNameDraft = stored.outputName
                }
            }
            .onChange(of: outputNameFocused) { _, focused in
                if !focused, !isClosingEditor {
                    commitOutputName()
                    save()
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .background {
                    commitOutputName()
                    save()
                }
            }
            .onDisappear {
                guard !isClosingEditor else { return }
                commitOutputName()
                save()
            }
            .onChange(of: photoSelections) { _, selections in
                Task { await addPhotosToTray(selections) }
            }
            .fileImporter(
                isPresented: $showPDFPicker,
                allowedContentTypes: [.pdf, .image, .plainText, .content],
                allowsMultipleSelection: true,
                onCompletion: { result in
                    Task { await addFilesToTray(result) }
                }
            )
            .confirmationDialog(
                L10n.text("page.actions", "ページの操作"),
                isPresented: Binding(
                    get: { tappedPage != nil },
                    set: { if !$0 { tappedPage = nil } }
                )
            ) {
                pageMenuButtons
            }
            .confirmationDialog(
                L10n.text("page.placementMethod", "配置方法"),
                isPresented: Binding(
                    get: { pendingTrayDrop != nil },
                    set: { if !$0 { pendingTrayDrop = nil } }
                )
            ) {
                dropMenuButtons
            }
            .sheet(item: $editingPage) { target in
                PageEditView(item: target.item) { changed in
                    applyPageEdit(target: target, changed: changed)
                }
            }
            .sheet(isPresented: $showDeleted) {
                DeletedItemsView(items: $project.deleted) { changedItems in
                    checkpoint()
                    project.deleted = changedItems.deleted
                    project.tray.append(contentsOf: changedItems.restored)
                    save()
                }
            }
            .fullScreenCover(item: $pagePreview) { preview in
                EditorPagePreviewView(item: preview)
            }
            .alert(L10n.text("error.invalidInput", "入力が無効です"), isPresented: $showInvalidOrder) {
                Button(role: .cancel) {
                } label: {
                    Text(verbatim: "OK")
                }
            }
            .alert(L10n.text("export.nameRequired", "出力名を入力してください"), isPresented: $showNameRequest) {
                TextField(L10n.text("export.name", "出力名"), text: $outputNameDraft)
                Button(L10n.text("export.action", "出力")) {
                    outputNameDraft = outputNameDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !outputNameDraft.isEmpty else {
                        showNameRequest = true
                        return
                    }
                    commitOutputName()
                    save()
                    performExport()
                }
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
            }
            .sheet(
                isPresented: Binding(
                    get: { shareURL != nil || !shareItems.isEmpty },
                    set: { presented in
                        if !presented {
                            shareURL = nil
                            shareItems = []
                            normalImageExportDirectory = nil
                        }
                    }
                )
            ) {
                let outputItems = shareURL.map { [$0] } ?? shareItems
                ShareSheet(
                    items: outputItems,
                    onPresented: {

                    },
                    onCompleted: { _, completed, error in
                        if countPendingSharedExport {
                            if completed && error == nil { recordSuccessfulExport() } else {}
                            countPendingSharedExport = false
                        }
                    }
                )
            }
            .fullScreenCover(isPresented: $showCompositeEditor) {
                CompositeLayoutEditor(
                    pages: pagesForCompositeEditing,
                    outputName: $outputNameDraft,
                    onCancel: { showCompositeEditor = false },
                    onSave: { updated in
                        checkpoint()
                        applyCompositePages(updated)
                        let enteredIDs = Set(compositeEntrySelection)
                        editorSelection = updated.map(\.id).filter { enteredIDs.contains($0) }
                        commitOutputName()
                        save()
                        showCompositeEditor = false
                    }
                )
            }
            .sheet(item: $compositePreview) { item in
                CompositeExportPreview(
                    image: item.image,
                    preset: $exportPreset,
                    rebuild: { preset in
                        ExportService.compositeImage(
                            pages: pagesForOutput,
                            transparent: preset == .transparentPNG,
                            longEdge: ProductSettings.shared.effectiveLongEdge(for: preset),
                            colorPolicy: ProductSettings.shared.exportColorPolicy,
                            customPixelSize: ProductSettings.shared.exactCustomPixelSize
                        )
                    },
                    onCancel: { compositePreview = nil },
                    onExport: { exportComposite() }
                )
            }
            .alert(L10n.text("merge.warning.title", "縦横比が異なります"), isPresented: $showCompositeWarning) {
                Button(L10n.text("merge.preview", "プレビューを確認")) {
                    compositeEntrySelection = editorSelection
                    showCompositeEditor = true
                }
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
            } message: {
                Text(L10n.text("merge.warning.message", "先頭ページを基準に物理サイズ比を保って重ねます。キャンバス外は切り取られます。"))
            }
            .sheet(isPresented: $showSettings) { ProductSettingsView() }
            .fullScreenCover(isPresented: $showScanner) {
                DocumentScanner { images in addScansToTray(images) }
            }
            .alert(L10n.text("error.invalidInput", "入力が無効です"), isPresented: $showExportError) {
                Button(role: .cancel) {
                } label: {
                    Text(verbatim: "OK")
                }
            } message: {
                Text(exportErrorMessage)
            }
            .alert(
                L10n.text("import.result.title", "読み込み結果"),
                isPresented: $showImportResult
            ) {
                Button(L10n.text("common.ok", "OK")) {}
            } message: {
                Text(importResultMessage)
            }
            .alert(L10n.text("ai.error", "AI結果を適用できません"), isPresented: $showAIError) {
                Button(role: .cancel) {
                } label: {
                    Text(verbatim: "OK")
                }
            } message: {
                Text(aiErrorMessage)
            }
            .alert(L10n.text("ai.confirm.title", "AIの並べ替え結果"), isPresented: $showAIConfirmation) {
                Button(L10n.text("ai.apply", "結果を確認して適用")) { commitPendingAIResult() }
                Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {
                    pendingAIOrder = []
                    pendingAIReason = ""
                }
            } message: {
                Text(
                    pendingAIReason.isEmpty
                        ? L10n.text("ai.confirm.noReason", "並べ替え結果を適用しますか？") : pendingAIReason)
            }

            .overlay(alignment: .top) {
                if showPhotoSavedToast {
                    Text(L10n.text("export.photoSaved", "写真に保存しました"))
                        .padding(.horizontal, 16).padding(.vertical, 10)
                        .background(.ultraThinMaterial, in: Capsule()).padding(.top, 8)
                }
            }
            .overlay {
                if let exportProgress {
                    ProcessingOverlay(progress: exportProgress) {
                        exportTask?.cancel()
                        self.exportProgress = nil
                    }
                }
            }
        }
    }
}
