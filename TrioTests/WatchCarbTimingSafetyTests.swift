import Foundation
import Testing

@testable import Trio

@Suite("Watch carbohydrate timing safety tests") struct WatchCarbTimingSafetyTests {
    private let referenceDate = Date(timeIntervalSince1970: 2_000_000_000)

    @Test("Recommendation metadata can never classify as a carb-save command") func recommendationIsDisjoint() {
        let message: [String: Any] = [
            WatchMessageKeys.requestBolusRecommendation: true,
            WatchMessageKeys.carbs: 30,
            WatchMessageKeys.bolusRecommendationCarbsDate: referenceDate.timeIntervalSince1970,
            WatchMessageKeys.date: referenceDate.timeIntervalSince1970
        ]

        #expect(WatchTreatmentRequestKind.classify(message) == .bolusRecommendation)
    }

    @Test("Recommendation date uses a key older phones cannot persist") func recommendationDateIsNotTreatmentDate() {
        let message: [String: Any] = [
            WatchMessageKeys.requestBolusRecommendation: true,
            WatchMessageKeys.carbs: 30,
            WatchMessageKeys.bolusRecommendationCarbsDate: referenceDate.timeIntervalSince1970
        ]

        #expect(message[WatchMessageKeys.date] == nil)
        #expect(WatchTreatmentRequestKind.classify(message) == .bolusRecommendation)
    }

    @Test("A confirmed carb payload still classifies as one carb-save command") func carbSaveClassification() {
        let message: [String: Any] = [
            WatchMessageKeys.carbs: 30,
            WatchMessageKeys.date: referenceDate.timeIntervalSince1970
        ]

        #expect(WatchTreatmentRequestKind.classify(message) == .carbs)
    }

    @Test("Unedited meal time is the final submission time") func uneditedTimeUsesSubmissionTime() {
        let selected = referenceDate.addingTimeInterval(-30 * 60)
        let submitted = referenceDate

        #expect(
            WatchCarbEntryTiming.submissionDate(selectedDate: selected, wasEdited: false, now: submitted) == submitted
        )
    }

    @Test("Edited meal time is preserved exactly") func editedTimeIsPreserved() {
        let selected = referenceDate.addingTimeInterval(-30 * 60)

        #expect(
            WatchCarbEntryTiming.submissionDate(selectedDate: selected, wasEdited: true, now: referenceDate) == selected
        )
    }

    @Test("Meal time clamps from eight hours ago through now") func mealTimeClampsToRange() {
        let lowerBound = referenceDate.addingTimeInterval(-WatchCarbEntryTiming.pastLimit)

        #expect(
            WatchCarbEntryTiming.clamped(referenceDate.addingTimeInterval(-9 * 60 * 60), relativeTo: referenceDate) ==
                lowerBound
        )
        #expect(
            WatchCarbEntryTiming.clamped(referenceDate.addingTimeInterval(60), relativeTo: referenceDate) == referenceDate
        )
    }

    @Test("Phone receipt rejects stale and future meal times") func receiptValidation() {
        #expect(WatchCarbEntryTiming.isValidForReceipt(referenceDate.addingTimeInterval(-8 * 60 * 60), now: referenceDate))
        #expect(!WatchCarbEntryTiming.isValidForReceipt(referenceDate.addingTimeInterval(-9 * 60 * 60), now: referenceDate))
        #expect(!WatchCarbEntryTiming.isValidForReceipt(referenceDate.addingTimeInterval(10 * 60), now: referenceDate))
    }

    @Test("Only the current recommendation response is accepted") func responseCorrelation() {
        #expect(
            WatchBolusRecommendationProtocol.responseMatchesPendingRequest(
                responseID: "current",
                pendingRequestID: "current"
            )
        )
        #expect(
            !WatchBolusRecommendationProtocol.responseMatchesPendingRequest(
                responseID: "stale",
                pendingRequestID: "current"
            )
        )
        #expect(
            !WatchBolusRecommendationProtocol.responseMatchesPendingRequest(
                responseID: nil,
                pendingRequestID: "current"
            )
        )
    }

    @Test("Backdated recommendation requires complete valid simulation values") func simulationValidation() {
        #expect(WatchBolusSimulationValues.validated(cob: nil, minPredBG: 100) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: 20, minPredBG: nil) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: -1, minPredBG: 100) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: Decimal(Int16.max) + 1, minPredBG: 100) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: 20, minPredBG: 100) == .init(cob: 20, minPredBG: 100))
    }
}
