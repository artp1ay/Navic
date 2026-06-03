import SwiftUI
import AppKit

struct MiniPlayerView: View {

    @Bindable var coordinator: PlayerCoordinator
    @Environment(AppSettings.self) private var settings
    var body: some View {
        styledContent
            .padding(4)
            .contextMenu {
                Button("Reload now-playing") { coordinator.rebuildProviders() }
                Toggle("Always on top", isOn: alwaysOnTopBinding)
                Divider()
                if let track = coordinator.track {
                    Button("Copy track title") {
                        let pb = NSPasteboard.general
                        pb.clearContents()
                        pb.setString("\(track.artist) - \(track.title)", forType: .string)
                    }
                }
            }
    }

    @ViewBuilder
    private var styledContent: some View {
        let isTransparent = settings.widgetBackgroundStyle == .transparent
        let cornerRadius = isTransparent ? 0 : settings.widgetCornerRadius
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        let base = content
            .padding(widgetPadding)
            .frame(minWidth: minimumSize.width, minHeight: minimumSize.height)
        if isTransparent {
            base
        } else {
            base
                .background { WidgetBackground(image: coordinator.artwork) }
                .clipShape(shape)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch settings.widgetLayout {
        case .horizontal:
            HStack(alignment: .center, spacing: settings.artworkTextSpacing) {
                if shouldShowArtwork {
                    artwork(size: settings.artworkSize)
                }
                if shouldShowText {
                    trackText
                        .frame(width: textColumnWidth, alignment: frameAlignment)
                }
            }
        case .vertical:
            VStack(alignment: stackAlignment, spacing: settings.artworkTextSpacing) {
                if shouldShowArtwork {
                    artwork(size: settings.artworkSize)
                }
                if shouldShowText {
                    trackText
                        .frame(width: textColumnWidth, alignment: frameAlignment)
                }
            }
        case .textOnly:
            if shouldShowText {
                trackText
                    .frame(width: textColumnWidth, alignment: frameAlignment)
            } else {
                artwork(size: settings.artworkSize)
            }
        }
    }

    private func artwork(size: Double) -> some View {
        ArtworkView(
            size: size,
            image: coordinator.artwork,
            imageId: coordinator.artworkTrackId ?? "placeholder",
            isLoading: coordinator.isArtworkLoading,
            cornerRadius: settings.artworkCornerRadius,
            shadowStyle: artworkShadowStyle,
            presentationEffect: settings.artworkPresentationEffect
        )
    }

    private var trackText: some View {
        VStack(alignment: stackAlignment, spacing: 5) {
            ForEach(Array(textRows.enumerated()), id: \.offset) { index, row in
                Text(row.text)
                    .font(index == 0 ? titleFont : secondaryFont)
                    .foregroundStyle(index == 0 ? primaryTextColor : secondaryTextColor)
                    .lineLimit(row.lineLimit)
                    .truncationMode(.tail)
                    .multilineTextAlignment(textAlignment)
                    .shadow(color: textShadowColor, radius: textShadowRadius, x: 0, y: 1)
            }
        }
        .id(coordinator.track?.id ?? "empty")
        .transition(
            .asymmetric(
                insertion: .opacity.combined(with: .scale(scale: 0.98)).combined(with: .move(edge: .bottom)),
                removal: .opacity.combined(with: .scale(scale: 1.02)).combined(with: .move(edge: .top))
            )
        )
        .animation(.smooth(duration: 0.32), value: coordinator.track?.id)
    }

    private var titleText: String {
        guard let track = coordinator.track else { return "Nothing playing" }
        return track.title
    }

    private var secondaryText: String {
        guard let track = coordinator.track else { return waitingText }
        if settings.showAlbum, let album = track.album, !album.isEmpty {
            return "\(track.artist) • \(album)"
        }
        return track.artist
    }

    private var waitingText: String {
        "Waiting for \(settings.integrationSource.displayName) playback"
    }

    private var textRows: [TrackTextRow] {
        guard let track = coordinator.track else {
            return [
                TrackTextRow(text: "Nothing playing", lineLimit: 1),
                TrackTextRow(text: waitingText, lineLimit: 1)
            ]
        }

        let titleLimit = settings.widgetLayout == .vertical ? 2 : 1
        let artist = track.artist.isEmpty ? "Unknown artist" : track.artist
        let album = track.album.flatMap { $0.isEmpty ? nil : $0 } ?? "Unknown album"
        let year = track.year.map(String.init) ?? "Unknown year"

        switch settings.trackInfoLayout {
        case .twoLines:
            let detail = settings.showAlbum && album != "Unknown album" ? "\(artist) • \(album)" : artist
            return [
                TrackTextRow(text: track.title, lineLimit: titleLimit),
                TrackTextRow(text: detail, lineLimit: 1)
            ]
        case .threeLines:
            return [
                TrackTextRow(text: track.title, lineLimit: titleLimit),
                TrackTextRow(text: artist, lineLimit: 1),
                TrackTextRow(text: album, lineLimit: 1)
            ]
        case .fourLines:
            return [
                TrackTextRow(text: track.title, lineLimit: titleLimit),
                TrackTextRow(text: artist, lineLimit: 1),
                TrackTextRow(text: album, lineLimit: 1),
                TrackTextRow(text: year, lineLimit: 1)
            ]
        }
    }

    private var modeBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(secondaryTextColor)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private var titleFont: Font {
        .system(size: titleFontSize, weight: .semibold, design: fontDesign)
    }

    private var secondaryFont: Font {
        .system(size: secondaryFontSize, weight: .regular, design: fontDesign)
    }

    private var titleFontSize: CGFloat {
        switch settings.textSize {
        case .small: return 12
        case .medium: return 14
        case .large: return 18
        case .extraLarge: return 22
        }
    }

    private var secondaryFontSize: CGFloat {
        switch settings.textSize {
        case .small: return 10
        case .medium: return 11
        case .large: return 13
        case .extraLarge: return 15
        }
    }

    private var fontDesign: Font.Design {
        switch settings.textStyle {
        case .system: return .default
        case .rounded: return .rounded
        case .serif: return .serif
        case .monospaced: return .monospaced
        }
    }

    private var primaryTextColor: Color {
        switch settings.textColorStyle {
        case .automatic:
            return settings.widgetBackgroundStyle == .light ? .black : .white
        case .white: return .white
        case .black: return .black
        }
    }

    private var secondaryTextColor: Color {
        primaryTextColor.opacity(0.72)
    }

    private var textShadowColor: Color {
        switch settings.textColorStyle {
        case .automatic:
            return settings.widgetBackgroundStyle == .light ? .white.opacity(0.35) : .black.opacity(0.55)
        case .white:
            return .black.opacity(0.55)
        case .black:
            return .white.opacity(0.35)
        }
    }

    private var textShadowRadius: CGFloat {
        settings.textColorStyle == .automatic ? 2 : 1.5
    }

    private var stackAlignment: HorizontalAlignment {
        switch settings.textAlignmentStyle {
        case .leading: return .leading
        case .center: return .center
        }
    }

    private var frameAlignment: Alignment {
        switch settings.textAlignmentStyle {
        case .leading: return .leading
        case .center: return .center
        }
    }

    private var textAlignment: TextAlignment {
        switch settings.textAlignmentStyle {
        case .leading: return .leading
        case .center: return .center
        }
    }

    private var textColumnWidth: CGFloat {
        if settings.widgetWidthMode == .custom {
            return settings.textAreaWidth
        }
        switch settings.widgetLayout {
        case .horizontal:
            return max(160, min(420, artworkDisplayWidth))
        case .vertical:
            return max(180, min(520, artworkDisplayWidth))
        case .textOnly:
            return max(220, min(520, settings.textAreaWidth))
        }
    }

    private var statusText: String {
        if coordinator.track == nil { return "No playback" }
        switch coordinator.playbackState.status {
        case .paused: return "Paused"
        case .playing: return coordinator.resolvedMode.badgeText
        case .stopped: return "Stopped"
        case .unknown: return coordinator.resolvedMode.badgeText
        }
    }

    private var statusColor: Color {
        if coordinator.track == nil { return Color.orange }
        switch coordinator.playbackState.status {
        case .paused: return Color.yellow
        case .playing: return Color.cyan
        case .stopped: return Color.orange
        case .unknown: return Color.gray
        }
    }

    private var artworkShadowStyle: ArtworkShadowStyle {
        // CD case, vinyl box and cassette all have rich pre-rendered silhouettes
        // that already include their own depth cues. Drawing a flat rectangular
        // drop shadow under them looks wrong, so we suppress it.
        switch settings.artworkPresentationEffect {
        case .cdCase, .vinylBox, .cassette: return .none
        case .none: return settings.artworkShadowStyle
        }
    }

    private var shouldShowArtwork: Bool {
        settings.showArtwork || !settings.showText
    }

    private var shouldShowText: Bool {
        settings.showText || !settings.showArtwork
    }

    private var widgetPadding: CGFloat {
        12
    }

    private var artworkDisplayWidth: CGFloat {
        CGFloat(settings.artworkSize) * ArtworkView.aspectRatio(for: settings.artworkPresentationEffect)
    }

    private var minimumSize: CGSize {
        let artworkWidth: CGFloat = shouldShowArtwork ? artworkDisplayWidth : 0
        let artworkHeight: CGFloat = shouldShowArtwork ? CGFloat(settings.artworkSize) : 0
        let textWidth: CGFloat = shouldShowText ? textColumnWidth : 0
        let contentSpacing: CGFloat = shouldShowArtwork && shouldShowText ? CGFloat(settings.artworkTextSpacing) : 0
        let horizontalWidth = artworkWidth + contentSpacing + textWidth + widgetPadding * 2
        let textHeight = CGFloat(textRows.count - 2) * (secondaryFontSize + 5)
        switch settings.widgetLayout {
        case .horizontal: return CGSize(width: max(120, horizontalWidth), height: max(78, shouldShowArtwork ? artworkHeight + 24 : 78 + textHeight))
        case .vertical:
            let verticalHeight = artworkHeight + contentSpacing + (shouldShowText ? 78 + textHeight : 0) + widgetPadding * 2
            return CGSize(width: max(120, max(artworkWidth, textWidth) + widgetPadding * 2), height: max(78, verticalHeight))
        case .textOnly:
            if shouldShowText {
                return CGSize(width: max(120, textWidth + widgetPadding * 2), height: 78 + textHeight)
            }
            return CGSize(width: max(120, artworkWidth + widgetPadding * 2), height: max(78, artworkHeight + widgetPadding * 2))
        }
    }

    private var alwaysOnTopBinding: Binding<Bool> {
        Binding(
            get: { settings.alwaysOnTop },
            set: { settings.alwaysOnTop = $0 }
        )
    }

}

private struct TrackTextRow {
    let text: String
    let lineLimit: Int
}

private struct WidgetBackground: View {
    @Environment(AppSettings.self) private var settings
    let image: NSImage?

