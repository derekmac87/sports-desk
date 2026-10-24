import Foundation
@testable import SportsDeskCore

enum FixtureLoader {
    static func data(_ name: String) throws -> Data {
        let url = Bundle.module.url(forResource: name, withExtension: nil, subdirectory: "Fixtures")
            ?? Bundle.module.url(forResource: (name as NSString).deletingPathExtension, withExtension: (name as NSString).pathExtension, subdirectory: "Fixtures")
        guard let url else {
            throw SportsDeskError.unavailable("Missing fixture \(name)")
        }
        return try Data(contentsOf: url)
    }

    static func decode<T: Decodable>(_ type: T.Type, _ name: String) throws -> T {
        try JSONDecoder.sportsDesk.decode(type, from: data(name))
    }
}
