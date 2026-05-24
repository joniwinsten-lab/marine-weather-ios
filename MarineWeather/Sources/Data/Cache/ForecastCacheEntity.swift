import Foundation
import SwiftData

@Model
final class ForecastCacheEntity {
    @Attribute(.unique) var cacheKey: String
    var json: String
    var updatedAt: Int64

    init(cacheKey: String, json: String, updatedAt: Int64) {
        self.cacheKey = cacheKey
        self.json = json
        self.updatedAt = updatedAt
    }
}
