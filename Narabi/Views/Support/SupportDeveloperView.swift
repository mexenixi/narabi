import Combine
import StoreKit
import SwiftUI

@MainActor
final class SupportTransactionObserver: ObservableObject {
    @Published private(set) var completedProductID: String?
    private var updatesTask: Task<Void, Never>?
    private var processedTransactionIDs: Set<UInt64> = []

    init() {
        updatesTask = Task { [weak self] in
            for await verification in Transaction.updates {
                guard let self else { return }
                await self.process(verification)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    func purchase(_ product: Product) async -> SupportPurchasePhase {
        do {
            switch try await product.purchase() {
            case .success(let verification):
                return await process(verification) ? .succeeded : .unverified
            case .pending:
                return .pending
            case .userCancelled:
                return .idle
            @unknown default:
                return .failed(message: L10n.text("support.purchaseFailed", "購入を完了できませんでした。"))
            }
        } catch {
            return .failed(message: error.localizedDescription)
        }
    }

    func consumeCompletedProductID() -> String? {
        defer { completedProductID = nil }
        return completedProductID
    }

    @discardableResult
    private func process(_ verification: VerificationResult<StoreKit.Transaction>) async -> Bool {
        guard case .verified(let transaction) = verification,
            SupportPurchaseCatalog.contains(transaction.productID)
        else { return false }
        guard processedTransactionIDs.insert(transaction.id).inserted else { return true }
        await transaction.finish()
        completedProductID = transaction.productID
        return true
    }
}

@MainActor
final class SupportStore: ObservableObject {
    @Published private(set) var products: [Product] = []
    @Published var phase: SupportPurchasePhase = .idle
    @Published private(set) var loadFailed = false

    func load() async {
        guard products.isEmpty, !phase.isBusy else { return }
        phase = .loading
        do {
            let loaded = try await Product.products(for: SupportPurchaseCatalog.productIDs)
            products = loaded.filter { SupportPurchaseCatalog.contains($0.id) }.sorted { $0.price < $1.price }
            loadFailed = products.isEmpty
            phase =
                products.isEmpty
                ? .failed(message: L10n.text("support.loadFailed", "応援商品を読み込めませんでした。"))
                : .idle
        } catch {
            loadFailed = true
            phase = .failed(message: error.localizedDescription)
        }
    }

    func purchase(_ product: Product, transactionObserver: SupportTransactionObserver) async {
        guard phase.canStartPurchase(productID: product.id) else { return }
        phase = .purchasing(productID: product.id)
        phase = await transactionObserver.purchase(product)
    }
}

private struct SupportMessageRecord: Codable, Identifiable, Equatable {
    let id: UUID
    let message: String
    let receivedAt: Date
    let languageCode: String
    let productID: String
}

@MainActor
private final class SupportMessageHistory: ObservableObject {
    @Published private(set) var records: [SupportMessageRecord] = []
    private let defaultsKey = "support.messageHistory.v1"

    init() {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode([SupportMessageRecord].self, from: data)
        else { return }
        records = decoded.sorted { $0.receivedAt > $1.receivedAt }
    }

    func append(message: String, languageCode: String, productID: String) {
        records.insert(
            SupportMessageRecord(
                id: UUID(),
                message: message,
                receivedAt: Date(),
                languageCode: languageCode,
                productID: productID
            ),
            at: 0
        )
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    var recordedLanguages: [String] {
        Array(Set(records.map(\.languageCode))).sorted {
            SupportPageLanguage.displayName(for: $0) < SupportPageLanguage.displayName(for: $1)
        }
    }
}

private enum SupportPageLanguage {
    static let settingKey = "support.pageLanguage"
    static let followApp = "app"
    static let messageLanguages = [
        "ar", "de", "en", "es", "fr", "he", "hi", "id", "it", "ja", "ko", "nl", "pl", "pt-BR", "ru", "th",
        "tr", "uk", "vi", "zh-Hans", "zh-Hant",
    ]

    static func resolved(_ setting: String) -> String {
        setting == followApp ? L10n.effectiveLanguage : setting
    }

    static func messageLanguage(_ setting: String) -> String {
        let resolvedLanguage = resolved(setting)
        return messageLanguages.contains(resolvedLanguage) ? resolvedLanguage : "en"
    }

    static func displayName(for code: String) -> String {
        switch code {
        case "ar": return "العربية"
        case "de": return "Deutsch"
        case "en": return "English"
        case "es": return "Español"
        case "fr": return "Français"
        case "he": return "עברית"
        case "hi": return "हिन्दी"
        case "id": return "Bahasa Indonesia"
        case "it": return "Italiano"
        case "ja": return "日本語"
        case "ko": return "한국어"
        case "nl": return "Nederlands"
        case "pl": return "Polski"
        case "pt-BR": return "Português (Brasil)"
        case "ru": return "Русский"
        case "th": return "ไทย"
        case "tr": return "Türkçe"
        case "uk": return "Українська"
        case "vi": return "Tiếng Việt"
        case "zh-Hans": return "简体中文"
        case "zh-Hant": return "繁體中文"
        default: return code
        }
    }
}

private enum SupportMessageCatalog {
    static let keysByProductID: [String: [String]] = [
        "com.mexenixi.narabi.support.small": [
            "support.message.small.01", "support.message.small.02", "support.message.small.03",
        ],
        "com.mexenixi.narabi.support.medium": [
            "support.message.medium.01", "support.message.medium.02", "support.message.medium.03",
        ],
        "com.mexenixi.narabi.support.large": [
            "support.message.large.01", "support.message.large.02", "support.message.large.03",
        ],
    ]

    static func randomMessage(productID: String, languageCode: String) -> String {
        let keys = keysByProductID[productID] ?? ["support.thanks"]
        let key = keys.randomElement() ?? "support.thanks"
        return localizedText(key, languageCode: languageCode)
    }

    static func localizedText(_ key: String, languageCode: String) -> String {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
            let bundle = Bundle(path: path)
        else { return L10n.text(key, "応援ありがとうございます。") }
        return bundle.localizedString(forKey: key, value: L10n.text(key, "応援ありがとうございます。"), table: nil)
    }
}

private enum SupportHistoryFilter: Hashable {
    case all
    case language(String)
}

private struct SupportMessageHistoryView: View {
    let records: [SupportMessageRecord]
    let interfaceLanguage: String
    @State private var filter: SupportHistoryFilter = .all

    private var languages: [String] {
        Array(Set(records.map(\.languageCode))).sorted {
            SupportPageLanguage.displayName(for: $0) < SupportPageLanguage.displayName(for: $1)
        }
    }

    private var filteredRecords: [SupportMessageRecord] {
        switch filter {
        case .all: records
        case .language(let code): records.filter { $0.languageCode == code }
        }
    }

    var body: some View {
        List {
            Section {
                Picker(selection: $filter) {
                    Text(text("support.history.filter.all", fallback: "すべて")).tag(SupportHistoryFilter.all)
                    ForEach(languages, id: \.self) { code in
                        Text(SupportPageLanguage.displayName(for: code))
                            .tag(SupportHistoryFilter.language(code))
                    }
                } label: {
                    Text(text("support.history.filter.label", fallback: "表示する言語"))
                }
            }

            Section {
                ForEach(filteredRecords) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: record.message)
                            .fixedSize(horizontal: false, vertical: true)
                        Text(record.receivedAt, format: .dateTime.year().month().day().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle(text("support.history.title", fallback: "メッセージ"))
    }

    private func text(_ key: String, fallback: String) -> String {
        SupportMessageCatalog.localizedText(key, languageCode: interfaceLanguage)
    }
}

struct SupportDeveloperView: View {
    @EnvironmentObject private var transactionObserver: SupportTransactionObserver
    @StateObject private var store = SupportStore()
    @StateObject private var history = SupportMessageHistory()
    @AppStorage(SupportPageLanguage.settingKey) private var supportLanguage = SupportPageLanguage.followApp
    @State private var latestMessage: String?

    private var interfaceLanguage: String { SupportPageLanguage.messageLanguage(supportLanguage) }

    var body: some View {
        Form {
            Section {
                Picker(text("support.language.title", fallback: "応援ページの言語"), selection: $supportLanguage) {
                    Text(text("support.language.followApp", fallback: "アプリの設定に従う"))
                        .tag(SupportPageLanguage.followApp)
                    Text(verbatim: SupportPageLanguage.displayName(for: "ar")).tag("ar")
                    Text(verbatim: SupportPageLanguage.displayName(for: "de")).tag("de")
                    Text(verbatim: SupportPageLanguage.displayName(for: "en")).tag("en")
                    Text(verbatim: SupportPageLanguage.displayName(for: "es")).tag("es")
                    Text(verbatim: SupportPageLanguage.displayName(for: "fr")).tag("fr")
                    Text(verbatim: SupportPageLanguage.displayName(for: "he")).tag("he")
                    Text(verbatim: SupportPageLanguage.displayName(for: "hi")).tag("hi")
                    Text(verbatim: SupportPageLanguage.displayName(for: "id")).tag("id")
                    Text(verbatim: SupportPageLanguage.displayName(for: "it")).tag("it")
                    Text(verbatim: SupportPageLanguage.displayName(for: "ja")).tag("ja")
                    Text(verbatim: SupportPageLanguage.displayName(for: "ko")).tag("ko")
                    Text(verbatim: SupportPageLanguage.displayName(for: "nl")).tag("nl")
                    Text(verbatim: SupportPageLanguage.displayName(for: "pl")).tag("pl")
                    Text(verbatim: SupportPageLanguage.displayName(for: "pt-BR")).tag("pt-BR")
                    Text(verbatim: SupportPageLanguage.displayName(for: "ru")).tag("ru")
                    Text(verbatim: SupportPageLanguage.displayName(for: "th")).tag("th")
                    Text(verbatim: SupportPageLanguage.displayName(for: "tr")).tag("tr")
                    Text(verbatim: SupportPageLanguage.displayName(for: "uk")).tag("uk")
                    Text(verbatim: SupportPageLanguage.displayName(for: "vi")).tag("vi")
                    Text(verbatim: SupportPageLanguage.displayName(for: "zh-Hans")).tag("zh-Hans")
                    Text(verbatim: SupportPageLanguage.displayName(for: "zh-Hant")).tag("zh-Hant")
                }
            }

            Section {
                Text(text("support.description", fallback: "応援購入は任意です。すべての機能は無料で利用できます。"))
                Text(text("support.purchaseNotice", fallback: "購入しても機能やコンテンツは追加されません。自動更新はありません。"))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section {
                ForEach(store.products, id: \.id) { product in
                    Button {
                        Task { await store.purchase(product, transactionObserver: transactionObserver) }
                    } label: {
                        HStack {
                            Text(productName(product))
                            Spacer()
                            if case .purchasing(let productID) = store.phase, productID == product.id {
                                ProgressView()
                            } else {
                                Text(product.displayPrice)
                            }
                        }
                    }
                    .disabled(store.phase.isBusy)
                    .accessibilityIdentifier("support.product.\(product.id)")
                }

                if store.products.isEmpty {
                    Text(text("support.preparing", fallback: "応援商品を準備中です。"))
                    if store.loadFailed {
                        Button(text("support.retry", fallback: "再読み込み")) {
                            Task { await store.load() }
                        }
                        .accessibilityIdentifier("support.retry")
                    }
                }
            }

            messageSection

            if !history.records.isEmpty {
                Section {
                    NavigationLink {
                        SupportMessageHistoryView(
                            records: history.records, interfaceLanguage: interfaceLanguage)
                    } label: {
                        Text(text("support.history.button", fallback: "メッセージ"))
                    }
                }
            }
        }
        .accessibilityIdentifier("support.screen")
        .navigationTitle(text("support.title", fallback: "開発を応援"))
        .task { await store.load() }
        .onChange(of: transactionObserver.completedProductID) { _, productID in
            guard productID != nil else { return }
            recordCompletedPurchase()
        }
    }

    @ViewBuilder
    private var messageSection: some View {
        if let latestMessage {
            Section { Text(verbatim: latestMessage) }
        } else {
            switch store.phase {
            case .pending:
                Section { Text(text("support.pending", fallback: "購入は保留中です。承認または支払い確認後に完了します。")) }
            case .unverified:
                Section { Text(text("support.unverified", fallback: "購入を確認できませんでした。")) }
            case .failed(let message):
                Section { Text(message) }
            case .idle, .loading, .purchasing, .succeeded:
                EmptyView()
            }
        }
    }

    private func productName(_ product: Product) -> String {
        guard let key = SupportPurchaseCatalog.nameKeysByID[product.id] else { return product.displayName }
        return SupportMessageCatalog.localizedText(key, languageCode: interfaceLanguage)
    }

    private func text(_ key: String, fallback: String) -> String {
        SupportMessageCatalog.localizedText(key, languageCode: interfaceLanguage)
    }

    private func recordCompletedPurchase() {
        guard let productID = transactionObserver.consumeCompletedProductID() else { return }
        let language = interfaceLanguage
        let message = SupportMessageCatalog.randomMessage(productID: productID, languageCode: language)
        history.append(message: message, languageCode: language, productID: productID)
        latestMessage = message
    }
}
