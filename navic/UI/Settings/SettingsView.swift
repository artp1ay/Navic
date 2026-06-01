import AppKit
import SwiftUI

struct SettingsView: View {

    @Bindable var settings: AppSettings
    @Bindable var coordinator: PlayerCoordinator

    var body: some View {
        TabView {
            ConnectionTab(settings: settings, coordinator: coordinator)
                .tabItem { Label("Navidrome", systemImage: "network") }
            PresetsTab(settings: settings)
                .modifier(RequiresCredentialsModifier(configured: areCredentialsConfigured))
                .tabItem { Label("Presets", systemImage: "square.stack.3d.up") }
            WidgetTab(settings: settings)
                .modifier(RequiresCredentialsModifier(configured: areCredentialsConfigured))
                .tabItem { Label("Widget", systemImage: "macwindow") }
            ArtworkTab(settings: settings)
                .modifier(RequiresCredentialsModifier(configured: areCredentialsConfigured))
                .tabItem { Label("Artwork", systemImage: "photo") }
            TypographyTab(settings: settings)
                .modifier(RequiresCredentialsModifier(configured: areCredentialsConfigured))
                .tabItem { Label("Typography", systemImage: "textformat") }
            AboutTab()
                .tabItem { Label("About", systemImage: "info.circle") }
        }
        .frame(minWidth: 760, idealWidth: 820, maxWidth: 900, minHeight: 580, idealHeight: 620, maxHeight: 720)
    }

    /// "Configured" = the credentials are structurally complete (URL parses,
    /// username and password present). This deliberately does NOT depend on
    /// whether the server is currently reachable — a dropped network connection
    /// should not lock the user out of widget settings they already had working.
    private var areCredentialsConfigured: Bool {
        settings.credentials != nil
    }
}

private struct RequiresCredentialsModifier: ViewModifier {
    let configured: Bool

    func body(content: Content) -> some View {
        ZStack {
            content
                .disabled(!configured)
                .opacity(configured ? 1 : 0.4)
            if !configured {
                VStack(spacing: 8) {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.secondary)
                    Text("Configure Navidrome server credentials to access widget settings.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(20)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .padding(40)
            }
        }
    }
}

private struct ConnectionTab: View {
    @Bindable var settings: AppSettings
    @Bindable var coordinator: PlayerCoordinator
    @State private var draft: ServerDraft = .init()
    @State private var pingResult: String?
    @State private var isTesting: Bool = false
    @State private var status: ConnectionStatus = .checking

