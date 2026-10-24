import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPSession: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

public struct URLSessionTransport: HTTPSession, @unchecked Sendable {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await session.data(for: request)
    }
}

public struct HTTPClient: Sendable {
    public var transport: any HTTPSession
    public var userAgent: String
    public var extraHeaders: [String: String]

    public init(
        transport: any HTTPSession = URLSessionTransport(),
        userAgent: String = "SportsDesk/1.0 (personal sports dashboard)",
        extraHeaders: [String: String] = [:]
    ) {
        self.transport = transport
        self.userAgent = userAgent
        self.extraHeaders = extraHeaders
    }

    public func get(url: URL, headers: [String: String] = [:]) async throws -> Data {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.setValue("application/json, text/html;q=0.9, */*;q=0.8", forHTTPHeaderField: "Accept")
        extraHeaders.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        let (data, response) = try await transport.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw SportsDeskError.network("HTTP \(http.statusCode) for \(url.absoluteString)")
        }
        return data
    }

    public func getJSON<T: Decodable>(_ type: T.Type, url: URL, headers: [String: String] = [:]) async throws -> T {
        let data = try await get(url: url, headers: headers)
        do {
            return try JSONDecoder.sportsDesk.decode(type, from: data)
        } catch {
            throw SportsDeskError.decoding("\(type): \(error.localizedDescription)")
        }
    }
}

public struct FixtureHTTPSession: HTTPSession, Sendable {
    public var responses: [String: Data]
    public var statusByHostPath: [String: Int]

    public init(responses: [String: Data] = [:], statusByHostPath: [String: Int] = [:]) {
        self.responses = responses
        self.statusByHostPath = statusByHostPath
    }

    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        guard let url = request.url else {
            throw SportsDeskError.network("Missing URL")
        }
        let key = Self.key(for: url)
        let pathKey = "\(url.host ?? "")\(url.path)"
        let data = responses[key]
            ?? responses[pathKey]
            ?? responses.first(where: { $0.key.hasPrefix(pathKey) })?.value
            ?? Data()
        let status = statusByHostPath[key] ?? statusByHostPath[pathKey] ?? (data.isEmpty ? 404 : 200)
        let response = HTTPURLResponse(url: url, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (data, response)
    }

    public static func key(for url: URL) -> String {
        let path = url.path
        if let query = url.query, !query.isEmpty {
            return "\(url.host ?? "")\(path)?\(query)"
        }
        return "\(url.host ?? "")\(path)"
    }
}

extension JSONDecoder {
    public static let sportsDesk: JSONDecoder = {
        let decoder = JSONDecoder()
        return decoder
    }()
}

public enum DateParser {
    public static func parse(_ raw: String?) -> Date? {
        guard var raw, !raw.isEmpty else { return nil }
        if raw.hasSuffix("Z"), raw.count == 17, raw.contains("T") {
            raw = String(raw.dropLast()) + ":00Z"
        }
        if let date = isoFractional.date(from: raw) { return date }
        if let date = iso.date(from: raw) { return date }
        for formatter in posix {
            if let date = formatter.date(from: raw) { return date }
        }
        return nil
    }

    public static func display(date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    public static func weekdayTime(date: Date, timeZone: TimeZone = .current) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = timeZone
        formatter.locale = .current
        formatter.setLocalizedDateFormatFromTemplate("EEE MMM d jmm")
        return formatter.string(from: date)
    }

    nonisolated(unsafe) private static let isoFractional: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }()

    nonisolated(unsafe) private static let iso: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }()

    nonisolated(unsafe) private static let posix: [DateFormatter] = {
        ["yyyy-MM-dd'T'HH:mm:ssZ", "yyyy-MM-dd'T'HH:mmZ", "yyyy-MM-dd"].map { format in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = TimeZone(secondsFromGMT: 0)
            formatter.dateFormat = format
            return formatter
        }
    }()
}

struct FlexibleText: Decodable, Sendable {
    var value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let text = try? container.decode(String.self) {
            value = text
            return
        }
        let keyed = try decoder.container(keyedBy: CodingKeys.self)
        value = try keyed.decode(String.self, forKey: .defaultValue)
    }

    private enum CodingKeys: String, CodingKey {
        case defaultValue = "default"
    }
}

struct FlexibleID: Decodable, Sendable {
    var value: String

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let int = try? container.decode(Int.self) {
            value = String(int)
        } else if let text = try? container.decode(String.self) {
            value = text
        } else {
            value = ""
        }
    }
}

func percent(_ value: Double?, digits: Int = 1) -> String {
    guard let value else { return "—" }
    return String(format: "%.\(digits)f%%", value * (value <= 1.0 ? 100 : 1))
}

func oneDecimal(_ value: Double?) -> String {
    guard let value else { return "—" }
    return String(format: "%.1f", value)
}
