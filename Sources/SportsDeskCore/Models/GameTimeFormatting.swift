import Foundation

public enum GameTimeFormatting {
    /// "2d 4h", "3h 05m", "12:07", or nil once the start time has passed.
    public static func countdown(until start: Date, now: Date = Date()) -> String? {
        let seconds = Int(start.timeIntervalSince(now).rounded(.up))
        guard seconds > 0 else { return nil }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3600
        let minutes = (seconds % 3600) / 60
        if days > 0 { return "\(days)d \(hours)h" }
        if hours > 0 { return "\(hours)h \(String(format: "%02d", minutes))m" }
        return String(format: "%d:%02d", minutes, seconds % 60)
    }

    /// "Tonight · 7:00 PM", "Tomorrow · 1:00 PM", "Sun · 4:25 PM", or "Oct 30 · 7:00 PM" in the given time zone.
    public static func startLabel(
        for start: Date,
        now: Date = Date(),
        timeZone: TimeZone = .current,
        locale: Locale = .current
    ) -> String {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        calendar.locale = locale
        let time = formatter(template: "jmm", timeZone: timeZone, locale: locale).string(from: start)
        let dayStart = calendar.startOfDay(for: now)
        let startDay = calendar.startOfDay(for: start)
        let days = calendar.dateComponents([.day], from: dayStart, to: startDay).day ?? 0
        let day: String
        switch days {
        case 0: day = calendar.component(.hour, from: start) >= 17 ? "Tonight" : "Today"
        case 1: day = "Tomorrow"
        case 2..<7: day = formatter(template: "EEE", timeZone: timeZone, locale: locale).string(from: start)
        default: day = formatter(template: "MMMd", timeZone: timeZone, locale: locale).string(from: start)
        }
        return "\(day) · \(time)"
    }

    private static func formatter(template: String, timeZone: TimeZone, locale: Locale) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.setLocalizedDateFormatFromTemplate(template)
        return formatter
    }
}
