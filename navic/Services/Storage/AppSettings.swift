import Foundation
import CoreGraphics
import Observation
import OSLog

enum WidgetLayout: String, CaseIterable, Identifiable, Codable {
    case horizontal
    case vertical
    case textOnly

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .horizontal: return "Horizontal"
        case .vertical: return "Vertical"
        case .textOnly: return "Text only"
        }
    }
}

enum AppIconVariant: String, CaseIterable, Identifiable {
    case `default`
    case light
    case tinted

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .default: return "Default"
        case .light: return "Light"
        case .tinted: return "Tinted"
        }
    }

    var previewAssetName: String {
        switch self {
        case .default: return "AppIconPreviewDefault"
        case .light: return "AppIconPreviewLight"
        case .tinted: return "AppIconPreviewTinted"
        }
    }
}

enum WidgetBackgroundStyle: String, CaseIterable, Identifiable, Codable {
    case transparent
    case glass
    case artwork
    case dark
    case light

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .transparent: return "None"
        case .glass: return "Glass"
        case .artwork: return "Artwork"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}

enum ArtworkShadowStyle: String, CaseIterable, Identifiable, Codable {
    case none
    case subtle
    case regular
    case deep

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .subtle: return "Subtle"
        case .regular: return "Regular"
        case .deep: return "Deep"
        }
    }
}

enum ArtworkPresentationEffect: String, CaseIterable, Identifiable, Codable {
    case none
    case cdCase
    case vinylBox
    case cassette

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .none: return "None"
        case .cdCase: return "CD Case"
        case .vinylBox: return "Vinyl Box"
        case .cassette: return "Cassette"
        }
    }
}

enum TrackTextStyle: String, CaseIterable, Identifiable, Codable {
    case system
    case rounded
    case serif
    case monospaced

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .system: return "System"
        case .rounded: return "Rounded"
        case .serif: return "Serif"
        case .monospaced: return "Mono"
        }
    }
}

enum TrackTextColorStyle: String, CaseIterable, Identifiable, Codable {
    case automatic
    case white
    case black

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Auto"
        case .white: return "White"
        case .black: return "Black"
        }
    }
}

enum TrackTextSize: String, CaseIterable, Identifiable, Codable {
    case small
    case medium
    case large
    case extraLarge

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .small: return "S"
        case .medium: return "M"
        case .large: return "L"
        case .extraLarge: return "XL"
        }
    }
}

enum TrackTextAlignmentStyle: String, CaseIterable, Identifiable, Codable {
    case leading
    case center

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .leading: return "Left"
        case .center: return "Center"
        }
    }
}

enum TrackInfoLayout: String, CaseIterable, Identifiable, Codable {
    case twoLines
    case threeLines
    case fourLines

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .twoLines: return "2 lines"
        case .threeLines: return "3 lines"
        case .fourLines: return "4 lines"
        }
    }
}

enum WidgetWidthMode: String, CaseIterable, Identifiable, Codable {
    case automatic
    case custom

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: return "Automatic"
        case .custom: return "Custom"
        }
    }
}

/// A snapshot of every widget styling value — the unit that built-in style
/// presets describe and that user presets persist. Codable so it can be
/// serialised into UserDefaults for user-created presets. Decoding is
/// forward-compatible: missing keys fall back to the default value, so
/// adding a new styling property in a later release won't invalidate
/// existing saved presets.
struct WidgetStyleValues: Equatable, Codable {
    var widgetLayout: WidgetLayout = .horizontal
    var widgetBackgroundStyle: WidgetBackgroundStyle = .artwork
    var widgetBackgroundOpacity: Double = 0.75
    var widgetBackgroundBlur: Double = 18
    var widgetCornerRadius: Double = 18
    var artworkSize: Double = 96
    var artworkCornerRadius: Double = 12
    var artworkShadowStyle: ArtworkShadowStyle = .regular
    var artworkPresentationEffect: ArtworkPresentationEffect = .none
    var artworkTextSpacing: Double = 14
    var showArtwork: Bool = true
    var showText: Bool = true
    var showAlbum: Bool = true
    var widgetWidthMode: WidgetWidthMode = .automatic
    var textAreaWidth: Double = 280
    var textSize: TrackTextSize = .medium
    var textStyle: TrackTextStyle = .system
    var textColorStyle: TrackTextColorStyle = .automatic
    var textAlignmentStyle: TrackTextAlignmentStyle = .leading
    var trackInfoLayout: TrackInfoLayout = .twoLines