    var body: some View {
        ZStack {
            switch settings.widgetBackgroundStyle {
            case .transparent:
                Color.clear
            case .glass:
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .blur(radius: settings.widgetBackgroundBlur * 0.15)
                    .opacity(settings.widgetBackgroundOpacity)
            case .artwork:
                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .blur(radius: settings.widgetBackgroundBlur)
                        .saturation(1.25)
                        .overlay(.black.opacity(0.34 * settings.widgetBackgroundOpacity))
                        .opacity(settings.widgetBackgroundOpacity)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.02, green: 0.18, blue: 0.24), Color(red: 0.08, green: 0.09, blue: 0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .opacity(settings.widgetBackgroundOpacity)
                }
            case .dark:
                LinearGradient(
                    colors: [Color(red: 0.08, green: 0.09, blue: 0.11), Color(red: 0.02, green: 0.03, blue: 0.04)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(settings.widgetBackgroundOpacity)
            case .light:
                LinearGradient(
                    colors: [Color(white: 0.98), Color(white: 0.88)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .opacity(settings.widgetBackgroundOpacity)
            }
        }
    }
}

private struct ArtworkView: View {
    static let cdCaseAspectRatio: CGFloat = 452.0 / 413.0
    static let vinylBoxAspectRatio: CGFloat = 722.0 / 615.0
    static let cassetteAspectRatio: CGFloat = 1421.0 / 898.0

    static func aspectRatio(for effect: ArtworkPresentationEffect) -> CGFloat {
        switch effect {
        case .none: return 1
        case .cdCase: return cdCaseAspectRatio
        case .vinylBox: return vinylBoxAspectRatio
        case .cassette: return cassetteAspectRatio
        }
    }

    let size: Double
    let image: NSImage?
    let imageId: String
    let isLoading: Bool
    let cornerRadius: Double
    let shadowStyle: ArtworkShadowStyle
    let presentationEffect: ArtworkPresentationEffect

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch presentationEffect {
            case .vinylBox:
                Image("VinylBox")
                    .resizable()
                    .scaledToFit()
                    .frame(width: caseFrame.width, height: caseFrame.height)
                artworkContent
            case .cassette:
                // The whole cassette scene — masked cover + PNG overlay —
                // renders into a single Metal offscreen image. Without this,
                // the transparent cut-outs cause stale-composite smearing in
                // the panel's backing store while the window is being dragged.
                ZStack(alignment: .topLeading) {
                    Group {
                        artworkPlaceholder
                        artworkContent
                    }
                    .mask { cassetteMask }

                    Image("Casette")
                        .resizable()
                        .interpolation(.high)
                        .scaledToFit()
                        // Slight outward bleed so the PNG's anti-aliased white
                        // fringe falls outside the outer clipShape and gets
                        // cropped instead of leaking a halo onto the desktop.
                        .frame(width: caseFrame.width + 6, height: caseFrame.height + 6)
                        .offset(x: -3, y: -3)
                        .allowsHitTesting(false)
                }
                .frame(width: caseFrame.width, height: caseFrame.height)
                .drawingGroup(opaque: false)
            case .cdCase:
                artworkPlaceholder
                artworkContent
                Image("CDCase")
                    .resizable()
                    .scaledToFit()
                    .frame(width: caseFrame.width, height: caseFrame.height)
                    .allowsHitTesting(false)
            case .none:
                artworkPlaceholder
                artworkContent
            }
        }
        .frame(width: caseFrame.width, height: caseFrame.height)
        .clipShape(clipShape)
        .background { shadowLayer }
        .animation(.smooth(duration: 0.45), value: isLoading)
        .animation(.smooth(duration: 0.45), value: imageId)
    }

    /// Mask for the cassette cover: full body silhouette with the reel
    /// openings, tape window and bottom alignment notches subtracted via
    /// even-odd fill on a single combined path. We deliberately use EO-fill
    /// (not `.destinationOut` blend mode) because blend-mode-based masking
    /// on transparent NSWindows leaves stale composite buffers behind while
    /// the user drags the panel — every move smears the previous frame's
    /// holes on top of the new ones until something invalidates the tree.
    /// A plain even-odd filled Path renders cleanly on every frame.
    private var cassetteMask: some View {
        CassetteCutoutShape()
            .fill(style: FillStyle(eoFill: true, antialiased: true))
    }

    @ViewBuilder
    private var shadowLayer: some View {
        if shadowStyle != .none {
            ZStack {
                clipShape
                    .fill(Color.black)
                    .shadow(color: shadow.primaryColor, radius: shadow.primaryRadius, x: 0, y: shadow.primaryY)
                clipShape
                    .fill(Color.black)
                    .shadow(color: shadow.secondaryColor, radius: shadow.secondaryRadius, x: 0, y: shadow.secondaryY)
            }
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let image {
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: coverFrame.width, height: coverFrame.height)
                .clipShape(RoundedRectangle(cornerRadius: effectiveCoverCornerRadius, style: .continuous))
                .offset(x: coverFrame.minX, y: coverFrame.minY)
                .id(imageId)
                .opacity(isLoading ? 0.72 : 1)
                .blur(radius: isLoading ? 14 : 0)
                .scaleEffect(isLoading ? 0.985 : 1)
                .transition(.opacity.combined(with: .scale(scale: 1.012)))
        } else {
            Image(systemName: "music.note")
                .font(.system(size: 28))
                .foregroundStyle(.secondary)
                .frame(width: coverFrame.width, height: coverFrame.height)
                .offset(x: coverFrame.minX, y: coverFrame.minY)
                .blur(radius: isLoading ? 8 : 0)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }

    private var artworkPlaceholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(LinearGradient(
                colors: [Color(white: 0.2), Color(white: 0.08)],
                startPoint: .top,
                endPoint: .bottom
            ))
            .frame(width: coverFrame.width, height: coverFrame.height)
            .offset(x: coverFrame.minX, y: coverFrame.minY)
    }

    private var caseFrame: CGRect {
        let height = CGFloat(size)
        let width = height * Self.aspectRatio(for: presentationEffect)
        return CGRect(x: 0, y: 0, width: width, height: height)
    }

    private var coverFrame: CGRect {
        switch presentationEffect {
        case .none:
            return CGRect(x: 0, y: 0, width: CGFloat(size), height: CGFloat(size))
        case .cdCase:
            let scale = CGFloat(size) / 413
            return CGRect(
                x: 41 * scale,
                y: 7 * scale,
                width: 404 * scale,
                height: 399 * scale
            )
        case .vinylBox:
            // The new VinylBox.png is 722×615 with a square 615×615 sleeve on
            // the left and the record protruding into the remaining ~107px on
            // the right. The cover art fills the entire sleeve square.
            let coverSide = CGFloat(size)
            return CGRect(x: 0, y: 0, width: coverSide, height: coverSide)
        case .cassette:
            // Cover image fills the full cassette bounding box; the cassette
            // PNG on top has transparent interior regions through which the
            // cover bleeds (label, reel windows, the body shell). Using
            // scaledToFill on the cover gives the J-card aesthetic — the
            // centre slice of the artwork is what the listener actually sees.
            return CGRect(
                x: 0, y: 0,
                width: CGFloat(size) * Self.cassetteAspectRatio,
                height: CGFloat(size)
            )
        }
    }

    private var effectiveCoverCornerRadius: CGFloat {
        switch presentationEffect {
        case .none:
            return CGFloat(cornerRadius)
        case .cdCase:
            return max(2, CGFloat(cornerRadius) * 0.25)
        case .vinylBox:
            return max(1, CGFloat(cornerRadius) * 0.08)
        case .cassette:
            // Real J-card labels are essentially square-cornered.
            return max(1, CGFloat(cornerRadius) * 0.05)
        }
    }

    private var clipShape: RoundedRectangle {
        switch presentationEffect {
        case .none: return RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        case .cdCase: return RoundedRectangle(cornerRadius: 8, style: .continuous)
        case .vinylBox: return RoundedRectangle(cornerRadius: 3, style: .continuous)
        case .cassette: return RoundedRectangle(cornerRadius: 12, style: .continuous)
        }
    }

    private var shadow: (
        primaryColor: Color,
        primaryRadius: CGFloat,
        primaryY: CGFloat,
        secondaryColor: Color,
        secondaryRadius: CGFloat,
        secondaryY: CGFloat
    ) {
        switch shadowStyle {
        case .none:
            return (.clear, 0, 0, .clear, 0, 0)
        case .subtle:
            return (.black.opacity(0.14), 8, 2, .black.opacity(0.06), 18, 5)
        case .regular:
            return (.black.opacity(0.16), 14, 4, .black.opacity(0.08), 28, 10)
        case .deep:
            return (.black.opacity(0.18), 22, 7, .black.opacity(0.10), 44, 18)
        }
    }
}

/// Silhouette of the cassette shell, used as a mask for the cover so the
/// artwork lives entirely inside the cassette outline. Coordinates are in the
/// source PNG's pixel space (1421 × 898) and scale linearly with the actual
/// rendered size. The outline is slightly inset from the painted PNG edge so
/// anti-aliased pixels fall outside the mask and don't leak a white halo.
private struct CassetteBodyShape: Shape {
    static let imageSize = CGSize(width: 1421, height: 898)
    private static let body = CGRect(x: 38, y: 58, width: 1345, height: 782)
    private static let bodyCornerRadius: CGFloat = 36

