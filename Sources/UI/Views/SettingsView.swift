import SwiftUI

struct SettingsView: View {
    /// App Store ID 347959354 — 宿さがし, first published in 2010.
    private static let appStoreID = "347959354"

    @Environment(\.yadoSearch) private var yadoSearch
    @State private var isRefreshingAreas = false
    @State private var areaRefreshMessage: String?

    private var reviewURL: URL {
        URL(string: "https://apps.apple.com/app/id\(Self.appStoreID)?action=write-review")
            ?? jalanURL
    }

    private var jalanURL: URL {
        // A literal that cannot fail to parse; the fallback keeps the view
        // free of force-unwraps all the same.
        URL(string: "https://www.jalan.net/") ?? URL(filePath: "/")
    }

    private var version: String {
        let bundle = Bundle.main
        let short = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("データ") {
                    LabeledContent("APIキー") {
                        Label(
                            yadoSearch.isConfigured ? "設定済み" : "未設定",
                            systemImage: yadoSearch.isConfigured ? "checkmark.circle" : "exclamationmark.circle"
                        )
                        .foregroundStyle(yadoSearch.isConfigured ? .green : .orange)
                    }
                    Button {
                        Task { await refreshAreas() }
                    } label: {
                        LabeledContent("地域データを更新") {
                            if isRefreshingAreas {
                                ProgressView()
                            }
                        }
                    }
                    .disabled(!yadoSearch.isConfigured || isRefreshingAreas)
                    if let areaRefreshMessage {
                        Text(areaRefreshMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Section {
                    LabeledContent("バージョン", value: version)
                    // The App Store record this ships as an update to — the one
                    // 宿さがし 2.0.4 was published under in 2010.
                    Link("App Store でレビューを書く", destination: reviewURL)
                    Link("じゃらん net", destination: jalanURL)
                } header: {
                    Text("このアプリについて")
                } footer: {
                    Text("宿の情報は「じゃらん Web サービス」から取得しています。掲載内容の正確性についてはじゃらん net をご確認ください。宿の予約ページへのリンクにはアフィリエイトプログラムを利用しています。")
                }
            }
            .formStyle(.grouped)
            .navigationTitle("設定")
        }
    }

    private func refreshAreas() async {
        guard let catalog = yadoSearch.areaCatalog else { return }
        isRefreshingAreas = true
        defer { isRefreshingAreas = false }
        do {
            let tree = try await catalog.refresh()
            areaRefreshMessage = "\(tree.regions.flatMap(\.prefectures).count)都道府県分を更新しました。"
        } catch {
            areaRefreshMessage = searchErrorMessage(for: error)
        }
    }
}

#Preview {
    SettingsView()
}
