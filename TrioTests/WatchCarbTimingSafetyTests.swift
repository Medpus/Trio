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

        var pendingRequestID: String? = "newer"
        #expect(
            !WatchBolusRecommendationProtocol.consumeMatchingResponse(
                responseID: "older",
                pendingRequestID: &pendingRequestID
            )
        )
        #expect(pendingRequestID == "newer")
        #expect(
            WatchBolusRecommendationProtocol.consumeMatchingResponse(
                responseID: "newer",
                pendingRequestID: &pendingRequestID
            )
        )
        #expect(pendingRequestID == nil)
    }

    @Test("Bolus editing uses exact whole increments") func bolusUsesCanonicalSteps() {
        let maximum: Decimal = 10

        #expect(WatchBolusDose.amount(stepCount: 3, increment: 0.05, maximum: maximum) == 0.15)
        #expect(WatchBolusDose.amount(stepCount: 6, increment: 0.05, maximum: maximum) == 0.30)
        #expect(WatchBolusDose.amount(stepCount: 3, increment: 0.025, maximum: maximum) == 0.075)
        #expect(WatchBolusDose.amount(stepCount: 3, increment: 0.1, maximum: maximum) == 0.3)
    }

    @Test("Recommendations normalize down to pump increments") func bolusRecommendationNormalization() {
        let maximum: Decimal = 10

        #expect(WatchBolusDose.normalized(0.15, increment: 0.05, maximum: maximum) == 0.15)
        #expect(WatchBolusDose.normalized(0.30, increment: 0.05, maximum: maximum) == 0.30)
        #expect(WatchBolusDose.normalized(0.074, increment: 0.025, maximum: maximum) == 0.05)
        #expect(WatchBolusDose.normalized(12, increment: 0.1, maximum: maximum) == maximum)
    }

    @Test("Maximum bolus never exceeds a non-divisible limit") func bolusMaximumClamping() {
        let maximum: Decimal = 10.01

        #expect(WatchBolusDose.maximumStepCount(maximum: maximum, increment: 0.05) == 200)
        #expect(WatchBolusDose.amount(stepCount: 201, increment: 0.05, maximum: maximum) == 10)
    }

    @Test("Invalid bolus inputs fail closed") func invalidBolusInputs() {
        let notANumber = Decimal.nan

        #expect(WatchBolusDose.validatedIncrement(0) == WatchBolusDose.fallbackIncrement)
        #expect(WatchBolusDose.validatedIncrement(-0.05) == WatchBolusDose.fallbackIncrement)
        #expect(WatchBolusDose.maximumStepCount(maximum: -1, increment: 0.05) == 0)
        #expect(WatchBolusDose.stepCount(for: -1, increment: 0.05, maximum: 10) == 0)
        #expect(WatchBolusDose.stepCount(for: notANumber, increment: 0.05, maximum: 10) == 0)
        #expect(WatchBolusDose.stepCount(for: 1, increment: 0.05, maximum: notANumber) == 0)
    }

    @Test("Bolus formatting preserves the pump increment precision") func bolusFormattingPrecision() {
        let locale = Locale(identifier: "en_US_POSIX")

        #expect(WatchBolusDose.formatted(0.1, increment: 0.1, locale: locale) == "0.1")
        #expect(WatchBolusDose.formatted(0.15, increment: 0.05, locale: locale) == "0.15")
        #expect(WatchBolusDose.formatted(0.075, increment: 0.025, locale: locale) == "0.075")
    }

    @Test("Backdated recommendation requires complete valid simulation values") func simulationValidation() {
        #expect(WatchBolusSimulationValues.validated(cob: nil, minPredBG: 100) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: 20, minPredBG: nil) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: -1, minPredBG: 100) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: Decimal(Int16.max) + 1, minPredBG: 100) == nil)
        #expect(WatchBolusSimulationValues.validated(cob: 20, minPredBG: 100) == .init(cob: 20, minPredBG: 100))
    }
}
