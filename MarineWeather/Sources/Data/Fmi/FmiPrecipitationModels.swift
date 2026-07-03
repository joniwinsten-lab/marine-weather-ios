import Foundation

struct FmiPrecipitationStep: Equatable {
    let epochMs: Int64
    /// Model precipitation amount for the timestep (typically mm per step).
    let amountMm: Double
}