    init(
        widgetLayout: WidgetLayout = .horizontal,
        widgetBackgroundStyle: WidgetBackgroundStyle = .artwork,
        widgetBackgroundOpacity: Double = 0.75,
        widgetBackgroundBlur: Double = 18,
        widgetCornerRadius: Double = 18,
        artworkSize: Double = 96,
        artworkCornerRadius: Double = 12,
        artworkShadowStyle: ArtworkShadowStyle = .regular,
        artworkPresentationEffect: ArtworkPresentationEffect = .none,
        artworkTextSpacing: Double = 14,
        showArtwork: Bool = true,
        showText: Bool = true,
        showAlbum: Bool = true,
        widgetWidthMode: WidgetWidthMode = .automatic,
        textAreaWidth: Double = 280,
        textSize: TrackTextSize = .medium,
        textStyle: TrackTextStyle = .system,
        textColorStyle: TrackTextColorStyle = .automatic,
        textAlignmentStyle: TrackTextAlignmentStyle = .leading,
        trackInfoLayout: TrackInfoLayout = .twoLines
    ) {
        self.widgetLayout = widgetLayout
        self.widgetBackgroundStyle = widgetBackgroundStyle
        self.widgetBackgroundOpacity = widgetBackgroundOpacity
        self.widgetBackgroundBlur = widgetBackgroundBlur
        self.widgetCornerRadius = widgetCornerRadius
        self.artworkSize = artworkSize
        self.artworkCornerRadius = artworkCornerRadius
        self.artworkShadowStyle = artworkShadowStyle
        self.artworkPresentationEffect = artworkPresentationEffect
        self.artworkTextSpacing = artworkTextSpacing
        self.showArtwork = showArtwork
        self.showText = showText
        self.showAlbum = showAlbum
        self.widgetWidthMode = widgetWidthMode
        self.textAreaWidth = textAreaWidth
        self.textSize = textSize
        self.textStyle = textStyle
        self.textColorStyle = textColorStyle
        self.textAlignmentStyle = textAlignmentStyle
        self.trackInfoLayout = trackInfoLayout
    }

    @MainActor
    init(settings: AppSettings) {
        self.widgetLayout = settings.widgetLayout
        self.widgetBackgroundStyle = settings.widgetBackgroundStyle
        self.widgetBackgroundOpacity = settings.widgetBackgroundOpacity
        self.widgetBackgroundBlur = settings.widgetBackgroundBlur
        self.widgetCornerRadius = settings.widgetCornerRadius
        self.artworkSize = settings.artworkSize
        self.artworkCornerRadius = settings.artworkCornerRadius
        self.artworkShadowStyle = settings.artworkShadowStyle
        self.artworkPresentationEffect = settings.artworkPresentationEffect
        self.artworkTextSpacing = settings.artworkTextSpacing
        self.showArtwork = settings.showArtwork
        self.showText = settings.showText
        self.showAlbum = settings.showAlbum
        self.widgetWidthMode = settings.widgetWidthMode
        self.textAreaWidth = settings.textAreaWidth
        self.textSize = settings.textSize
        self.textStyle = settings.textStyle
        self.textColorStyle = settings.textColorStyle
        self.textAlignmentStyle = settings.textAlignmentStyle
        self.trackInfoLayout = settings.trackInfoLayout
    }

