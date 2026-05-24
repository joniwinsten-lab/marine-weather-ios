import Foundation

enum CompositeLightningRepository {
    static func fetchMergedStrikes() async -> Result<[LightningStrike], Error> {
        async let fmiResult = FmiLightningRepository.fetchRecentStrikes()
        async let smhiResult = SmhiLightningRepository.fetchRecentStrikes()

        let fmi = await fmiResult
        let smhi = await smhiResult
        let fmiStrikes = (try? fmi.get()) ?? []
        let smhiStrikes = (try? smhi.get()) ?? []
        var seen = Set<String>()
        let merged = (fmiStrikes + smhiStrikes)
            .filter { strike in
                let key = "\(strike.source.rawValue):\(strike.latitude):\(strike.longitude):\(strike.observedAtEpochMs)"
                if seen.contains(key) { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.observedAtEpochMs > $1.observedAtEpochMs }

        var errors: [String] = []
        if case .failure(let e) = fmi { errors.append(e.localizedDescription) }
        if case .failure(let e) = smhi { errors.append(e.localizedDescription) }
        if merged.isEmpty, !errors.isEmpty {
            return .failure(StormDataError.combined(errors.joined(separator: " · ")))
        }
        return .success(merged)
    }
}

enum StormDataError: LocalizedError {
    case combined(String)
    var errorDescription: String? {
        switch self {
        case .combined(let msg): msg
        }
    }
}
