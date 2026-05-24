import Foundation

enum ISO8601Parser {
    private static let formatters: [ISO8601DateFormatter] = {
        let withFraction = ISO8601DateFormatter()
        withFraction.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let plain = ISO8601DateFormatter()
        plain.formatOptions = [.withInternetDateTime]

        return [withFraction, plain]
    }()

    static func epochMillis(_ string: String) -> Int64? {
        for formatter in formatters {
            if let date = formatter.date(from: string) {
                return Int64(date.timeIntervalSince1970 * 1000)
            }
        }
        return nil
    }
}