    @MainActor
    func apply(to settings: AppSettings) {
        settings.widgetLayout = widgetLayout
        settings.widgetBackgroundStyle = widgetBackgroundStyle
        settings.widgetBackgroundOpacity = widgetBackgroundOpacity
        settings.widgetBackgroundBlur = widgetBackgroundBlur
        settings.widgetCornerRadius = widgetCornerRadius
        settings.artworkSize = artworkSize
        settings.artworkCornerRadius = artworkCornerRadius
        settings.artworkShadowStyle = artworkShadowStyle
        settings.artworkPresentationEffect = artworkPresentationEffect
        settings.artworkTextSpacing = artworkTextSpacing
        settings.showArtwork = showArtwork || !showText
        settings.showText = showText || !showArtwork
        settings.showAlbum = showAlbum
        settings.widgetWidthMode = widgetWidthMode
        settings.textAreaWidth = textAreaWidth
        settings.textSize = textSize
        settings.textStyle = textStyle
        settings.textColorStyle = textColorStyle
        settings.textAlignmentStyle = textAlignmentStyle
        settings.trackInfoLayout = trackInfoLayout
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let defaults = WidgetStyleValues()
        self.widgetLayout = try c.decodeIfPresent(WidgetLayout.self, forKey: .widgetLayout) ?? defaults.widgetLayout
        self.widgetBackgroundStyle = try c.decodeIfPresent(WidgetBackgroundStyle.self, forKey: .widgetBackgroundStyle) ?? defaults.widgetBackgroundStyle
        self.widgetBackgroundOpacity = try c.decodeIfPresent(Double.self, forKey: .widgetBackgroundOpacity) ?? defaults.widgetBackgroundOpacity
        self.widgetBackgroundBlur = try c.decodeIfPresent(Double.self, forKey: .widgetBackgroundBlur) ?? defaults.widgetBackgroundBlur
        self.widgetCornerRadius = try c.decodeIfPresent(Double.self, forKey: .widgetCornerRadius) ?? defaults.widgetCornerRadius
        self.artworkSize = try c.decodeIfPresent(Double.self, forKey: .artworkSize) ?? defaults.artworkSize
        self.artworkCornerRadius = try c.decodeIfPresent(Double.self, forKey: .artworkCornerRadius) ?? defaults.artworkCornerRadius
        self.artworkShadowStyle = try c.decodeIfPresent(ArtworkShadowStyle.self, forKey: .artworkShadowStyle) ?? defaults.artworkShadowStyle
        self.artworkPresentationEffect = try c.decodeIfPresent(ArtworkPresentationEffect.self, forKey: .artworkPresentationEffect) ?? defaults.artworkPresentationEffect
        self.artworkTextSpacing = try c.decodeIfPresent(Double.self, forKey: .artworkTextSpacing) ?? defaults.artworkTextSpacing
        self.showArtwork = try c.decodeIfPresent(Bool.self, forKey: .showArtwork) ?? defaults.showArtwork
        self.showText = try c.decodeIfPresent(Bool.self, forKey: .showText) ?? defaults.showText
        self.showAlbum = try c.decodeIfPresent(Bool.self, forKey: .showAlbum) ?? defaults.showAlbum
        self.widgetWidthMode = try c.decodeIfPresent(WidgetWidthMode.self, forKey: .widgetWidthMode) ?? defaults.widgetWidthMode
        self.textAreaWidth = try c.decodeIfPresent(Double.self, forKey: .textAreaWidth) ?? defaults.textAreaWidth
        self.textSize = try c.decodeIfPresent(TrackTextSize.self, forKey: .textSize) ?? defaults.textSize
        self.textStyle = try c.decodeIfPresent(TrackTextStyle.self, forKey: .textStyle) ?? defaults.textStyle
        self.textColorStyle = try c.decodeIfPresent(TrackTextColorStyle.self, forKey: .textColorStyle) ?? defaults.textColorStyle
        self.textAlignmentStyle = try c.decodeIfPresent(TrackTextAlignmentStyle.self, forKey: .textAlignmentStyle) ?? defaults.textAlignmentStyle
        self.trackInfoLayout = try c.decodeIfPresent(TrackInfoLayout.self, forKey: .trackInfoLayout) ?? defaults.trackInfoLayout
    }
}

/// User-created preset, persisted in UserDefaults.
struct UserWidgetStylePreset: Identifiable, Codable, Equatable {
    let id: String
    var name: String
    var values: WidgetStyleValues
}

@MainActor
@Observable
final class AppSettings {
    static let shared = AppSettings()

    // MARK: - Change notification

    private var changeContinuations: [UUID: AsyncStream<Void>.Continuation] = [:]

    nonisolated func changes() -> AsyncStream<Void> {
        AsyncStream { continuation in
            let id = UUID()
            Task { @MainActor in
                self.changeContinuations[id] = continuation
            }
            continuation.onTermination = { [weak self] _ in
                Task { @MainActor in
                    self?.changeContinuations.removeValue(forKey: id)
                }
            }
        }
    }

    private func notifyChanged() {
        for continuation in changeContinuations.values {
            continuation.yield()
        }
    }

    // MARK: - Storage

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let keychain: KeychainStore
    @ObservationIgnored private var cachedCredentials: NavidromeCredentials??

