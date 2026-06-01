import SwiftUI

struct DiagnosticsView: View {

    @Bindable var coordinator: PlayerCoordinator

    var body: some View {
        Form {
            Section("Navidrome") {
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
                Navic now works as a read-only Navidrome widget. It polls Navidrome's now-playing endpoint for the configured user and fetches artwork from the same server when cover art is available.
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
