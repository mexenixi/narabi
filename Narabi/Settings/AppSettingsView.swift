import SwiftUI

struct AppLanguageOption: Identifiable, Hashable {
    let id: String
    let name: String
    static let all: [AppLanguageOption] = [
        .init(id: "system", name: ""),
        .init(id: "ja", name: "日本語"), .init(id: "en", name: "English"),
        .init(id: "zh-Hans", name: "简体中文"), .init(id: "zh-Hant", name: "繁體中文"),
        .init(id: "ko", name: "한국어"), .init(id: "es", name: "Español"),
        .init(id: "fr", name: "Français"), .init(id: "de", name: "Deutsch"),
        .init(id: "pt-BR", name: "Português (Brasil)"), .init(id: "it", name: "Italiano"),
        .init(id: "nl", name: "Nederlands"), .init(id: "pl", name: "Polski"),
        .init(id: "ru", name: "Русский"), .init(id: "uk", name: "Українська"),
        .init(id: "tr", name: "Türkçe"), .init(id: "id", name: "Bahasa Indonesia"),
        .init(id: "th", name: "ไทย"), .init(id: "vi", name: "Tiếng Việt"),
        .init(id: "ar", name: "العربية"),
        .init(id: "he", name: "עברית"),
        .init(id: "hi", name: "हिन्दी"),
    ]

    static var displayOrder: [AppLanguageOption] {
        let system = all.first { $0.id == "system" }
        let languages = all.filter { $0.id != "system" }.sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
        return system.map { [$0] + languages } ?? languages
    }
}

struct AppSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appearance: AppearanceSettings
    @AppStorage(L10n.languageKey) private var appLanguage = "system"
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("settings.display", "表示")) {
                    Picker(L10n.text("settings.appearance", "外観"), selection: $appearance.appearance) {
                        Text(L10n.text("settings.appearance.system", "自動")).tag(AppAppearance.system)
                        Text(L10n.text("settings.appearance.light", "ライト")).tag(AppAppearance.light)
                        Text(L10n.text("settings.appearance.dark", "ダーク")).tag(AppAppearance.dark)
                    }
                    .pickerStyle(.segmented)
                }
                Section(L10n.text("settings.language", "言語")) {
                    Picker(L10n.text("settings.language", "言語"), selection: $appLanguage) {
                        ForEach(AppLanguageOption.displayOrder) { option in
                            Text(
                                option.id == "system" ? L10n.text("language.system", "端末の設定に従う") : option.name
                            )
                            .tag(option.id)
                        }
                    }
                    .pickerStyle(.menu)
                    Text(L10n.text("settings.systemLanguageNote", "一部の機能は、端末の言語で表示される場合があります。"))
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Section(L10n.text("settings.information", "情報")) {
                    NavigationLink {
                        AboutView()
                    } label: {
                        Label(L10n.text("about.title", "このアプリについて"), systemImage: "info.circle")
                    }
                    LabeledContent(L10n.text("about.version", "バージョン"), value: AppInfo.version)
                }
                AppPublicLinksSection()
            }
            .navigationTitle(L10n.text("settings.appTitle", "アプリ設定"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.done", "完了")) { dismiss() }
                        .accessibilityIdentifier("settings.done")
                }
            }
        }
    }
}

struct AIReadSettingsSection: View {
    @StateObject private var settings = AIReadSettings.shared
    var body: some View {
        Section(L10n.text("settings.aiRead", "AI読み取り方式")) {
            Picker(selection: $settings.mode) {
                Text(L10n.text("settings.aiPDF", "PDF読み取り")).tag(AIReadMode.pdf)
                Text(L10n.text("settings.aiText", "テキスト読み取り")).tag(AIReadMode.text)
            } label: {
                EmptyView()
            }.pickerStyle(.segmented)
            if settings.mode == .pdf {
                Picker(selection: $settings.pdfQuality) {
                    Text(L10n.text("settings.highQuality", "高精度")).tag(AIPDFQuality.high)
                    Text(L10n.text("settings.lightweight", "軽量")).tag(AIPDFQuality.light)
                } label: {
                    EmptyView()
                }.pickerStyle(.segmented)
            } else {
                Picker(selection: $settings.ocrPreparation) {
                    Text(L10n.text("settings.ocrBasic", "そのまま")).tag(AIOCRPreparation.basic)
                    Text(L10n.text("settings.ocrCorrected", "補正する")).tag(AIOCRPreparation.corrected)
                } label: {
                    EmptyView()
                }.pickerStyle(.segmented)
            }
        }
    }
}