    func path(in rect: CGRect) -> Path {
        let sx = rect.width / Self.imageSize.width
        let sy = rect.height / Self.imageSize.height
        let bodyRect = CGRect(
            x: rect.minX + Self.body.minX * sx,
            y: rect.minY + Self.body.minY * sy,
            width: Self.body.width * sx,
            height: Self.body.height * sy
        )
        let r = Self.bodyCornerRadius * min(sx, sy)
        return Path(roundedRect: bodyRect, cornerSize: CGSize(width: r, height: r))
    }
}

/// Punch-outs over the cassette body: two reel openings, the tape window
/// between them, and the row of bottom alignment notches. Drawn with
/// `.destinationOut` blend mode so they carve true transparency out of the
/// body mask — the cover doesn't show through these spots, the desktop /
/// widget background does.
///
/// Coordinates were extracted by connected-component scanning of the
/// Casette.png alpha channel — every bbox here corresponds to a real
/// transparent region in the source PNG (1421 × 898), inflated by 1px to
/// catch anti-aliased edges.
private struct CassetteHolesShape: Shape {
    private static let edgePadding: CGFloat = 1

    private static let leftReel = CGRect(x: 353, y: 354, width: 131, height: 126)
    private static let rightReel = CGRect(x: 927, y: 354, width: 129, height: 126)
    private static let tapeWindow = CGRect(x: 640, y: 341, width: 86, height: 138)
    private static let tapeWindowCornerRadius: CGFloat = 10
    private static let bottomNotches: [CGRect] = [
        CGRect(x: 364, y: 794, width: 44, height: 22),
        CGRect(x: 495, y: 776, width: 44, height: 25),
        CGRect(x: 871, y: 777, width: 44, height: 23),
        CGRect(x: 998, y: 792, width: 44, height: 24),
    ]
    private static let bottomNotchCornerRadius: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        let imageSize = CassetteBodyShape.imageSize
        let sx = rect.width / imageSize.width
        let sy = rect.height / imageSize.height
        var path = Path()

