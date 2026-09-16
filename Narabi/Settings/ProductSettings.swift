import Combine
import SwiftUI

@MainActor
final class ProductSettings: ObservableObject {
    static let shared = ProductSettings()
    @AppStorage("exportPreset") var exportPresetRaw = ExportPreset.pdf.rawValue
    @AppStorage("mergePagesForExport") var mergePagesForExport = false
    @AppStorage("exportLongEdge") var exportLongEdgeRaw = ExportLongEdge.px2048.rawValue
    @AppStorage("exportCustomPixelWidth") var exportCustomPixelWidth = 1024
    @AppStorage("exportCustomPixelHeight") var exportCustomPixelHeight = 1024
    @AppStorage("jpegQuality") var jpegQuality = 0.88
    @AppStorage("exportColorPolicy") var exportColorPolicyRaw = ExportColorPolicy.perPage.rawValue
    @AppStorage("aiSortingPromptCustom") private var aiSortingPromptCustom = ""
    @AppStorage("aiSortingPromptWasCustomized") private var aiSortingPromptWasCustomized = false
    @AppStorage("aiIncludeReason") var aiIncludeReason = true

    var aiSortingPrompt: String {
        get {
            aiSortingPromptWasCustomized
                ? aiSortingPromptCustom
                : L10n.text("ai.defaultPrompt", "書類の種類、日付、表裏の連続性を考慮し、提出資料として自然な順番に並べてください。")
        }
        set { setCustomAIPrompt(newValue) }
    }
    var isUsingDefaultAIPrompt: Bool { !aiSortingPromptWasCustomized }
    func setCustomAIPrompt(_ value: String) {
        aiSortingPromptCustom = value
        aiSortingPromptWasCustomized = true
        objectWillChange.send()
    }
    func resetAIPrompt() {
        aiSortingPromptCustom = ""
        aiSortingPromptWasCustomized = false
        objectWillChange.send()
    }
    var exportColorPolicy: ExportColorPolicy {
        get { ExportColorPolicy(rawValue: exportColorPolicyRaw) ?? .perPage }
        set { exportColorPolicyRaw = newValue.rawValue }
    }
    var exportPreset: ExportPreset {
        get { ExportPreset(rawValue: exportPresetRaw) ?? .pdf }
        set { exportPresetRaw = newValue.rawValue }
    }
    var exportLongEdge: ExportLongEdge {
        get { ExportLongEdge(rawValue: exportLongEdgeRaw) ?? .px2048 }
        set { exportLongEdgeRaw = newValue.rawValue }
    }
    var exactCustomPixelSize: CGSize? {
        switch exportLongEdge {
        case .custom:
            return CGSize(
                width: CGFloat(min(max(exportCustomPixelWidth, 16), 16_384)),
                height: CGFloat(min(max(exportCustomPixelHeight, 16), 16_384))
            )
        case .px800x600:
            return CGSize(width: 800, height: 600)
        case .px1024x768:
            return CGSize(width: 1024, height: 768)
        case .px1280x720:
            return CGSize(width: 1280, height: 720)
        case .px1920x1080:
            return CGSize(width: 1920, height: 1080)
        case .px2048x2048:
            return CGSize(width: 2048, height: 2048)
        case .px2560x1440:
            return CGSize(width: 2560, height: 1440)
        case .px2688x1242:
            return CGSize(width: 2688, height: 1242)
        case .px2752x2064:
            return CGSize(width: 2752, height: 2064)
        case .px3840x2160:
            return CGSize(width: 3840, height: 2160)
        case .px4096x4096:
            return CGSize(width: 4096, height: 4096)
        default:
            return nil
        }
    }
    func effectiveLongEdge(for preset: ExportPreset) -> ExportLongEdge {
        if preset == .photos && exportLongEdge == .custom { return .px2048 }
        return exactCustomPixelSize == nil ? exportLongEdge : .custom
    }
}

