import Foundation
import SwiftUI
import WatchKit

struct BolusConfirmationView: View {
    @Binding var navigationPath: NavigationPath
    let state: WatchState
    @Binding var bolusAmount: Decimal
    @Binding var confirmationProgress: Double

    @FocusState private var isCrownFocused: Bool

    var trioBackgroundColor = LinearGradient(
        gradient: Gradient(colors: [Color.bgDarkBlue, Color.bgDarkerDarkBlue]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            VStack(spacing: 6) {
                if state.carbsAmount > 0 {
                    HStack(spacing: 8) {
                        Image(systemName: "fork.knife")
                            .accessibilityHidden(true)
                        Text("\(state.carbsAmount) g")
                        if state.carbsDateWasEdited {
                            Text(state.carbsDate, style: .time)
                        } else {
                            Text("Now")
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.orange)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Carbohydrates")
                    .accessibilityValue(
                        "\(state.carbsAmount) g, \(state.carbsDateWasEdited ? state.carbsDate.formatted(date: .omitted, time: .shortened) : String(localized: "Now"))"
                    )
                }

                HStack(spacing: 5) {
                    Image(systemName: "syringe.fill")
                        .accessibilityHidden(true)
                    Text(
                        "\(WatchBolusDose.formatted(bolusAmount, increment: state.bolusIncrement)) \(String(localized: "U", comment: "Insulin unit"))"
                    )
                    .bold()
                }
                .font(.title3)
                .foregroundStyle(Color.insulin)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Bolus")
                .accessibilityValue(
                    "\(WatchBolusDose.formatted(bolusAmount, increment: state.bolusIncrement)) \(String(localized: "U", comment: "Insulin unit"))"
                )
            }

            ProgressView(value: confirmationProgress, total: 1.0)
                .tint(confirmationProgress >= 1.0 ? .loopGreen : .gray)
                .padding(.horizontal)

            Text("Turn Crown to confirm")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Spacer(minLength: 0)

            Button("Cancel") {
                if state.carbsAmount > 0 {
                    state.carbsAmount = 0 // reset carbs in state
                    state.carbsDate = Date()
                    state.carbsDateWasEdited = false
                }
                bolusAmount = 0 // reset bolus in state
                confirmationProgress = 0 // reset auth progress
                navigationPath.removeLast(navigationPath.count)
            }
            .buttonStyle(.bordered)
        }
        .focusable(true)
        .focused($isCrownFocused)
        .digitalCrownRotation(
            $confirmationProgress,
            from: 0.0,
            through: 1.0,
            by: state.confirmBolusFaster ? 0.5 : 0.05,
            sensitivity: .medium,
            isContinuous: false,
            isHapticFeedbackEnabled: true
        )
        .onAppear {
            isCrownFocused = true
        }
        .onChange(of: confirmationProgress) { _, newValue in
            if newValue >= 1.0 {
                WKInterfaceDevice.current().play(.success)

                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    if state.carbsAmount > 0 {
                        let entryDate = WatchCarbEntryTiming.submissionDate(
                            selectedDate: state.carbsDate,
                            wasEdited: state.carbsDateWasEdited
                        )
                        state.sendCarbsRequest(state.carbsAmount, entryDate)
                        state.carbsAmount = 0 // reset carbs in state
                        state.carbsDate = Date()
                        state.carbsDateWasEdited = false
                    }
                    state.sendBolusRequest(bolusAmount)
                    bolusAmount = 0 // reset bolus in state
                    confirmationProgress = 0 // reset auth progress
                    navigationPath.append(NavigationDestinations.acknowledgmentPending)
                }
            } else if newValue > 0 {
                WKInterfaceDevice.current().play(.click)
            }
        }
        .background(trioBackgroundColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(
                    systemName: WKInterfaceDevice.current()
                        .wristLocation == .left ? "digitalcrown.arrow.clockwise.fill" : "digitalcrown.arrow.counterclockwise.fill"
                )
                .symbolRenderingMode(.palette)
                .foregroundStyle(Color.insulin, Color.primary)
                .symbolEffect(
                    .variableColor.reversing,
                    options: .speed(100).repeating
                )
            }
        }
    }
}
