import SwiftUI
import YadoSearchCore

/// Which sites to search, chosen by ticking them.
///
/// A segmented control could not hold "楽天トラベル" in English — "Rakuten
/// Tr…" — and there is no shorter name for it that is still its name. A list
/// has room, and it says what the three states are without abbreviating any of
/// them.
///
/// **The last tick cannot be cleared.** A search of no sites is not a search,
/// so the row that would empty the set is disabled rather than allowed and then
/// rejected. Where both cannot be searched at once — an area belongs to one
/// site's scheme — ticking one clears the other instead of adding to it.
struct SearchScopePicker: View {
    @Binding var scope: SearchScope
    /// `false` while an area is being picked: its codes name one site, and
    /// there is nothing to send the other.
    let allowsBoth: Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(Provider.allCases) { provider in
                        row(provider)
                    }
                } footer: {
                    Text(footer)
                }
            }
            .navigationTitle("検索先")
            #if !os(macOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了") { dismiss() }
                }
            }
        }
    }

    private func row(_ provider: Provider) -> some View {
        Button {
            toggle(provider)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: isOn(provider) ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isOn(provider) ? Color.accentColor : Color.secondary)
                Text(provider.title)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier(YadoAccessibilityID.searchScope(provider.rawValue))
        .disabled(isLastTicked(provider))
    }

    private func isOn(_ provider: Provider) -> Bool {
        scope == .both || scope.provider == provider
    }

    /// The one keeping the search alive: turning it off would leave nothing to
    /// ask, so it does not respond.
    private func isLastTicked(_ provider: Provider) -> Bool {
        scope != .both && scope.provider == provider
    }

    private func toggle(_ provider: Provider) {
        if isOn(provider) {
            // Only reachable from `.both`, the single case where dropping one
            // leaves the other.
            scope = SearchScope(provider == .jalan ? .rakuten : .jalan)
        } else {
            scope = allowsBoth ? .both : SearchScope(provider)
        }
    }

    private var footer: String {
        if !allowsBoth {
            return String(localized: "エリアの区分は2つのサイトで別物で、コードを変換できません。どちらか一方をえらびます。")
        }
        switch scope {
        case .both: return String(localized: "両方をさがし、同じ宿は1件にまとめます。")
        case .jalan, .rakuten: return String(localized: "\(scope.title)だけをさがします。")
        }
    }
}

#Preview {
    SearchScopePicker(scope: .constant(.both), allowsBoth: true)
}
