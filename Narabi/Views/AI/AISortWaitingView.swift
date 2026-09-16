import SwiftUI

struct AISortWaitingView: View {
    @AppStorage("aiShareSafetyAcknowledged") private var safetyAcknowledged = false
    @State private var showSafetyDetails = false
    @State private var showSafetyConfirmation = false

    @Binding var prompt: String
    let hasPackage: Bool
    @Binding var resultText: String
    let createAIFile: () -> Void
    let isCreating: Bool
    let creationProgress: ExportProgress?
    let cancelCreation: () -> Void
    let apply: () -> Void
    let cancel: () -> Void

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 38))
                    .foregroundStyle(.tint)
                    .accessibilityHidden(true)
                Text(L10n.text("ai.title", "AI並べ替え"))
                    .font(.title2.bold())
                Text(L10n.text("ai.prompt", "並べ替えの基準"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.headline)
                TextEditor(text: $prompt)
                    .frame(minHeight: 120, maxHeight: 180)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(.secondary.opacity(0.4)))

                if isCreating {
                    ProgressView(
                        value: Double(creationProgress?.completed ?? 0),
                        total: Double(max(creationProgress?.total ?? 1, 1))
                    )
                    Text(creationProgress?.message ?? L10n.text("processing", "処理中"))
                    Button(L10n.text("common.cancel", "キャンセル"), role: .destructive, action: cancelCreation)
                } else {
                    VStack(spacing: 8) {
                        Button(action: beginCreatingAIFile) {
                            Label(
                                L10n.text("ai.createFile", "AI用ファイルを作成"),
                                systemImage: "square.and.arrow.up"
                            )
                        }
                        .buttonStyle(.borderedProminent)

                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Image(systemName: "exclamationmark.shield")
                                .foregroundStyle(.orange)
                                .accessibilityHidden(true)
                            Text(
                                L10n.text(
                                    "ai.shareSafety.short",
                                    "AI用ファイルにはページ画像またはOCRテキストが含まれます。共有前に個人情報や機密情報を確認してください。"
                                )
                            )
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            Button(L10n.text("ai.shareSafety.details", "詳しく見る")) {
                                showSafetyDetails = true
                            }
                            .font(.footnote.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }

                Text(
                    L10n.text(
                        "ai.steps",
                        "共有先のAIへ作成したファイルを渡し、質問に回答してください。最後にAIが生成したコード欄、または2本の線の間にある1行をコピーして、下へ貼り付けます。"
                    )
                )
                .frame(maxWidth: .infinity, alignment: .leading)
                .font(.callout)

                Text(L10n.text("ai.result", "AIの最終結果"))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .font(.headline)
                HStack(spacing: 8) {
                    TextField(
                        L10n.text("ai.result.placeholder", "結果の1行を貼り付け"),
                        text: $resultText,
                        axis: .horizontal
                    )
                    .font(.system(.caption, design: .monospaced))
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1)
                    .submitLabel(.done)
                    Button {
                        resultText = UIPasteboard.general.string ?? ""
                    } label: {
                        Image(systemName: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(L10n.text("ai.paste", "貼り付け"))
                }
                Button(L10n.text("ai.apply", "結果を確認して適用"), action: apply)
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        !hasPackage || resultText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(L10n.text("common.cancel", "キャンセル"), role: .destructive, action: cancel)
            }
            .padding()
        }
        .scrollDismissesKeyboard(.interactively)
        .interactiveDismissDisabled(true)
        .sheet(isPresented: $showSafetyDetails) {
            NavigationStack {
                ScrollView {
                    Text(
                        L10n.text(
                            "ai.shareSafety.full",
                            [
                                "AI用ファイルには、対象ページの画像またはOCRテキスト、並べ替え条件、",
                                "セッション識別子、ページ識別子、現在の順序が含まれます。",
                                "送信先は共有シートで利用者が選択し、並び替えでポンは送信先を記録しません。",
                                "共有前に、個人情報、機密情報、第三者の情報が含まれていないか確認してください。",
                                "共有後の保存、利用、学習、削除は、選択した外部サービスの",
                                "利用規約とプライバシーポリシーに従います。",
                            ].joined()
                        )
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
                .navigationTitle(L10n.text("ai.shareSafety.title", "外部AIへの共有について"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(L10n.text("common.done", "完了")) {
                            showSafetyDetails = false
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            L10n.text("ai.shareSafety.confirmTitle", "外部サービスへ共有します"),
            isPresented: $showSafetyConfirmation,
            titleVisibility: .visible
        ) {
            Button(L10n.text("ai.shareSafety.confirmAction", "確認して作成")) {
                safetyAcknowledged = true
                createAIFile()
            }
            Button(L10n.text("common.cancel", "キャンセル"), role: .cancel) {}
        } message: {
            Text(
                L10n.text(
                    "ai.shareSafety.confirmMessage",
                    "AI用ファイルにはページ画像またはOCRテキストが含まれます。個人情報や機密情報を確認してから、共有先を選んでください。"
                ))
        }
    }

    private func beginCreatingAIFile() {
        if safetyAcknowledged {
            createAIFile()
        } else {
            showSafetyConfirmation = true
        }
    }
}
