import Foundation

/// Storm radar scrubber: ±3 h from now, 30 min steps (Android `StormRadarTimeline`).
enum StormRadarTimeline {
    static let horizonMinutes = 180
    static let stepMinutes = 30

    static let offsetsMinutes: [Int] = {
        var list: [Int] = []
        var t = -horizonMinutes
        while t <= horizonMinutes {
            list.append(t)
            t += stepMinutes
        }
        return list
    }()

    static var nowFrameIndex: Int {
        offsetsMinutes.firstIndex(of: 0) ?? 0
    }

    static var frameCount: Int { offsetsMinutes.count }
}