    var body: some View {
        Form {
            Section {
                ConnectionStatusBanner(status: status)
            }

            Section("Server") {
                TextField("Server URL", text: $draft.serverURLString, prompt: Text("https://navidrome.example.com"))
                    .textContentType(.URL)
                TextField("Username", text: $draft.username)
                    .textContentType(.username)
                SecureField("Password", text: $draft.password)
                    .textContentType(.password)
                Toggle(isOn: $draft.ignoreSSLErrors) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ignore SSL certificate errors")
                        Text("Use only for self-signed or private Navidrome certificates.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                HStack(spacing: 10) {
                    Button {
                        applyDraft()
                    } label: {
                        Text("Apply")
                    }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.return, modifiers: [.command])
                    .disabled(!isDraftDirty)

                    Button {
                        Task { await testConnection() }
                    } label: {
                        if isTesting {
                            ProgressView().controlSize(.small)
                        }
                        Text(isTesting ? "Testing..." : "Test connection")
                    }
                    .disabled(isTesting)

                    if let pingResult {
                        Text(pingResult)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Button("Revert") {
                        draft = ServerDraft(settings: settings)
                    }
                    .buttonStyle(.link)
                    .foregroundStyle(isDraftDirty ? Color.red : Color.red.opacity(0.35))
                    .disabled(!isDraftDirty)
                }
                if isDraftDirty {
                    Text("You have unsaved changes. Press Apply to connect with the new credentials.")
                        .font(.footnote)
                        .foregroundStyle(.orange)
                }
            }

            Section("App icon") {
                HStack(spacing: 14) {
                    ForEach(AppIconVariant.allCases) { variant in
                        AppIconChoice(
                            variant: variant,
                            isSelected: settings.appIconVariant == variant
                        ) {
                            settings.appIconVariant = variant
                            AppIconManager.apply(variant)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Diagnostics") {
                LabeledContent("Active", value: coordinator.resolvedMode.badgeText)
                LabeledContent("Track", value: coordinator.track?.title ?? "—")
                LabeledContent("Artist", value: coordinator.track?.artist ?? "—")
                LabeledContent("Last error", value: coordinator.lastError ?? "—")
                Button("Reload player") { coordinator.refreshNow() }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear { draft = ServerDraft(settings: settings) }
        .task { await refreshStatus() }
        .task(id: credentialsStatusKey) { await refreshStatus() }
    }

    private var isDraftDirty: Bool {
        draft != ServerDraft(settings: settings)
    }

    private var credentialsStatusKey: String {
        "\(settings.serverURLString)|\(settings.username)|\(settings.password)|\(settings.ignoreSSLErrors)"
    }

    private func applyDraft() {
        settings.serverURLString = draft.serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.username = draft.username.trimmingCharacters(in: .whitespacesAndNewlines)
        settings.password = draft.password
        settings.ignoreSSLErrors = draft.ignoreSSLErrors
        pingResult = nil
    }

    private func testConnection() async {
        isTesting = true
        defer { isTesting = false }
        // Test the DRAFT, not the saved settings — lets the user verify before applying.
        let testCredentials: NavidromeCredentials? = {
            guard let url = URL(string: draft.serverURLString.trimmingCharacters(in: .whitespacesAndNewlines)),
                  url.scheme != nil,
                  !draft.username.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !draft.password.isEmpty else { return nil }
            return NavidromeCredentials(
                serverURL: url,
                username: draft.username.trimmingCharacters(in: .whitespacesAndNewlines),
                password: draft.password,
                ignoreSSLErrors: draft.ignoreSSLErrors
            )
        }()

        guard let credentials = testCredentials else {
            pingResult = "Enter a valid URL, username and password first."
            return
        }
        let client = NavidromeAPIClient(credentials: credentials)
        do {
            let ok = try await client.ping()
            pingResult = ok ? "Connected." : "Server responded with an error."
        } catch {
            pingResult = error.localizedDescription
        }
    }

    private func refreshStatus() async {
        guard let credentials = settings.credentials else {
            status = .failed(title: "Not configured", message: "Enter a valid server URL, username, and password.")
            return
        }

        status = .checking
        let client = NavidromeAPIClient(credentials: credentials)
        do {
            let ok = try await client.ping()
            status = ok
                ? .connected
                : .failed(title: "Connection failed", message: "Server responded with an error.")
        } catch {
            status = .failed(title: "Connection failed", message: error.localizedDescription)
        }
    }
}

private struct ServerDraft: Equatable {
    var serverURLString: String = ""
    var username: String = ""
    var password: String = ""
    var ignoreSSLErrors: Bool = false

    init() {}

    @MainActor
    init(settings: AppSettings) {
        self.serverURLString = settings.serverURLString
        self.username = settings.username
        self.password = settings.password
        self.ignoreSSLErrors = settings.ignoreSSLErrors
    }
}

private struct AppIconChoice: View {
    let variant: AppIconVariant
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Image(nsImage: AppIconManager.image(for: variant) ?? NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: 64, height: 64)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.white, .blue)
                            .offset(x: 5, y: -5)
                    }
                }
                Text(variant.displayName)
                    .font(.caption)
                    .foregroundStyle(.primary)
            }
            .frame(width: 96)
            .padding(.vertical, 8)
            .background {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: isSelected ? 1.5 : 1)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Use \(variant.displayName) app icon")
    }
}

private enum ConnectionStatus: Equatable {
    case checking
    case connected
    case failed(title: String, message: String)
}

private struct ConnectionStatusBanner: View {
    let status: ConnectionStatus

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            Image(systemName: iconName)
                .font(.system(size: 32, weight: .semibold))
                .foregroundStyle(iconColor)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private var iconName: String {
        switch status {
        case .checking: return "clock"
        case .connected: return "checkmark.circle.fill"
        case .failed: return "xmark.octagon.fill"
        }
    }