struct ProductSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var settings = ProductSettings.shared
    @State private var promptDraft = ProductSettings.shared.aiSortingPrompt
    @FocusState private var pixelNumberFieldIsFocused: Bool
    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.text("settings.export", "出力")) {
                    Picker(L10n.text("settings.defaultFormat", "既定形式"), selection: $settings.exportPresetRaw)
                    {
                        ForEach(ExportPreset.allCases) { value in
                            Label(
                                L10n.text(value.titleKey, value.rawValue.uppercased()),
                                systemImage: value.symbol
                            ).tag(value.rawValue)
                        }
                    }
                    if let preset = ExportPreset(rawValue: settings.exportPresetRaw) {
                        if preset == .jpeg || preset == .png || preset == .transparentPNG || preset == .photos
                        {
                            Picker(
                                L10n.text("settings.imageSize", "画像サイズ"),
                                selection: Binding(
                                    get: { settings.exportLongEdgeRaw },
                                    set: {
                                        settings.objectWillChange.send()
                                        settings.exportLongEdgeRaw = $0
                                    })
                            ) {
                                Text(L10n.text("settings.original", "元サイズ"))
                                    .tag(ExportLongEdge.original.rawValue)
                                if preset == .jpeg || preset == .png || preset == .transparentPNG {
                                    Text(L10n.text("settings.imageSize.custom", "カスタム"))
                                        .tag(ExportLongEdge.custom.rawValue)
                                }
                                Divider()
                                ForEach(ExportLongEdge.allCases.filter { $0.rawValue > 0 }) { value in
                                    Text(verbatim: "\(value.rawValue) px").tag(value.rawValue)
                                }
                                if preset == .jpeg || preset == .png || preset == .transparentPNG {
                                    Divider()
                                    Text(verbatim: "800 × 600 px").tag(ExportLongEdge.px800x600.rawValue)
                                    Text(verbatim: "1024 × 768 px").tag(ExportLongEdge.px1024x768.rawValue)
                                    Text(verbatim: "1280 × 720 px").tag(ExportLongEdge.px1280x720.rawValue)
                                    Text(verbatim: "1920 × 1080 px").tag(ExportLongEdge.px1920x1080.rawValue)
                                    Text(verbatim: "2048 × 2048 px").tag(ExportLongEdge.px2048x2048.rawValue)
                                    Text(verbatim: "2560 × 1440 px").tag(ExportLongEdge.px2560x1440.rawValue)
                                    Text(verbatim: "2688 × 1242 px").tag(ExportLongEdge.px2688x1242.rawValue)
                                    Text(verbatim: "2752 × 2064 px").tag(ExportLongEdge.px2752x2064.rawValue)
                                    Text(verbatim: "3840 × 2160 px").tag(ExportLongEdge.px3840x2160.rawValue)
                                    Text(verbatim: "4096 × 4096 px").tag(ExportLongEdge.px4096x4096.rawValue)
                                }
                            }
                        }
                        if preset == .jpeg || preset == .png || preset == .transparentPNG,
                            settings.exportLongEdge == .custom
                        {
                            HStack {
                                Text(L10n.text("paper.width", "幅"))
                                Spacer()
                                TextField(
                                    value: $settings.exportCustomPixelWidth,
                                    format: .number,
                                    prompt: Text(verbatim: "1024")
                                ) {
                                    EmptyView()
                                }
                                .keyboardType(.numberPad)
                                .focused($pixelNumberFieldIsFocused)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 92)
                                Text(verbatim: "px").foregroundStyle(.secondary)
                            }
                            HStack {
                                Text(L10n.text("paper.height", "高さ"))
                                Spacer()
                                TextField(
                                    value: $settings.exportCustomPixelHeight,
                                    format: .number,
                                    prompt: Text(verbatim: "1024")
                                ) {
                                    EmptyView()
                                }
                                .keyboardType(.numberPad)
                                .focused($pixelNumberFieldIsFocused)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 92)
                                Text(verbatim: "px").foregroundStyle(.secondary)
                            }
                            Text(L10n.text("settings.imageSize.customRange", "16〜16384 pxの範囲で入力してください。"))
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Picker(
                        L10n.text("settings.outputColor", "出力カラー"), selection: $settings.exportColorPolicyRaw
                    ) {
                        Text(L10n.text("settings.color.perPage", "ページごとの設定")).tag(
                            ExportColorPolicy.perPage.rawValue)
                        Text(L10n.text("settings.color.allColor", "すべてカラー")).tag(
                            ExportColorPolicy.allColor.rawValue)
                        Text(L10n.text("settings.color.allGray", "すべてグレー")).tag(
                            ExportColorPolicy.allGrayscale.rawValue)
                        Text(L10n.text("settings.color.allMono", "すべて白黒")).tag(
                            ExportColorPolicy.allMonochrome.rawValue)
                    }
                    if ExportPreset(rawValue: settings.exportPresetRaw) == .jpeg {
                        HStack {
                            Text(L10n.text("settings.jpegQuality", "JPEG画質"))
                            Slider(
                                value: Binding(
                                    get: { settings.jpegQuality },
                                    set: {
                                        settings.objectWillChange.send()
                                        settings.jpegQuality = $0
                                    }), in: 0.55...0.98)
                            Text(settings.jpegQuality, format: .percent.precision(.fractionLength(0)))
                                .monospacedDigit()
                        }
                    }
                }
                AIReadSettingsSection()
                Section(L10n.text("settings.ai", "AI並べ替え")) {
                    TextEditor(text: $promptDraft).frame(minHeight: 170)
                        .onChange(of: promptDraft) { _, value in
                            // A language-driven refresh equals the current default and must not become custom.
                            if value != settings.aiSortingPrompt {
                                settings.setCustomAIPrompt(value)
                            }
                        }
                    Toggle(L10n.text("settings.aiReason", "短い説明を求める"), isOn: $settings.aiIncludeReason)
                    Button(L10n.text("settings.aiReset", "初期プロンプトへ戻す")) {
                        settings.resetAIPrompt()
                        promptDraft = settings.aiSortingPrompt
                    }
                }
                AppPublicLinksSection()
            }
            .navigationTitle(L10n.text("settings.editorTitle", "編集設定"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.text("common.done", "完了")) {
                        if pixelNumberFieldIsFocused {
                            pixelNumberFieldIsFocused = false
                        } else {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