    private enum Keys {
        static let serverURL = "navidrome.serverURL"
        static let username = "navidrome.username"
        static let ignoreSSLErrors = "navidrome.ignoreSSLErrors"
        static let appIconVariant = "app.iconVariant"
        static let alwaysOnTop = "ui.alwaysOnTop"
        static let miniPlayerFrame = "ui.miniPlayerFrame"
        static let widgetLayout = "ui.widgetLayout"
        static let widgetBackgroundStyle = "ui.widgetBackgroundStyle"
        static let widgetBackgroundOpacity = "ui.widgetBackgroundOpacity"
        static let widgetBackgroundBlur = "ui.widgetBackgroundBlur"
        static let widgetCornerRadius = "ui.widgetCornerRadius"
        static let artworkSize = "ui.artworkSize"
        static let artworkTextSpacing = "ui.artworkTextSpacing"
        static let artworkCornerRadius = "ui.artworkCornerRadius"
        static let artworkShadowStyle = "ui.artworkShadowStyle"
        static let showCDCaseOverlay = "ui.showCDCaseOverlay"
        static let artworkPresentationEffect = "ui.artworkPresentationEffect"
        static let textStyle = "ui.textStyle"
        static let textColorStyle = "ui.textColorStyle"
        static let textSize = "ui.textSize"
        static let textAlignmentStyle = "ui.textAlignmentStyle"
        static let trackInfoLayout = "ui.trackInfoLayout"
        static let widgetWidthMode = "ui.widgetWidthMode"
        static let textAreaWidth = "ui.textAreaWidth"
        static let showDockIcon = "ui.showDockIcon"
        static let hideWidgetWhenIdle = "ui.hideWidgetWhenIdle"
        static let showArtwork = "ui.showArtwork"
        static let showText = "ui.showText"
        static let showAlbum = "ui.showAlbum"
        static let userPresets = "ui.userPresets"
    }

    private enum KeychainKeys {
        static let password = "navidrome.password"
    }

    // MARK: - Persisted settings

    var serverURLString: String {
        didSet { defaults.set(serverURLString, forKey: Keys.serverURL); invalidateCredentialsCache(); notifyChanged() }
    }

    var username: String {
        didSet { defaults.set(username, forKey: Keys.username); invalidateCredentialsCache(); notifyChanged() }
    }

    var password: String {
        didSet { try? keychain.setString(password, for: KeychainKeys.password); invalidateCredentialsCache(); notifyChanged() }
    }

    var ignoreSSLErrors: Bool {
        didSet { defaults.set(ignoreSSLErrors, forKey: Keys.ignoreSSLErrors); invalidateCredentialsCache(); notifyChanged() }
    }

    var appIconVariant: AppIconVariant {
        didSet { defaults.set(appIconVariant.rawValue, forKey: Keys.appIconVariant); notifyChanged() }
    }

    var alwaysOnTop: Bool {
        didSet { defaults.set(alwaysOnTop, forKey: Keys.alwaysOnTop); notifyChanged() }
    }

    var widgetLayout: WidgetLayout {
        didSet { defaults.set(widgetLayout.rawValue, forKey: Keys.widgetLayout); notifyChanged() }
    }

    var widgetBackgroundStyle: WidgetBackgroundStyle {
        didSet { defaults.set(widgetBackgroundStyle.rawValue, forKey: Keys.widgetBackgroundStyle); notifyChanged() }
    }

    var widgetBackgroundOpacity: Double {
        didSet { defaults.set(widgetBackgroundOpacity, forKey: Keys.widgetBackgroundOpacity); notifyChanged() }
    }

    var widgetBackgroundBlur: Double {
        didSet { defaults.set(widgetBackgroundBlur, forKey: Keys.widgetBackgroundBlur); notifyChanged() }
    }

    var widgetCornerRadius: Double {
        didSet { defaults.set(widgetCornerRadius, forKey: Keys.widgetCornerRadius); notifyChanged() }
    }

    var artworkSize: Double {
        didSet { defaults.set(artworkSize, forKey: Keys.artworkSize); notifyChanged() }
    }

    var artworkTextSpacing: Double {
        didSet { defaults.set(artworkTextSpacing, forKey: Keys.artworkTextSpacing); notifyChanged() }
    }

    var artworkCornerRadius: Double {
        didSet { defaults.set(artworkCornerRadius, forKey: Keys.artworkCornerRadius); notifyChanged() }
    }

    var artworkShadowStyle: ArtworkShadowStyle {
        didSet { defaults.set(artworkShadowStyle.rawValue, forKey: Keys.artworkShadowStyle); notifyChanged() }
    }

