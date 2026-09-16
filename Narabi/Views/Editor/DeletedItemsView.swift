import SwiftUI

struct DeletedItemsChange {
    let deleted: [ProjectPage]
    let restored: [ProjectPage]
}

struct DeletedItemsView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var items: [ProjectPage]
    let commit: (DeletedItemsChange) -> Void
    @State private var selectionMode = false
    @State private var selectedIDs: [UUID] = []
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        NavigationStack {
            VStack {
                HStack {
                    Text(L10n.text("deleted.title", "削除済み")).font(.headline)
                    Spacer()
                    if selectionMode, !selectedIDs.isEmpty {
                        Button(L10n.text("deleted.restore", "復元")) { restoreSelection() }
                        Button(L10n.text("deleted.permanent", "完全削除"), role: .destructive) {
                            permanentlyDeleteSelection()
                        }
                    }
                    Button(selectionMode ? L10n.text("common.done", "完了") : L10n.text("common.select", "選択"))
                    {
                        selectionMode.toggle()
                        if !selectionMode { selectedIDs.removeAll() }
                    }
                }
                .padding(.horizontal)

                ScrollView {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(items) { item in
                            ZStack(alignment: .bottomTrailing) {
                                if let image = UIImage(data: item.renderedData) {
                                    Image(uiImage: PageColorRenderer.render(image, mode: item.colorMode))
                                        .resizable().scaledToFit().background(.white)
                                }
                                if let number = selectedIDs.firstIndex(of: item.id).map({ $0 + 1 }) {
                                    Text(verbatim: String(number))
                                        .font(.caption.bold())
                                        .frame(width: 27, height: 27)
                                        .background(.tint)
                                        .foregroundStyle(.white)
                                        .clipShape(Circle())
                                        .padding(4)
                                }
                            }
                            .aspectRatio(0.72, contentMode: .fit)
                            .background(.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .contentShape(Rectangle())
                            .onTapGesture {
                                guard selectionMode else { return }
                                if let index = selectedIDs.firstIndex(of: item.id) {
                                    selectedIDs.remove(at: index)
                                } else {
                                    selectedIDs.append(item.id)
                                }
                            }
                        }
                    }
                    .padding(8)
                }
            }
            .navigationTitle(L10n.text("deleted.title", "削除済み"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L10n.text("common.close", "閉じる")) { dismiss() }
                }
            }
        }
    }

    private func restoreSelection() {
        let restored = selectedIDs.compactMap { id in items.first { $0.id == id } }
        let remaining = items.filter { !selectedIDs.contains($0.id) }
        commit(DeletedItemsChange(deleted: remaining, restored: restored))
        items = remaining
        selectedIDs.removeAll()
    }

    private func permanentlyDeleteSelection() {
        let remaining = items.filter { !selectedIDs.contains($0.id) }
        commit(DeletedItemsChange(deleted: remaining, restored: []))
        items = remaining
        selectedIDs.removeAll()
    }
}
