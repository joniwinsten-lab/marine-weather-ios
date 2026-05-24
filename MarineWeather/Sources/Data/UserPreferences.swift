import Foundation

enum UserPreferences {
    private static let windUnitKey = "windUnit"

    static var windUnit: WindUnit {
        get {
            guard let raw = UserDefaults.standard.string(forKey: windUnitKey),
                  let unit = WindUnit(rawValue: raw) else {
                return .metersPerSecond
            }
            return unit
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: windUnitKey)
        }
    }
}
