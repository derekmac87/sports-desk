import SportsDeskCore
import SwiftUI
import UIKit

// MARK: - Images

/// In-memory logo/headshot cache so recycled rows don't flash placeholders (AsyncImage re-fetches).
@MainActor
final class ImageCache {
    static let shared = ImageCache()

    private let images = NSCache<NSURL, UIImage>()
    private var inFlight: [URL: Task<Data?, Never>] = [:]
    private let session: URLSession = {
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(memoryCapacity: 16 * 1024 * 1024, diskCapacity: 128 * 1024 * 1024)
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        return URLSession(configuration: configuration)
    }()

    func cached(_ url: URL) -> UIImage? {
        images.object(forKey: url as NSURL)
    }

    func image(for url: URL) async -> UIImage? {
        if let hit = cached(url) { return hit }
        let task: Task<Data?, Never>
        if let existing = inFlight[url] {
            task = existing
        } else {
            let session = self.session
            task = Task { try? await session.data(from: url).0 }
            inFlight[url] = task
        }
        let data = await task.value
        inFlight[url] = nil
        guard let data, let image = UIImage(data: data) else { return nil }
        images.setObject(image, forKey: url as NSURL)
        return image
    }
}

struct RemoteImage<Placeholder: View>: View {
    var url: URL?
    @ViewBuilder var placeholder: () -> Placeholder
    @State private var loaded: UIImage?

    var body: some View {
        let image = loaded ?? url.flatMap { ImageCache.shared.cached($0) }
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .transition(.opacity)
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            guard let url else { return }
            let fetched = await ImageCache.shared.image(for: url)
            withAnimation(.easeOut(duration: 0.2)) { loaded = fetched }
        }
    }
}

struct TeamLogo: View {
    var url: URL?
    var abbreviation: String
    var size: CGFloat

    var body: some View {
        RemoteImage(url: url) {
            Text(abbreviation)
                .font(.system(size: size * 0.3, weight: .heavy, design: .rounded))
                .foregroundStyle(.secondary)
                .frame(width: size, height: size)
                .background(Circle().fill(.white.opacity(0.08)))
        }
        .frame(width: size, height: size)
        .shadow(color: .black.opacity(0.35), radius: size * 0.06, y: size * 0.03)
        .accessibilityHidden(true)
    }
}

extension TeamLogo {
    init(team: TeamSummary, size: CGFloat) {
        self.init(url: team.logoURL, abbreviation: team.abbreviation, size: size)
    }
}

struct Headshot: View {
    var url: URL?
    var name: String
    var tint: Color
    var size: CGFloat

    var body: some View {
        RemoteImage(url: url) {
            Text(initials)
                .font(.system(size: size * 0.36, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .frame(width: size, height: size)
        }
        .frame(width: size, height: size)
        .background(Circle().fill(tint.opacity(0.35)))
        .clipShape(Circle())
        .accessibilityHidden(true)
    }

    private var initials: String {
        name.split(separator: " ").prefix(2).compactMap(\.first).map(String.init).joined()
    }
}

// MARK: - Surfaces

extension View {
    func cardSurface(tint: Color? = nil) -> some View {
        background {
            RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay {
                    if let tint {
                        RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                            .fill(LinearGradient(colors: [tint.opacity(0.22), .clear], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous)
                        .strokeBorder(.white.opacity(0.08), lineWidth: 1)
                }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
    }

    /// tvOS: the system card style (focus lift, tilt and specular highlight). iOS: a gentle press-down.
    @ViewBuilder
    func cardLinkStyle() -> some View {
        #if os(tvOS)
        buttonStyle(.card)
        #else
        buttonStyle(PressableCardStyle())
        #endif
    }

    @ViewBuilder
    func tvFocusSection() -> some View {
        #if os(tvOS)
        focusSection()
        #else
        self
        #endif
    }

    /// On tvOS, non-button content can only be scrolled by moving focus, so long tables need focusable rows.
    func tvFocusableRow() -> some View {
        modifier(TVFocusableRow())
    }

    func shimmering() -> some View {
        modifier(Shimmer())
    }
}

struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .brightness(configuration.isPressed ? -0.03 : 0)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: configuration.isPressed)
    }
}

private struct TVFocusableRow: ViewModifier {
    @FocusState private var focused: Bool

    func body(content: Content) -> some View {
        #if os(tvOS)
        content
            .padding(.horizontal, 12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(focused ? 0.16 : 0)))
            .scaleEffect(focused ? 1.02 : 1)
            .focusable()
            .focused($focused)
            .animation(.easeOut(duration: 0.15), value: focused)
        #else
        content
        #endif
    }
}

/// Ambient team-colour glow behind translucent cards.
struct AmbientBackground: View {
    var colors: [Color]

