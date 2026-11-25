import SwiftUI
import SportsDeskCore

enum Theme {
    #if os(tvOS)
    static let isTV = true
    #else
    static let isTV = false
    #endif

    static let cardRadius: CGFloat = isTV ? 16 : 22
    static let horizontalPadding: CGFloat = isTV ? 0 : 16
    static let sectionSpacing: CGFloat = isTV ? 48 : 18
    static let gridSpacing: CGFloat = isTV ? 48 : 16
    static let cardPadding: CGFloat = isTV ? 32 : 18
    static let logoSmall: CGFloat = isTV ? 44 : 26
    static let logoMedium: CGFloat = isTV ? 96 : 52
    static let logoLarge: CGFloat = isTV ? 180 : 92

    static let background = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let live = Color(red: 1.0, green: 0.23, blue: 0.24)
    static let win = Color(red: 0.2, green: 0.84, blue: 0.47)
    static let loss = Color(red: 1.0, green: 0.36, blue: 0.36)

    static func statusColor(_ status: String) -> Color {
        switch ESPNInjuryProvider.severity(status: status) {
        case 0: return .pink
        case 1: return .red
        case 2: return .orange
        case 3: return .yellow
        default: return .secondary
        }
    }
}

extension TeamSummary {
    var primaryColor: Color { Color(hex: primaryHex) }
    var secondaryColor: Color { Color(hex: secondaryHex) }
    /// Primary colour lifted until it reads on a near-black background (e.g. Leafs navy, Kings black).
    var accentColor: Color { Color(rgb: RGB(hex: primaryHex).legible(fallback: RGB(hex: secondaryHex))) }

    var gradient: LinearGradient {
        LinearGradient(
            colors: [primaryColor, Color(rgb: RGB(hex: primaryHex).mixed(with: .black, amount: 0.65))],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static func lookup(league: League, code: String) -> TeamSummary? {
        TeamCatalog.shared.team(for: TeamID(league: league, code: code))
    }
}

struct RGB: Equatable {
    var red: Double
    var green: Double
    var blue: Double

    static let black = RGB(red: 0, green: 0, blue: 0)
    static let white = RGB(red: 1, green: 1, blue: 1)

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let value = UInt64(cleaned, radix: 16) ?? 0x333333
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    /// WCAG relative luminance.
    var luminance: Double {
        func channel(_ value: Double) -> Double {
            value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    func mixed(with other: RGB, amount: Double) -> RGB {
        RGB(
            red: red + (other.red - red) * amount,
            green: green + (other.green - green) * amount,
            blue: blue + (other.blue - blue) * amount
        )
    }

    func legible(fallback: RGB, minimum: Double = 0.12) -> RGB {
        if luminance >= minimum { return self }
        // Near-greyscale primaries (black/charcoal) look better as their secondary colour.
        let isGrey = max(red, green, blue) - min(red, green, blue) < 0.08
        if isGrey, fallback.luminance >= minimum { return fallback }
        var lifted = self
        for _ in 0..<10 where lifted.luminance < minimum {
            lifted = lifted.mixed(with: .white, amount: 0.12)
        }
        return lifted
    }
}

extension Color {
    init(hex: String) {
        self.init(rgb: RGB(hex: hex))
    }

    init(rgb: RGB) {
        self.init(red: rgb.red, green: rgb.green, blue: rgb.blue)
    }
}

extension League {
    var symbolName: String {
        switch self {
        case .nhl: return "hockey.puck.fill"
        case .nfl: return "football.fill"
        default: return "sportscourt.fill"
        }
    }

    var startVerb: String {
        switch self {
        case .nhl: return "Puck drop"
        case .nfl: return "Kickoff"
        default: return "Starts"
        }
    }
}