        path.addEllipse(in: scaled(Self.leftReel, sx: sx, sy: sy, in: rect))
        path.addEllipse(in: scaled(Self.rightReel, sx: sx, sy: sy, in: rect))

        let tapeCorner = Self.tapeWindowCornerRadius * min(sx, sy)
        path.addRoundedRect(
            in: scaled(Self.tapeWindow, sx: sx, sy: sy, in: rect),
            cornerSize: CGSize(width: tapeCorner, height: tapeCorner)
        )

        let notchCorner = Self.bottomNotchCornerRadius * min(sx, sy)
        for notch in Self.bottomNotches {
            path.addRoundedRect(
                in: scaled(notch, sx: sx, sy: sy, in: rect),
                cornerSize: CGSize(width: notchCorner, height: notchCorner)
            )
        }

        return path
    }

    private func scaled(_ r: CGRect, sx: CGFloat, sy: CGFloat, in rect: CGRect) -> CGRect {
        let pad = Self.edgePadding
        return CGRect(
            x: rect.minX + (r.minX - pad) * sx,
            y: rect.minY + (r.minY - pad) * sy,
            width: (r.width + pad * 2) * sx,
            height: (r.height + pad * 2) * sy
        )
    }
}

/// Single combined path used as the cassette mask: outer cassette silhouette
/// plus every transparent punch-out, rendered with even-odd fill so the holes
/// alternate to "unfilled" wherever they sit inside the body.
///
/// Using one EO-filled Path (rather than a body shape + a destinationOut blend
/// of the holes) sidesteps a CoreAnimation gotcha on transparent macOS
/// windows: destinationOut leaves stale composite pixels in the window's
/// backing store while it's being dragged, smearing each frame's holes over
/// the previous ones until something triggers a full redraw.
private struct CassetteCutoutShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.addPath(CassetteBodyShape().path(in: rect))
        path.addPath(CassetteHolesShape().path(in: rect))
        return path
    }
}
