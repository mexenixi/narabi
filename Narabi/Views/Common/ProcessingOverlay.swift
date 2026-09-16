import SwiftUI

struct ProcessingOverlay: View {
    let progress: ExportProgress
    let cancel: () -> Void
    var body: some View {
        ZStack {
            Color.black.opacity(0.28).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView(value: Double(progress.completed), total: Double(max(progress.total, 1)))
                Text(progress.message).monospacedDigit()
                Button(L10n.text("common.cancel", "キャンセル"), role: .destructive, action: cancel)
            }.padding(24).background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16)).padding()
        }
    }
}
