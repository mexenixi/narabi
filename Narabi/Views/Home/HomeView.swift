import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var appearancePlaceholder: AppearanceSettings
    let newProject: () -> Void
    let continueProject: () -> Void
    @State private var showContact = false
    @State private var showAppSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 54))
                    .foregroundStyle(.tint)

                Text(L10n.text("app.name", "並び替えでポン"))
                    .font(.largeTitle.bold())

                Button(L10n.text("home.new", "新しく作成"), action: newProject)
                    .accessibilityIdentifier("home.newProject")
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 230)

                Button(L10n.text("home.continue", "続きから"), action: continueProject)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: 230)

                NavigationLink {
                    SupportDeveloperView()
                } label: {
                    HStack(alignment: .center, spacing: 12) {
                        Image(systemName: "heart")
                            .font(.title2)
                        Text(L10n.text("support.title", "開発を応援"))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(L10n.text("support.title", "開発を応援"))
                }
                .accessibilityIdentifier("home.support")
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: 230)
                .padding(.top, 4)
                Spacer()
                HStack(spacing: 16) {
                    Link(L10n.text("legal.terms", "利用規約"), destination: AppPublicLinks.terms)
                    Text(verbatim: "•").foregroundStyle(.tertiary)
                    Link(L10n.text("legal.privacy", "プライバシーポリシー"), destination: AppPublicLinks.privacy)
                }.font(.footnote)
                HStack(spacing: 4) {
                    Text(L10n.text("about.version", "バージョン"))
                    Text(verbatim: AppInfo.version)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showContact = true
                    } label: {
                        Image(systemName: "envelope").font(.title2)
                    }
                    .accessibilityLabel(L10n.text("contact.title", "お問い合わせ"))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAppSettings = true
                    } label: {
                        Image(systemName: "gearshape").font(.title2)
                    }
                    .accessibilityIdentifier("home.settings")
                    .accessibilityLabel(L10n.text("settings.appTitle", "アプリ設定"))
                }
            }
            .sheet(isPresented: $showContact) { ContactMailView() }
            .sheet(isPresented: $showAppSettings) {
                AppSettingsView().environmentObject(appearancePlaceholder)
            }
        }
    }
}
