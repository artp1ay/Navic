import SwiftUI

struct DiagnosticsView: View {

    @Bindable var coordinator: PlayerCoordinator

    var body: some View {
        Form {
            Section("Player") {
                LabeledContent("Active", value: coordinator.resolvedMode.badgeText)
                LabeledContent("Track", value: coordinator.track?.title ?? "—")
                LabeledContent("Artist", value: coordinator.track?.artist ?? "—")
                Button("Refresh") { coordinator.refreshNow() }
            }

            Section("Last Error") {
                Text(coordinator.lastError ?? "—")
                    .foregroundStyle(coordinator.lastError == nil ? AnyShapeStyle(HierarchicalShapeStyle.secondary) : AnyShapeStyle(Color.red))
                    .lineLimit(4)
            }

            Section("Notes") {
                Text("""
                Navic mirrors the now-playing track of the integration source you pick on the Source tab — either a remote Navidrome server or the Music app running on this Mac.
                """)
                .font(.footnote)
                .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(minWidth: 480, minHeight: 480)
    }
}
