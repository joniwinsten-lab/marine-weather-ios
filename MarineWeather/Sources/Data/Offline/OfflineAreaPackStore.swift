import Foundation
import SwiftData

@Model
final class OfflineAreaPackEntity {
    @Attribute(.unique) var id: UUID
    var createdAtMs: Int64
    var routePointCount: Int
    var weatherSampleCount: Int
    var minLat: Double
    var minLon: Double
    var maxLat: Double
    var maxLon: Double
    var label: String

    init(
        id: UUID = UUID(),
        createdAtMs: Int64,
        routePointCount: Int,
        weatherSampleCount: Int,
        minLat: Double,
        minLon: Double,
        maxLat: Double,
        maxLon: Double,
        label: String
    ) {
        self.id = id
        self.createdAtMs = createdAtMs
        self.routePointCount = routePointCount
        self.weatherSampleCount = weatherSampleCount
        self.minLat = minLat
        self.minLon = minLon
        self.maxLat = maxLat
        self.maxLon = maxLon
        self.label = label
    }
}

@MainActor
final class OfflineAreaPackStore {
    static let shared = OfflineAreaPackStore()

    private let container: ModelContainer
    private let context: ModelContext

    private init() {
        container = try! ModelContainer(for: OfflineAreaPackEntity.self)
        context = ModelContext(container)
    }

    func insert(_ pack: OfflineAreaPackEntity) {
        context.insert(pack)
        try? context.save()
    }

    func latest() -> OfflineAreaPackEntity? {
        var descriptor = FetchDescriptor<OfflineAreaPackEntity>(
            sortBy: [SortDescriptor(\.createdAtMs, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}
