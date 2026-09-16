import PDFKit
import Photos
import PhotosUI
import StoreKit
import SwiftUI
import UIKit
import UniformTypeIdentifiers
import VisionKit

extension EditorView {
    func beginScannerPermissionFlow() {
        switch CameraPermissionFlow.current() {
        case .allowed:
            showScanner = true
        case .needsSystemPrompt:
            Task { if await CameraPermissionFlow.request() { showScanner = true } }
        case .denied:
            CameraPermissionFlow.openSettings()
        }
    }

    var topControls: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                TextField(L10n.text("export.name", "出力名"), text: $outputNameDraft)
                    .textFieldStyle(.roundedBorder)
                    .focused($outputNameFocused)
                    .submitLabel(.done)
                    .onSubmit {
                        outputNameFocused = false
                    }
                Menu {
                    ForEach(ExportPreset.allCases) { value in
                        Button {
                            exportPreset = value
                            ProductSettings.shared.exportPreset = value
                        } label: {
                            Label(
                                L10n.text(value.titleKey, value.rawValue.uppercased()),
                                systemImage: value.symbol)
                        }
                    }
                } label: {
                    Image(systemName: exportPreset.symbol).frame(width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(
                    L10n.text("export.format", "出力形式") + " "
                        + L10n.text(exportPreset.titleKey, exportPreset.rawValue.uppercased()))
                Menu {
                    Button {
                        mergePages = false
                        ProductSettings.shared.mergePagesForExport = false
                    } label: {
                        Label(L10n.text("merge.normal", "通常出力"), systemImage: "rectangle.stack")
                    }
                    Button {
                        mergePages = true
                        ProductSettings.shared.mergePagesForExport = true
                    } label: {
                        Label(L10n.text("merge.selectedOrder", "順番に重ねる"), systemImage: "square.3.layers.3d")
                    }
                } label: {
                    Image(systemName: mergePages ? "square.3.layers.3d" : "rectangle.stack").frame(
                        width: 24, height: 24)
                }
                .buttonStyle(.bordered)
                .accessibilityLabel(
                    mergePages
                        ? L10n.text("merge.selectedOrder", "順番に重ねる") : L10n.text("merge.normal", "通常出力"))
                Button(action: performExport) { Image(systemName: "square.and.arrow.up").font(.title2) }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel(L10n.text("export.action", "出力"))
                    .disabled(project.pages.isEmpty)
            }
            ViewThatFits(in: .horizontal) {
                editorActionRow(compactAI: false)
                editorActionRow(compactAI: true)
            }
        }.padding(.horizontal)
    }

    @ViewBuilder
    func editorActionRow(compactAI: Bool) -> some View {
        HStack(spacing: 8) {
            Button {
                startAIRequest()
            } label: {
                if compactAI {
                    Text(verbatim: "AI").fontWeight(.semibold).lineLimit(1)
                } else {
                    Label(L10n.text("ai.create", "AI並べ替え"), systemImage: "sparkles.rectangle.stack")
                        .lineLimit(1).fixedSize(horizontal: true, vertical: false)
                }
            }
            .accessibilityLabel(L10n.text("ai.create", "AI並べ替え"))
            .disabled(project.pages.isEmpty)
            Spacer(minLength: 8)
            if editorSelectionMode {
                Text(verbatim: String(editorSelection.count)).font(.caption.monospacedDigit())
                    .accessibilityLabel(L10n.format("selection.count", editorSelection.count))
                Button {
                    let chosen = Set(editorSelection)
                    editorSelection.append(
                        contentsOf: project.pages.map(\.id).filter { !chosen.contains($0) })
                } label: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .accessibilityLabel(L10n.text("selection.selectAll", "全選択"))
                Button {
                    editorSelection.removeAll()
                } label: {
                    Image(systemName: "circle")
                }
                .accessibilityLabel(L10n.text("selection.clearAll", "全解除"))
                Button(role: .destructive) {
                    deleteEditorSelection()
                } label: {
                    Image(systemName: "trash")
                }
                .disabled(editorSelection.isEmpty).accessibilityLabel(
                    L10n.text("selection.delete", "選択項目を削除"))
            }
            Button {
                editorSelectionMode.toggle()
                if !editorSelectionMode { editorSelection.removeAll() }
            } label: {
                Image(systemName: editorSelectionMode ? "checkmark.circle.fill" : "checkmark.circle")
            }
            .accessibilityLabel(
                editorSelectionMode ? L10n.text("common.done", "完了") : L10n.text("common.select", "選択"))
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward").font(.title2)
            }.disabled(undoStack.isEmpty)
            Button {
                redo()
            } label: {
                Image(systemName: "arrow.uturn.forward").font(.title2)
            }.disabled(redoStack.isEmpty)
        }
    }

    var workspaceBoard: some View {
        WorkspaceBoard(
            project: $project,
            editorSelection: $editorSelection,
            traySelection: $traySelection,
            editorSelectionMode: editorSelectionMode,
            traySelectionMode: traySelectionMode,
            toggleTraySelectionMode: {
                traySelectionMode.toggle()
                if !traySelectionMode {
                    traySelection.removeAll()
                }
            },
            toggleTrayCollapsed: {
                project.isTrayCollapsed.toggle()
                save()
            },
            deleteTraySelection: {
                deleteTraySelection()
            },
            checkpoint: {
                checkpoint()
            },
            save: {
                save()
            },
            openPageMenu: { item, area in
                tappedArea = area == .editor ? .editor : .tray
                tappedPage = item
            },
            openPreview: { item, title in
                pagePreview = EditorPagePreviewItem(
                    page: item,
                    title: title
                )
            },
            requestTrayPlacement: { sourceID, destinationID in
                pendingTrayDrop = PendingTrayDrop(
                    sourceID: sourceID,
                    destinationID: destinationID
                )
            }
        )
    }

    var trayButtons: some View {
        HStack {
            PhotosPicker(
                selection: $photoSelections,
                maxSelectionCount: nil,
                matching: .images
            ) {
                Image(systemName: "photo.badge.plus").font(.title2)
            }
            .accessibilityLabel(L10n.text("import.photo", "写真を追加"))

            Button {
                showPDFPicker = true
            } label: {
                Image(systemName: "doc.badge.plus").font(.title2)
            }
            .accessibilityLabel(L10n.text("import.file", "ファイルを追加"))
            Button {
                beginScannerPermissionFlow()
            } label: {
                Image(systemName: "doc.viewfinder").font(.title2)
            }
            .accessibilityLabel(L10n.text("import.scan", "スキャン"))
            Spacer()
            Button {
                showDeleted = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "trash").font(.title2)
                    Text(verbatim: String(project.deleted.count)).monospacedDigit()
                }
            }
            .accessibilityLabel(L10n.format("deleted.accessibility", project.deleted.count))
            .disabled(project.deleted.isEmpty)
        }
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    @ViewBuilder
    var pageMenuButtons: some View {
        if let item = tappedPage {
            Button(L10n.text("common.delete", "削除"), role: .destructive) {
                checkpoint()
                remove(item.id, from: tappedArea, sendTo: .deleted)
                save()
            }
            Button(
                item.isHiddenFromPreviewAndOutput
                    ? L10n.text("page.show", "表示する") : L10n.text("page.hide", "見えなくする")
            ) {
                mutatePage(id: item.id) { $0.isHiddenFromPreviewAndOutput.toggle() }
            }
            Button(L10n.text("page.duplicate", "複製")) {
                duplicatePage(item, area: tappedArea)
            }
            Button(L10n.text("common.edit", "編集")) {
                editingPage = EditingTarget(item: item, area: tappedArea)
            }
            Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
        }
    }

    @ViewBuilder
    var dropMenuButtons: some View {
        if let drop = pendingTrayDrop {
            Button(L10n.text("common.add", "追加")) { applySingleTrayDrop(drop, action: .add) }
            Button(L10n.text("page.swap", "入れ替え")) { applySingleTrayDrop(drop, action: .swap) }
            Button(L10n.text("page.replace", "更新")) { applySingleTrayDrop(drop, action: .update) }
            Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
        }
    }
}
