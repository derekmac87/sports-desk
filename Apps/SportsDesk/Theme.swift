import SwiftUI
import SportsDeskCore

enum Theme {
    static var cardRadius: CGFloat {
        #if os(tvOS)
        24
        #else
        18
        #endif
    }

    static var horizontalPadding: CGFloat {
        #if os(tvOS)
        60
        #else
        16
        #endif
    }

    static var titleFont: Font {
        #if os(tvOS)
        .largeTitle
        #else
        .title2.weight(.bold)
        #endif
    }

    static var bodyFont: Font {
        #if os(tvOS)
        .title3
        #else
        .body
        #endif
    }
}

extension TeamSummary {
    var primaryColor: Color { Color(hex: primaryHex) }
    var secondaryColor: Color { Color(hex: secondaryHex) }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

struct FocusCard<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(cardPadding)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: Theme.cardRadius, style: .continuous))
        }
        #if os(tvOS)
        .buttonStyle(.card)
        #else
        .buttonStyle(.plain)
        #endif
    }

    private var cardPadding: CGFloat {
        #if os(tvOS)
        28
        #else
        16
        #endif
    }
}

struct RemoteImage: View {
    var url: URL?
    var size: CGFloat

    var body: some View {
        AsyncImage(url: url) { phase in
            switch phase {
            case .success(let image):
                image.resizable().scaledToFit()
            case .failure:
                placeholder
            case .empty:
                placeholder.redacted(reason: .placeholder)
            @unknown default:
                placeholder
            }
        }
        .frame(width: size, height: size)
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.white.opacity(0.12))
    }
}