    var body: some View {
        ZStack {
            Theme.background
            GeometryReader { proxy in
                let size = max(proxy.size.width, proxy.size.height)
                ZStack {
                    if let first = colors.first {
                        Circle().fill(first.opacity(0.55))
                            .frame(width: size * 0.9)
                            .offset(x: -size * 0.35, y: -size * 0.45)
                    }
                    if colors.count > 1 {
                        Circle().fill(colors[1].opacity(0.4))
                            .frame(width: size * 0.8)
                            .offset(x: size * 0.4, y: size * 0.1)
                    }
                }
                .frame(width: proxy.size.width, height: proxy.size.height)
                .blur(radius: size * 0.15)
            }
        }
        .ignoresSafeArea()
        .animation(.easeInOut(duration: 0.6), value: colors)
        .accessibilityHidden(true)
    }
}

// MARK: - Badges & labels

struct LiveBadge: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Theme.live)
                .frame(width: Theme.isTV ? 14 : 8, height: Theme.isTV ? 14 : 8)
                .scaleEffect(pulse ? 0.6 : 1)
                .opacity(pulse ? 0.5 : 1)
            Text("LIVE")
                .font(.caption.weight(.heavy))
                .tracking(1.2)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(Theme.live.opacity(0.22), in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.live.opacity(0.5), lineWidth: 1))
        .foregroundStyle(.white)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { pulse = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Live")
    }
}

struct Pill: View {
    var text: String
    var systemImage: String?
    var tint: Color = .white

    var body: some View {
        Label {
            Text(text)
        } icon: {
            if let systemImage { Image(systemName: systemImage) }
        }
        .labelStyle(PillLabelStyle(showsIcon: systemImage != nil))
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: Capsule())
    }
}

private struct PillLabelStyle: LabelStyle {
    var showsIcon: Bool

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            if showsIcon { configuration.icon }
            configuration.title
        }
    }
}

struct CardHeader: View {
    var title: String
    var systemImage: String
    var tint: Color
    var showsChevron = true

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .imageScale(.medium)
            Text(title)
                .font(.headline)
            Spacer(minLength: 0)
            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

struct StatTile: View {
    var label: String
    var value: String
    var detail: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .fontDesign(.rounded)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let detail {
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Ticks every second near start time, every 30 s otherwise.
struct CountdownText: View {
    var start: Date
    var font: Font

    var body: some View {
        TimelineView(.periodic(from: .now, by: start.timeIntervalSinceNow > 3600 ? 30 : 1)) { context in
            Text(GameTimeFormatting.countdown(until: start, now: context.date) ?? "Soon")
                .font(font)
                .monospacedDigit()
                .contentTransition(.numericText(countsDown: true))
                .animation(.snappy, value: context.date)
        }
    }
}

// MARK: - Loading, empty and error states

struct Shimmer: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay {
                if !reduceMotion {
                    GeometryReader { proxy in
                        LinearGradient(colors: [.clear, .white.opacity(0.12), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: proxy.size.width * 0.6)
                            .offset(x: phase * proxy.size.width * 1.4)
                    }
                    .allowsHitTesting(false)
                }
            }
            .clipped()
            .onAppear {
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) { phase = 1.2 }
            }
    }
}

struct SkeletonBlock: View {
    var width: CGFloat?
    var height: CGFloat
    var radius: CGFloat = 8

    var body: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.white.opacity(0.08))
            .frame(width: width, height: height)
    }
}

struct TeamCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                SkeletonBlock(width: Theme.logoMedium * 0.7, height: Theme.logoMedium * 0.7, radius: Theme.logoMedium)
                VStack(alignment: .leading, spacing: 8) {
                    SkeletonBlock(width: Theme.isTV ? 360 : 180, height: Theme.isTV ? 30 : 18)
                    SkeletonBlock(width: Theme.isTV ? 220 : 110, height: Theme.isTV ? 20 : 12)
                }
            }
            SkeletonBlock(width: nil, height: Theme.isTV ? 280 : 170, radius: Theme.cardRadius - 6)
            HStack(spacing: 10) {
                ForEach(0..<3, id: \.self) { _ in SkeletonBlock(width: nil, height: Theme.isTV ? 70 : 48, radius: 12) }
            }
        }
        .padding(Theme.cardPadding)
        .frame(maxWidth: .infinity)
        .cardSurface()
        .shimmering()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
    }
}

struct UnavailableNote: View {
    var message: String
    var systemImage = "exclamationmark.triangle"

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct SourceFootnote: View {
    var source: String
    var updated: Date?

    var body: some View {
        HStack(spacing: 4) {
            Text("Source: \(source)")
            if let updated {
                Text("·")
                Text(updated, style: .relative) + Text(" ago")
            }
        }
        .font(.caption)
        .foregroundStyle(.tertiary)
    }
}