    var artworkPresentationEffect: ArtworkPresentationEffect {
        didSet { defaults.set(artworkPresentationEffect.rawValue, forKey: Keys.artworkPresentationEffect); notifyChanged() }
    }

    var textStyle: TrackTextStyle {
        didSet { defaults.set(textStyle.rawValue, forKey: Keys.textStyle); notifyChanged() }
    }

    var textColorStyle: TrackTextColorStyle {
        didSet { defaults.set(textColorStyle.rawValue, forKey: Keys.textColorStyle); notifyChanged() }
    }

    var textSize: TrackTextSize {
        didSet { defaults.set(textSize.rawValue, forKey: Keys.textSize); notifyChanged() }
    }

    var textAlignmentStyle: TrackTextAlignmentStyle {
        didSet { defaults.set(textAlignmentStyle.rawValue, forKey: Keys.textAlignmentStyle); notifyChanged() }
    }

    var trackInfoLayout: TrackInfoLayout {
        didSet { defaults.set(trackInfoLayout.rawValue, forKey: Keys.trackInfoLayout); notifyChanged() }
    }

    var widgetWidthMode: WidgetWidthMode {
        didSet { defaults.set(widgetWidthMode.rawValue, forKey: Keys.widgetWidthMode); notifyChanged() }
    }

    var textAreaWidth: Double {
        didSet { defaults.set(textAreaWidth, forKey: Keys.textAreaWidth); notifyChanged() }
    }

    var showDockIcon: Bool {
        didSet { defaults.set(showDockIcon, forKey: Keys.showDockIcon); notifyChanged() }
    }

    var hideWidgetWhenIdle: Bool {
        didSet { defaults.set(hideWidgetWhenIdle, forKey: Keys.hideWidgetWhenIdle); notifyChanged() }
    }

    var showArtwork: Bool {
        didSet { defaults.set(showArtwork, forKey: Keys.showArtwork); notifyChanged() }
    }

    var showText: Bool {
        didSet { defaults.set(showText, forKey: Keys.showText); notifyChanged() }
    }

    var showAlbum: Bool {
        didSet { defaults.set(showAlbum, forKey: Keys.showAlbum); notifyChanged() }
    }

    var userPresets: [UserWidgetStylePreset] {
        didSet {
            do {
                let data = try JSONEncoder().encode(userPresets)
                defaults.set(data, forKey: Keys.userPresets)
            } catch {
                AppLog.app.error("Failed to persist user presets: \(error.localizedDescription, privacy: .public)")
            }
            notifyChanged()
        }
    }

