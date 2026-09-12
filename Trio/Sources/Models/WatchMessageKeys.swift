import Foundation

enum WatchMessageKeys {
    // Request/Response Keys
    static let date = "date"
    static let units = "units"
    static let requestWatchUpdate = "requestWatchUpdate"
    static let watchState = "watchState"
    static let acknowledged = "acknowledged"
    static let ackCode = "ackCode"
    static let message = "message"

    // Treatment Keys
    static let bolus = "bolus"
    static let carbs = "carbs"
    static let cancelBolus = "cancelBolus"
    static let bolusCanceled = "bolusCanceled"
    static let bolusProgress = "bolusProgress"
    static let activeBolusAmount = "activeBolusAmount"
    static let deliveredAmount = "deliveredAmount"
    static let bolusProgressTimestamp = "bolusProgressTimestamp"

    // Recommendation Keys
    static let requestBolusRecommendation = "requestBolusRecommendation"
    static let recommendedBolus = "recommendedBolus"
    static let bolusRecommendationCarbsDate = "bolusRecommendationCarbsDate"
    static let carbsDateWasEdited = "carbsDateWasEdited"
    static let bolusRecommendationRequestID = "bolusRecommendationRequestID"
    static let bolusRecommendationError = "bolusRecommendationError"

    // Override Keys
    static let cancelOverride = "cancelOverride"
    static let activateOverride = "activateOverride"

    // Temp Target Keys
    static let cancelTempTarget = "cancelTempTarget"
    static let activateTempTarget = "activateTempTarget"

    // Watch State Data Keys
    static let currentGlucose = "currentGlucose"
    static let currentGlucoseColorString = "currentGlucoseColorString"
    static let trend = "trend"
    static let delta = "delta"
    static let iob = "iob"
    static let cob = "cob"
    static let lastLoopTime = "lastLoopTime"
    static let glucoseValues = "glucoseValues"
    static let minYAxisValue = "minYAxisValue"
    static let maxYAxisValue = "maxYAxisValue"
    static let overridePresets = "overridePresets"
    static let tempTargetPresets = "tempTargetPresets"

    // Limits and Settings Keys
    static let maxBolus = "maxBolus"
    static let maxCarbs = "maxCarbs"
    static let maxFat = "maxFat"
    static let maxProtein = "maxProtein"
    static let bolusIncrement = "bolusIncrement"
    static let confirmBolusFaster = "confirmBolusFaster"

    // Notification Actions
    static let snoozeDuration = "snoozeDuration"
}

/// Keeps treatment-message dispatch mutually exclusive. Recommendation requests take precedence so
/// their carbohydrate metadata can never be interpreted as a command to save carbohydrates.
enum WatchTreatmentRequestKind: Equatable {
    case bolusRecommendation
    case bolus
    case carbs
    case combined
    case none

    static func classify(_ message: [String: Any]) -> Self {
        if message[WatchMessageKeys.requestBolusRecommendation] as? Bool == true {
            return .bolusRecommendation
        }

        let hasBolus = message[WatchMessageKeys.bolus] is Double
        let hasCarbs = message[WatchMessageKeys.carbs] is Int
        let hasDate = message[WatchMessageKeys.date] is TimeInterval

        switch (hasBolus, hasCarbs, hasDate) {
        case (true, false, false): return .bolus
        case (false, true, true): return .carbs
        case (true, true, true): return .combined
        default: return .none
        }
    }
}

enum WatchCarbEntryTiming {
    static let pastLimit: TimeInterval = 8 * 60 * 60
    static let buttonStep: TimeInterval = 15 * 60
    static let validationTolerance: TimeInterval = 5 * 60

    static func clamped(_ date: Date, relativeTo initialDate: Date) -> Date {
        min(initialDate, max(initialDate.addingTimeInterval(-pastLimit), date))
    }

    static func submissionDate(selectedDate: Date, wasEdited: Bool, now: Date = Date()) -> Date {
        wasEdited ? selectedDate : now
    }

    static func isValidForReceipt(_ date: Date, now: Date = Date()) -> Bool {
        let timestamp = date.timeIntervalSince1970
        guard timestamp.isFinite else { return false }
        let age = now.timeIntervalSince(date)
        return age >= -validationTolerance && age <= pastLimit + validationTolerance
    }
}

enum WatchBolusRecommendationProtocol {
    static func responseMatchesPendingRequest(responseID: String?, pendingRequestID: String?) -> Bool {
        guard let responseID, let pendingRequestID else { return false }
        return responseID == pendingRequestID
    }
}

struct WatchBolusSimulationValues: Equatable {
    let cob: Int16
    let minPredBG: Decimal

    static func validated(cob: Decimal?, minPredBG: Decimal?) -> Self? {
        guard let cob, let minPredBG else { return nil }
        let cobNumber = NSDecimalNumber(decimal: cob)
        let minPredNumber = NSDecimalNumber(decimal: minPredBG)
        guard cobNumber.doubleValue.isFinite,
              cobNumber.doubleValue >= 0,
              cobNumber.doubleValue <= Double(Int16.max),
              minPredNumber.doubleValue.isFinite,
              minPredNumber.doubleValue >= 0
        else { return nil }

        return Self(cob: Int16(cobNumber.intValue), minPredBG: minPredBG)
    }
}