    private var iconColor: Color {
        switch status {
        case .checking: return .secondary
        case .connected: return .green
        case .failed: return .red
        }
    }

    private var title: String {
        switch status {
        case .checking: return "Checking Navidrome"
        case .connected: return "Connected"
        case .failed(let title, _): return title
        }
    }

    private var message: String {
        switch status {
        case .checking: return "Testing the configured server."
        case .connected: return "Navidrome is reachable with the current credentials."
        case .failed(_, let message): return message
        }
    }
}

private struct PresetsTab: View {
    @Bindable var settings: AppSettings
    @State private var saveDialogVisible = false
    @State private var renameDialogTarget: UserWidgetStylePreset?
    @State private var pendingName: String = ""

    var body: some View {
        Form {
            Section("Your presets") {
                Button {
                    pendingName = defaultNameForNewPreset()
                    saveDialogVisible = true
                } label: {
                    Label("Save current settings as preset…", systemImage: "plus.circle.fill")
                }

                if settings.userPresets.isEmpty {
                    Text("You haven't saved any custom presets yet. Tweak the Widget / Artwork / Typography tabs to your taste, then capture the look here.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(settings.userPresets) { preset in
                        userPresetRow(preset)
                    }
                }
            }

            Section("Built-in presets") {
                ForEach(WidgetStylePreset.all) { preset in
                    builtInPresetRow(preset)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .alert("Save preset", isPresented: $saveDialogVisible) {
            TextField("Preset name", text: $pendingName)
            Button("Save") {
                settings.addUserPreset(name: pendingName, values: WidgetStyleValues(settings: settings))
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Capture every current Widget, Artwork and Typography value under a name. You can rename or remove it later.")
        }
        .alert("Rename preset", isPresented: renameAlertIsPresented) {
            TextField("Preset name", text: $pendingName)
            Button("Rename") {
                if let target = renameDialogTarget {
                    settings.renameUserPreset(id: target.id, to: pendingName)
                }
                renameDialogTarget = nil
            }
            Button("Cancel", role: .cancel) {
                renameDialogTarget = nil
            }
        }
    }

    private var renameAlertIsPresented: Binding<Bool> {
        Binding(
            get: { renameDialogTarget != nil },
            set: { if !$0 { renameDialogTarget = nil } }
        )
    }

    private func defaultNameForNewPreset() -> String {
        let existing = settings.userPresets.count + 1
        return "My preset \(existing)"
    }

    private func isUserPresetSelected(_ preset: UserWidgetStylePreset) -> Bool {
        preset.values == WidgetStyleValues(settings: settings)
    }

    @ViewBuilder
    private func userPresetRow(_ preset: UserWidgetStylePreset) -> some View {
        let selected = isUserPresetSelected(preset)
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name).font(.headline)
                Text("Custom")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button("Apply") { preset.values.apply(to: settings) }
            }
            Menu {
                Button("Update with current settings") {
                    settings.updateUserPreset(id: preset.id, values: WidgetStyleValues(settings: settings))
                }
                Button("Rename…") {
                    pendingName = preset.name
                    renameDialogTarget = preset
                }
                Divider()
                Button("Delete", role: .destructive) {
                    settings.deleteUserPreset(id: preset.id)
                }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
        .padding(.vertical, 3)
    }

    @ViewBuilder
    private func builtInPresetRow(_ preset: WidgetStylePreset) -> some View {
        let selected = preset.isSelected(settings)
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                Text(preset.name).font(.headline)
                Text(preset.description)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if selected {
                Label("Selected", systemImage: "checkmark.circle.fill")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.green)
            } else {
                Button("Apply") { preset.apply(settings) }
            }
        }
        .padding(.vertical, 3)
    }
}

private struct WidgetStylePreset: Identifiable {
    let id: String
    let name: String
    let description: String
    let values: WidgetStyleValues

