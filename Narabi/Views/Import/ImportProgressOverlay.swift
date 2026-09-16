import Combine
import SwiftUI

@MainActor
final class ImportProgressState: ObservableObject {
    @Published var isPresented = false
    @Published var phase = ""
    @Published var currentFile = 0
    @Published var totalFiles = 0
    @Published var currentUnit = 0
    @Published var totalUnits = 0
    @Published var generatedPages = 0
    @Published var cancellationRequested = false
    @Published var allowsCancellation = true

    func begin(totalFiles: Int) {
        self.totalFiles = max(totalFiles, 1)
        currentFile = 0
        currentUnit = 0
        totalUnits = 0
        generatedPages = 0
        cancellationRequested = false
        allowsCancellation = true
        phase = L10n.text("import.progress.preparing", "ファイルを準備しています")
        isPresented = true
    }

    func beginProjectPreparation(totalItems: Int, totalPages: Int) {
        totalFiles = max(totalItems, 1)
        currentFile = 0
        totalUnits = max(totalPages, 1)
        currentUnit = 0
        generatedPages = 0
        cancellationRequested = false
        allowsCancellation = false
        phase = L10n.text("import.progress.creatingProject", "ページを準備しています")
        isPresented = true
    }

    func updateProjectPreparation(item: Int, completedPages: Int) {
        currentFile = min(max(item, 0), totalFiles)
        currentUnit = min(max(completedPages, 0), totalUnits)
        generatedPages = currentUnit
    }

    func finish() {
        isPresented = false
        phase = ""
        currentFile = 0
        totalFiles = 0
        currentUnit = 0
        totalUnits = 0
        generatedPages = 0
        cancellationRequested = false
        allowsCancellation = true
    }

    func cancel() {
        cancellationRequested = true
        phase = L10n.text("import.progress.cancelling", "キャンセルしています")
    }
}

struct ImportProgressOverlay: View {
    @ObservedObject var progress: ImportProgressState

    var body: some View {
        if progress.isPresented {
            ZStack {
                Color.black.opacity(0.32).ignoresSafeArea()
                VStack(spacing: 14) {
                    ProgressView(value: overallValue, total: overallTotal)
                    Text(progress.phase).font(.headline)
                    if progress.totalFiles > 0 {
                        Text(
                            String(
                                format: L10n.text("import.progress.fileCount", "ファイル %1$lld / %2$lld"),
                                Int64(progress.currentFile), Int64(progress.totalFiles))
                        )
                        .font(.subheadline.monospacedDigit())
                    }
                    if progress.totalUnits > 0 {
                        Text(
                            String(
                                format: L10n.text("import.progress.pageCount", "ページ %1$lld / %2$lld"),
                                Int64(progress.currentUnit), Int64(progress.totalUnits))
                        )
                        .font(.subheadline.monospacedDigit())
                    }
                    if progress.generatedPages > 0 {
                        Text(
                            String(
                                format: L10n.text("import.progress.generatedCount", "%1$lldページ作成済み"),
                                Int64(progress.generatedPages))
                        )
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                    }
                    if progress.allowsCancellation {
                        Button(L10n.text("common.cancel", "キャンセル")) { progress.cancel() }
                            .buttonStyle(.bordered)
                            .disabled(progress.cancellationRequested)
                    }
                }
                .padding(24)
                .frame(maxWidth: 330)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20))
                .padding()
            }
            .transition(.opacity)
            .zIndex(1000)
        }
    }

    private var overallValue: Double {
        if progress.totalUnits > 0 { return Double(progress.currentUnit) }
        return Double(progress.currentFile)
    }

    private var overallTotal: Double {
        if progress.totalUnits > 0 { return Double(max(progress.totalUnits, 1)) }
        return Double(max(progress.totalFiles, 1))
    }
}
