import MessageUI
import SwiftUI
import UIKit

enum LegalDocument: String, Identifiable {
    case terms, privacy
    var id: String { rawValue }
    var title: String {
        self == .terms ? L10n.text("legal.terms", "利用規約") : L10n.text("legal.privacy", "プライバシーポリシー")
    }
    var resourceBase: String { self == .terms ? "Terms" : "Privacy" }
}

struct LegalDocumentView: View {
    let document: LegalDocument
    private var content: String {
        let language = L10n.legalDocumentLanguage
        let name = "\(document.resourceBase)_\(language)"
        let url =
            Bundle.main.url(forResource: name, withExtension: "md", subdirectory: "Legal")
            ?? Bundle.main.url(forResource: name, withExtension: "md")
        guard let url, let text = try? String(contentsOf: url, encoding: .utf8) else {
            return L10n.text("legal.unavailable", "文書を読み込めませんでした。")
        }
        return text
    }
    var body: some View {
        ScrollView {
            Text(.init(content)).frame(maxWidth: .infinity, alignment: .leading).textSelection(.enabled)
                .padding()
        }.navigationTitle(document.title).navigationBarTitleDisplayMode(.inline)
    }
}

struct AboutView: View {
    var body: some View {
        List {
            Section {
                VStack(spacing: 10) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 46))
                        .foregroundStyle(.tint)
                    Text(L10n.text("app.name", "並び替えでポン"))
                        .font(.title2.bold())
                    Text(
                        L10n.text(
                            "about.summary",
                            "PDFや画像をページ単位で整理し、必要な形式へ出力するローカルアプリです。"
                        )
                    )
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical)
            }

            Section(L10n.text("about.policy.title", "提供方針")) {
                Label(L10n.text("about.policy.free", "全機能無料"), systemImage: "checkmark.circle")
                Label(L10n.text("about.policy.noAds", "広告なし"), systemImage: "checkmark.circle")
                Label(L10n.text("about.policy.noAccount", "アカウント不要"), systemImage: "checkmark.circle")
            }

            Section(L10n.text("about.data.title", "データの取扱い")) {
                Text(
                    L10n.text(
                        "about.data.summary",
                        "プロジェクトやOCR結果は原則として端末内で処理します。AI用ファイルは自動送信されず、共有先は利用者が選びます。"
                    )
                )
            }

            Section(L10n.text("about.developer", "開発・運営")) {
                Text(verbatim: "Mexenixi")
            }

            Section(L10n.text("about.development.title", "開発について")) {
                Text(
                    L10n.text(
                        "about.development.summary",
                        "開発にはAIによる実装支援を利用しています。要件、設計、検証、公開判断は開発者が行っています。"
                    )
                )
            }

            Section(L10n.text("about.documents.title", "アプリ内の文書")) {
                NavigationLink(L10n.text("about.documents.terms", "アプリ内の利用規約")) {
                    LegalDocumentView(document: .terms)
                }
                NavigationLink(L10n.text("about.documents.privacy", "アプリ内のプライバシーポリシー")) {
                    LegalDocumentView(document: .privacy)
                }
            }

            Section {
                LabeledContent(L10n.text("about.version", "バージョン"), value: AppInfo.version)
            }
        }
        .navigationTitle(L10n.text("about.title", "このアプリについて"))
    }
}

enum AppInfo {
    static var version: String {
        let version =
            Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct ContactMailView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var opened = false
    @State private var copied = false
    private var mailURL: URL? {
        var components = URLComponents()
        components.scheme = "mailto"
        components.path = "mexenixi@gmail.com"
        components.queryItems = [
            URLQueryItem(name: "subject", value: "Narabi Support"),
            URLQueryItem(
                name: "body",
                value: [
                    "✎", "", "--------------------------------",
                    "Narabi \(AppInfo.version) | \(UIDevice.current.model) | \(UIDevice.current.systemName) \(UIDevice.current.systemVersion) | \(L10n.effectiveLanguage)",
                    "--------------------------------",
                ].joined(separator: "\r\n")),
        ]
        return components.url
    }
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "envelope").font(.system(size: 48))
                Text(L10n.text("contact.fallback", "メールアプリが開かない場合は、メールアドレスをコピーしてください。"))
                    .multilineTextAlignment(.center)
                Button(L10n.text("contact.openMail", "メールアプリを開く")) { openMail() }
                    .buttonStyle(.borderedProminent)
                Button(
                    copied ? L10n.text("contact.copied", "コピーしました") : L10n.text("contact.copy", "メールアドレスをコピー")
                ) {
                    UIPasteboard.general.string = "mexenixi@gmail.com"
                    copied = true
                }.buttonStyle(.bordered)
                Text(verbatim: "mexenixi@gmail.com").textSelection(.enabled).font(.callout.monospaced())
            }.padding()
                .navigationTitle(L10n.text("contact.title", "お問い合わせ"))
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(L10n.text("common.close", "閉じる")) { dismiss() }
                    }
                }
                .task {
                    if !opened {
                        opened = true
                        openMail()
                    }
                }
        }
    }
    private func openMail() {
        guard let mailURL else { return }
        UIApplication.shared.open(mailURL)
    }
}