    @MainActor
    func apply(_ settings: AppSettings) {
        values.apply(to: settings)
    }

    func isSelected(_ settings: AppSettings) -> Bool {
        values == WidgetStyleValues(settings: settings)
    }

    static let all: [WidgetStylePreset] = [
        WidgetStylePreset(
            id: "sleeve-glass",
            name: "Sleeve Glass",
            description: "Default-style horizontal sleeve with artwork backdrop and a regular shadow.",
            values: WidgetStyleValues(
                widgetLayout: .horizontal,
                widgetBackgroundStyle: .artwork,
                widgetBackgroundOpacity: 0.82,
                widgetBackgroundBlur: 18,
                widgetCornerRadius: 18,
                artworkSize: 96,
                artworkCornerRadius: 12,
                artworkShadowStyle: .regular,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 14,
                showArtwork: true,
                showText: true,
                showAlbum: true,
                widgetWidthMode: .automatic,
                textAreaWidth: 260,
                textSize: .medium,
                textStyle: .system,
                textColorStyle: .automatic,
                textAlignmentStyle: .leading,
                trackInfoLayout: .twoLines
            )
        ),
        WidgetStylePreset(
            id: "minimal-strip",
            name: "Minimal Strip",
            description: "Transparent floating strip — small cover with rounded compact text, no chrome.",
            values: WidgetStyleValues(
                widgetLayout: .horizontal,
                widgetBackgroundStyle: .transparent,
                widgetBackgroundOpacity: 1.0,
                widgetBackgroundBlur: 0,
                widgetCornerRadius: 0,
                artworkSize: 58,
                artworkCornerRadius: 8,
                artworkShadowStyle: .subtle,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 10,
                showArtwork: true,
                showText: true,
                showAlbum: false,
                widgetWidthMode: .automatic,
                textAreaWidth: 240,
                textSize: .small,
                textStyle: .rounded,
                textColorStyle: .automatic,
                textAlignmentStyle: .leading,
                trackInfoLayout: .twoLines
            )
        ),
        WidgetStylePreset(
            id: "vinyl-display",
            name: "Vinyl Display",
            description: "Vertical vinyl-box presentation on a deep glass surface, centered metadata.",
            values: WidgetStyleValues(
                widgetLayout: .vertical,
                widgetBackgroundStyle: .glass,
                widgetBackgroundOpacity: 0.62,
                widgetBackgroundBlur: 28,
                widgetCornerRadius: 24,
                artworkSize: 180,
                artworkCornerRadius: 6,
                artworkShadowStyle: .deep,
                artworkPresentationEffect: .vinylBox,
                artworkTextSpacing: 14,
                showArtwork: true,
                showText: true,
                showAlbum: true,
                widgetWidthMode: .automatic,
                textAreaWidth: 320,
                textSize: .large,
                textStyle: .rounded,
                textColorStyle: .automatic,
                textAlignmentStyle: .center,
                trackInfoLayout: .threeLines
            )
        ),
        WidgetStylePreset(
            id: "cd-edition",
            name: "CD Edition",
            description: "Horizontal CD-case artwork on a dark card with high-contrast white text.",
            values: WidgetStyleValues(
                widgetLayout: .horizontal,
                widgetBackgroundStyle: .dark,
                widgetBackgroundOpacity: 0.88,
                widgetBackgroundBlur: 0,
                widgetCornerRadius: 16,
                artworkSize: 112,
                artworkCornerRadius: 4,
                artworkShadowStyle: .regular,
                artworkPresentationEffect: .cdCase,
                artworkTextSpacing: 16,
                showArtwork: true,
                showText: true,
                showAlbum: true,
                widgetWidthMode: .automatic,
                textAreaWidth: 300,
                textSize: .medium,
                textStyle: .system,
                textColorStyle: .white,
                textAlignmentStyle: .leading,
                trackInfoLayout: .threeLines
            )
        ),
        WidgetStylePreset(
            id: "editorial-serif",
            name: "Editorial Serif",
            description: "Calm light card with serif typography and full four-line metadata.",
            values: WidgetStyleValues(
                widgetLayout: .horizontal,
                widgetBackgroundStyle: .light,
                widgetBackgroundOpacity: 0.94,
                widgetBackgroundBlur: 0,
                widgetCornerRadius: 14,
                artworkSize: 108,
                artworkCornerRadius: 6,
                artworkShadowStyle: .subtle,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 16,
                showArtwork: true,
                showText: true,
                showAlbum: true,
                widgetWidthMode: .custom,
                textAreaWidth: 340,
                textSize: .medium,
                textStyle: .serif,
                textColorStyle: .black,
                textAlignmentStyle: .leading,
                trackInfoLayout: .fourLines
            )
        ),
        WidgetStylePreset(
            id: "mono-console",
            name: "Mono Console",
            description: "Text-only monospaced console with a wide custom width and four metadata lines.",
            values: WidgetStyleValues(
                widgetLayout: .textOnly,
                widgetBackgroundStyle: .dark,
                widgetBackgroundOpacity: 0.78,
                widgetBackgroundBlur: 0,
                widgetCornerRadius: 8,
                artworkSize: 0,
                artworkCornerRadius: 0,
                artworkShadowStyle: .none,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 0,
                showArtwork: false,
                showText: true,
                showAlbum: true,
                widgetWidthMode: .custom,
                textAreaWidth: 380,
                textSize: .small,
                textStyle: .monospaced,
                textColorStyle: .white,
                textAlignmentStyle: .leading,
                trackInfoLayout: .fourLines
            )
        ),
        WidgetStylePreset(
            id: "hero-cover",
            name: "Hero Cover",
            description: "Floating poster — huge transparent artwork only, deep shadow on the desktop.",
            values: WidgetStyleValues(
                widgetLayout: .vertical,
                widgetBackgroundStyle: .transparent,
                widgetBackgroundOpacity: 1.0,
                widgetBackgroundBlur: 0,
                widgetCornerRadius: 0,
                artworkSize: 240,
                artworkCornerRadius: 18,
                artworkShadowStyle: .deep,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 0,
                showArtwork: true,
                showText: false,
                showAlbum: false,
                widgetWidthMode: .automatic,
                textAreaWidth: 260,
                textSize: .medium,
                textStyle: .system,
                textColorStyle: .white,
                textAlignmentStyle: .center,
                trackInfoLayout: .twoLines
            )
        ),
        WidgetStylePreset(
            id: "center-stage",
            name: "Center Stage",
            description: "Vertical glass card with large rounded artwork and centered headline text.",
            values: WidgetStyleValues(
                widgetLayout: .vertical,
                widgetBackgroundStyle: .glass,
                widgetBackgroundOpacity: 0.66,
                widgetBackgroundBlur: 22,
                widgetCornerRadius: 28,
                artworkSize: 156,
                artworkCornerRadius: 42,
                artworkShadowStyle: .subtle,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 14,
                showArtwork: true,
                showText: true,
                showAlbum: false,
                widgetWidthMode: .automatic,
                textAreaWidth: 280,
                textSize: .large,
                textStyle: .rounded,
                textColorStyle: .automatic,
                textAlignmentStyle: .center,
                trackInfoLayout: .twoLines
            )
        ),
        WidgetStylePreset(
            id: "wide-card",
            name: "Wide Card",
            description: "Roomy horizontal card with extra-large type and a fixed wide text column.",
            values: WidgetStyleValues(
                widgetLayout: .horizontal,
                widgetBackgroundStyle: .glass,
                widgetBackgroundOpacity: 0.74,
                widgetBackgroundBlur: 24,
                widgetCornerRadius: 22,
                artworkSize: 132,
                artworkCornerRadius: 16,
                artworkShadowStyle: .regular,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 20,
                showArtwork: true,
                showText: true,
                showAlbum: true,
                widgetWidthMode: .custom,
                textAreaWidth: 440,
                textSize: .extraLarge,
                textStyle: .system,
                textColorStyle: .automatic,
                textAlignmentStyle: .leading,
                trackInfoLayout: .twoLines
            )
        ),
        WidgetStylePreset(
            id: "transparent-poster",
            name: "Transparent Poster",
            description: "No background, square cover, centered three-line caption — pure desktop overlay.",
            values: WidgetStyleValues(
                widgetLayout: .vertical,
                widgetBackgroundStyle: .transparent,
                widgetBackgroundOpacity: 1.0,
                widgetBackgroundBlur: 0,
                widgetCornerRadius: 0,
                artworkSize: 168,
                artworkCornerRadius: 10,
                artworkShadowStyle: .regular,
                artworkPresentationEffect: .none,
                artworkTextSpacing: 12,
                showArtwork: true,
                showText: true,
                showAlbum: true,
                widgetWidthMode: .automatic,
                textAreaWidth: 280,
                textSize: .medium,
                textStyle: .serif,
                textColorStyle: .white,
                textAlignmentStyle: .center,
                trackInfoLayout: .threeLines
            )
        )
    ]
}


private struct WidgetTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Window") {
                Toggle("Keep mini-player always on top", isOn: $settings.alwaysOnTop)
                Toggle("Show Dock icon", isOn: $settings.showDockIcon)
                Toggle("Hide widget when idle", isOn: $settings.hideWidgetWhenIdle)
            }