    init(defaults: UserDefaults = .standard, keychain: KeychainStore = KeychainStore()) {
        self.defaults = defaults
        self.keychain = keychain

        self.serverURLString = defaults.string(forKey: Keys.serverURL) ?? ""
        self.username = defaults.string(forKey: Keys.username) ?? ""
        self.password = (try? keychain.string(for: KeychainKeys.password)) ?? ""
        self.ignoreSSLErrors = defaults.object(forKey: Keys.ignoreSSLErrors) as? Bool ?? false
        self.appIconVariant = AppIconVariant(rawValue: defaults.string(forKey: Keys.appIconVariant) ?? "") ?? .default
        self.alwaysOnTop = defaults.object(forKey: Keys.alwaysOnTop) as? Bool ?? true
        self.widgetLayout = WidgetLayout(rawValue: defaults.string(forKey: Keys.widgetLayout) ?? "") ?? .horizontal
        self.widgetBackgroundStyle = WidgetBackgroundStyle(rawValue: defaults.string(forKey: Keys.widgetBackgroundStyle) ?? "") ?? .artwork
        self.widgetBackgroundOpacity = defaults.object(forKey: Keys.widgetBackgroundOpacity) as? Double ?? 0.82
        self.widgetBackgroundBlur = defaults.object(forKey: Keys.widgetBackgroundBlur) as? Double ?? 18
        self.widgetCornerRadius = defaults.object(forKey: Keys.widgetCornerRadius) as? Double ?? 18
        self.artworkSize = defaults.object(forKey: Keys.artworkSize) as? Double ?? 96
        self.artworkTextSpacing = defaults.object(forKey: Keys.artworkTextSpacing) as? Double ?? 14
        self.artworkCornerRadius = defaults.object(forKey: Keys.artworkCornerRadius) as? Double ?? 12
        self.artworkShadowStyle = ArtworkShadowStyle(rawValue: defaults.string(forKey: Keys.artworkShadowStyle) ?? "") ?? .regular
        let storedArtworkEffect = defaults.string(forKey: Keys.artworkPresentationEffect) ?? ""
        if storedArtworkEffect == "vinylPlastic" {
            self.artworkPresentationEffect = .vinylBox
        } else if let storedEffect = ArtworkPresentationEffect(rawValue: storedArtworkEffect) {
            self.artworkPresentationEffect = storedEffect
        } else {
            self.artworkPresentationEffect = (defaults.object(forKey: Keys.showCDCaseOverlay) as? Bool ?? false) ? .cdCase : .none
        }
        self.textStyle = TrackTextStyle(rawValue: defaults.string(forKey: Keys.textStyle) ?? "") ?? .system
        self.textColorStyle = TrackTextColorStyle(rawValue: defaults.string(forKey: Keys.textColorStyle) ?? "") ?? .automatic
        self.textSize = TrackTextSize(rawValue: defaults.string(forKey: Keys.textSize) ?? "") ?? .medium
        self.textAlignmentStyle = TrackTextAlignmentStyle(rawValue: defaults.string(forKey: Keys.textAlignmentStyle) ?? "") ?? .leading
        self.trackInfoLayout = TrackInfoLayout(rawValue: defaults.string(forKey: Keys.trackInfoLayout) ?? "") ?? .twoLines
        self.widgetWidthMode = WidgetWidthMode(rawValue: defaults.string(forKey: Keys.widgetWidthMode) ?? "") ?? .automatic
        self.textAreaWidth = defaults.object(forKey: Keys.textAreaWidth) as? Double ?? 260
        self.showDockIcon = defaults.object(forKey: Keys.showDockIcon) as? Bool ?? false
        self.hideWidgetWhenIdle = defaults.object(forKey: Keys.hideWidgetWhenIdle) as? Bool ?? false
        self.showArtwork = defaults.object(forKey: Keys.showArtwork) as? Bool ?? true
        self.showText = defaults.object(forKey: Keys.showText) as? Bool ?? true
        self.showAlbum = defaults.object(forKey: Keys.showAlbum) as? Bool ?? true
        if let data = defaults.data(forKey: Keys.userPresets) {
            do {
                self.userPresets = try JSONDecoder().decode([UserWidgetStylePreset].self, from: data)
            } catch {
                AppLog.app.error("Failed to decode stored user presets, starting empty: \(error.localizedDescription, privacy: .public)")
                self.userPresets = []
            }
        } else {
            self.userPresets = []
        }
    }

    // MARK: - User preset operations

    func addUserPreset(name: String, values: WidgetStyleValues) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        userPresets.append(UserWidgetStylePreset(id: UUID().uuidString, name: trimmed, values: values))
    }

    func renameUserPreset(id: String, to newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let idx = userPresets.firstIndex(where: { $0.id == id }) else { return }
        userPresets[idx].name = trimmed
    }

    func deleteUserPreset(id: String) {
        userPresets.removeAll { $0.id == id }
    }

    func updateUserPreset(id: String, values: WidgetStyleValues) {
        guard let idx = userPresets.firstIndex(where: { $0.id == id }) else { return }
        userPresets[idx].values = values
    }

    var credentials: NavidromeCredentials? {
        if let cached = cachedCredentials { return cached }
        let resolved: NavidromeCredentials? = {
            guard let url = URL(string: serverURLString), url.scheme != nil else { return nil }
            guard !username.isEmpty, !password.isEmpty else { return nil }
            return NavidromeCredentials(
                serverURL: url,
                username: username,
                password: password,
                ignoreSSLErrors: ignoreSSLErrors
            )
        }()
        cachedCredentials = .some(resolved)
        return resolved
    }

    private func invalidateCredentialsCache() {
        cachedCredentials = nil
    }

    func saveMiniPlayerFrame(_ rect: CGRect) {
        let dict: [String: CGFloat] = [
            "x": rect.minX, "y": rect.minY, "w": rect.width, "h": rect.height
        ]
        defaults.set(dict, forKey: Keys.miniPlayerFrame)
    }

    func loadMiniPlayerFrame() -> CGRect? {
        guard let dict = defaults.dictionary(forKey: Keys.miniPlayerFrame) as? [String: CGFloat],
              let x = dict["x"], let y = dict["y"], let w = dict["w"], let h = dict["h"] else { return nil }
        return CGRect(x: x, y: y, width: w, height: h)
    }
}
