import SwiftUI

enum AppPublicLinks {
    static let website = URL(string: "https://by.mexenixi.workers.dev/")!
    static let product = URL(string: "https://by.mexenixi.workers.dev/products/narabi/")!
    static let support = URL(string: "https://by.mexenixi.workers.dev/support/")!
    static let privacy = URL(string: "https://by.mexenixi.workers.dev/products/narabi/privacy/")!
    static let terms = URL(string: "https://by.mexenixi.workers.dev/products/narabi/terms/")!
    static let commercialTransactions = URL(
        string: "https://by.mexenixi.workers.dev/commercial-transactions/"
    )!
    static let github = URL(string: "https://github.com/mexenixi/narabi")!
    static let youtube = URL(string: "https://www.youtube.com/@Mexenixi")!
    static let instagram = URL(string: "https://www.instagram.com/mexenixi/")!
    static let x = URL(string: "https://x.com/mexenixi")!
    static let tiktok = URL(string: "https://www.tiktok.com/@mexenixi")!
}

struct AppPublicLinksSection: View {
    private let links: [(String, String, URL)] = [
        ("info.website", "公式サイト", AppPublicLinks.website),
        ("info.product", "製品ページ", AppPublicLinks.product),
        ("info.support", "サポート", AppPublicLinks.support),
        ("info.privacy", "プライバシーポリシー", AppPublicLinks.privacy),
        ("info.terms", "利用規約", AppPublicLinks.terms),
        ("info.commercial", "特定商取引法に基づく表示", AppPublicLinks.commercialTransactions),
        ("info.github", "GitHub", AppPublicLinks.github),
        ("info.youtube", "YouTube", AppPublicLinks.youtube),
        ("info.instagram", "Instagram", AppPublicLinks.instagram),
        ("info.x", "X", AppPublicLinks.x),
        ("info.tiktok", "TikTok", AppPublicLinks.tiktok),
    ]

    var body: some View {
        Section(L10n.text("info.links", "公式リンク")) {
            ForEach(links, id: \.2) { key, fallback, url in
                Link(destination: url) {
                    Text(L10n.text(key, fallback))
                }
            }
        }
    }
}