            Section("Presentation") {
                Toggle("Show artwork", isOn: showArtworkBinding)
                Toggle("Show text", isOn: showTextBinding)
                Picker("Layout", selection: $settings.widgetLayout) {
                    ForEach(WidgetLayout.allCases) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
                Picker("Background", selection: $settings.widgetBackgroundStyle) {
                    ForEach(WidgetBackgroundStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Slider(value: $settings.widgetBackgroundOpacity, in: 0.15...1) {
                    Text("Background opacity")
                }
                .disabled(isBackgroundDisabled)
                .opacity(isBackgroundDisabled ? 0.45 : 1)
                Slider(value: $settings.widgetBackgroundBlur, in: 0...32) {
                    Text("Background blur")
                }
                .disabled(isBackgroundDisabled)
                .opacity(isBackgroundDisabled ? 0.45 : 1)
                Slider(value: $settings.widgetCornerRadius, in: 0...40) {
                    Text("Corner radius")
                }
                .disabled(isBackgroundDisabled)
                .opacity(isBackgroundDisabled ? 0.45 : 1)
                Picker("Width", selection: $settings.widgetWidthMode) {
                    ForEach(WidgetWidthMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                if settings.widgetWidthMode == .custom {
                    Slider(value: $settings.textAreaWidth, in: 160...640) {
                        Text("Text width")
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    private var isBackgroundDisabled: Bool {
        settings.widgetBackgroundStyle == .transparent
    }

    private var showArtworkBinding: Binding<Bool> {
        Binding(
            get: { settings.showArtwork },
            set: { newValue in
                if !newValue && !settings.showText {
                    settings.showText = true
                }
                settings.showArtwork = newValue
            }
        )
    }

    private var showTextBinding: Binding<Bool> {
        Binding(
            get: { settings.showText },
            set: { newValue in
                if !newValue && !settings.showArtwork {
                    settings.showArtwork = true
                }
                settings.showText = newValue
            }
        )
    }
}

private struct ArtworkTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Cover") {
                Picker("Artwork effect", selection: $settings.artworkPresentationEffect) {
                    ForEach(ArtworkPresentationEffect.allCases) { effect in
                        Text(effect.displayName).tag(effect)
                    }
                }
                Slider(value: $settings.artworkSize, in: 48...320) {
                    Text("Size")
                }
                Slider(value: $settings.artworkTextSpacing, in: 0...40) {
                    Text("Text spacing")
                }
                Slider(value: $settings.artworkCornerRadius, in: 0...40) {
                    Text("Corners")
                }
                .disabled(areOverlayControlsLocked)
                .opacity(areOverlayControlsLocked ? 0.45 : 1)
                Picker("Shadow", selection: $settings.artworkShadowStyle) {
                    ForEach(ArtworkShadowStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                .disabled(areOverlayControlsLocked)
                .opacity(areOverlayControlsLocked ? 0.45 : 1)
                if areOverlayControlsLocked {
                    Text("Corners and shadow don't apply to the \(settings.artworkPresentationEffect.displayName) effect — the artwork already has its own silhouette.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    /// The CD case, vinyl box and cassette overlays carry their own corner
    /// shapes and pre-rendered depth cues, so both the corner-radius slider
    /// and the shadow picker become no-ops when any of them is selected.
    private var areOverlayControlsLocked: Bool {
        switch settings.artworkPresentationEffect {
        case .cdCase, .vinylBox, .cassette: return true
        case .none: return false
        }
    }
}

private struct TypographyTab: View {
    @Bindable var settings: AppSettings

    var body: some View {
        Form {
            Section("Track text") {
                Picker("Size", selection: $settings.textSize) {
                    ForEach(TrackTextSize.allCases) { size in
                        Text(size.displayName).tag(size)
                    }
                }
                .pickerStyle(.segmented)
                Picker("Font", selection: $settings.textStyle) {
                    ForEach(TrackTextStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Picker("Text color", selection: $settings.textColorStyle) {
                    ForEach(TrackTextColorStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Picker("Alignment", selection: $settings.textAlignmentStyle) {
                    ForEach(TrackTextAlignmentStyle.allCases) { style in
                        Text(style.displayName).tag(style)
                    }
                }
                Picker("Info layout", selection: $settings.trackInfoLayout) {
                    ForEach(TrackInfoLayout.allCases) { layout in
                        Text(layout.displayName).tag(layout)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

private struct AboutTab: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .center, spacing: 18) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 128, height: 128)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                VStack(spacing: 4) {
                    Text("Navic")
                        .font(.largeTitle.bold())
                    Text(appVersionString)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                AboutBody()
                    .frame(maxWidth: 560)
            }
            .padding(32)
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var appVersionString: String {
        let info = Bundle.main.infoDictionary
        let version = info?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = info?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }
}

private struct AboutBody: View {
    private static let projectURL = URL(string: "https://github.com/artp1ay/navic")!
    private static let authorURL = URL(string: "https://freakware.ru")!
    private static let licenseURL = URL(string: "https://github.com/freakware/navic/blob/main/LICENSE")!
    private static let navidromeURL = URL(string: "https://www.navidrome.org/")!
    private static let subsonicURL = URL(string: "https://www.subsonic.org/pages/api.jsp")!

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Navic is a lightweight read-only now-playing widget for Navidrome on macOS. It quietly displays the track currently playing on your Navidrome server — title, artist, album and artwork — without ever taking over playback control.")
                Text("It sits on the desktop as a floating mini-player, polls your Navidrome instance over the Subsonic API, and keeps the cover art in sync with whatever is queued on the server. Connection details are stored securely in the macOS keychain; the app does not phone home or collect telemetry.")
            }
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)

            GroupBox {
                VStack(alignment: .leading, spacing: 8) {
                    aboutRow(label: "Source code", url: Self.projectURL, display: "github.com/artp1ay/navic")
                    aboutRow(label: "Author", url: Self.authorURL, display: "freakware.ru")
                    aboutRow(label: "License", url: Self.licenseURL, display: "MIT")
                }
                .padding(.vertical, 4)
            }

            HStack(spacing: 12) {
                Link("Navidrome", destination: Self.navidromeURL)
                Text("·").foregroundStyle(.secondary)
                Link("Subsonic API", destination: Self.subsonicURL)
            }
            .font(.callout)

            Text("© 2026 Freakware. Released under the MIT License. Navidrome and the Subsonic API are trademarks of their respective owners.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func aboutRow(label: String, url: URL, display: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Link(display, destination: url)
            Spacer(minLength: 0)
        }
        .font(.callout)
    }
}
