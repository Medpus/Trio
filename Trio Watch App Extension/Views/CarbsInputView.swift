import Foundation
import SwiftUI

// MARK: - Carbs Input View

struct CarbsInputView: View {
    private enum InputMode {
        case carbs
        case date

        mutating func toggle() {
            self = self == .carbs ? .date : .carbs
        }
    }

    @Binding var navigationPath: NavigationPath
    @State private var carbsAmount: Double = 0.0 // Needs to be Double due to .digitalCrownRotation() stride
    @State private var carbsDate = Date()
    @State private var initialDate = Date()
    @State private var carbsDateWasEdited = false
    @State private var inputMode: InputMode = .carbs
    @State private var hasInitializedDate = false
    @FocusState private var isCrownFocused: Bool // Manage crown focus

    let state: WatchState
    let continueToBolus: Bool

    private var effectiveCarbsLimit: Double {
        Double(truncating: state.maxCarbs as NSNumber)
    }

    private var crownValue: Binding<Double> {
        Binding(
            get: {
                switch inputMode {
                case .carbs:
                    return carbsAmount
                case .date:
                    return carbsDate.timeIntervalSince(initialDate) / 60
                }
            },
            set: { newValue in
                switch inputMode {
                case .carbs:
                    carbsAmount = min(max(newValue, 0), effectiveCarbsLimit)
                case .date:
                    carbsDate = initialDate.addingTimeInterval(newValue * 60)
                    carbsDateWasEdited = true
                }
            }
        )
    }

    private var crownRange: ClosedRange<Double> {
        switch inputMode {
        case .carbs:
            return 0 ... effectiveCarbsLimit
        case .date:
            return -(WatchCarbEntryTiming.pastLimit / 60) ... 0
        }
    }

    private var selectedCarbsDate: Date {
        WatchCarbEntryTiming.submissionDate(selectedDate: carbsDate, wasEdited: carbsDateWasEdited)
    }

    var trioBackgroundColor = LinearGradient(
        gradient: Gradient(colors: [Color.bgDarkBlue, Color.bgDarkerDarkBlue]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        let buttonLabel = continueToBolus ? String(localized: "Proceed", comment: "Button Label to Proceed to Bolus on Watch") :
            String(localized: "Log Carbs", comment: "Button Label to Log Carbs on Watch")

        // TODO: introduce meal setting fpu enablement to conditional handle FPU
        VStack {
            Spacer()

            HStack {
                // "-" Button
                Button(action: {
                    switch inputMode {
                    case .carbs:
                        if carbsAmount > 0 {
                            carbsAmount < 5 ? carbsAmount = 0 : (carbsAmount -= 5)
                        }
                    case .date:
                        carbsDate = WatchCarbEntryTiming.clamped(
                            carbsDate.addingTimeInterval(-WatchCarbEntryTiming.buttonStep),
                            relativeTo: initialDate
                        )
                        carbsDateWasEdited = true
                    }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .font(.title3)
                        .tint(.orange)
                }
                .buttonStyle(.borderless)
                .disabled(inputMode == .carbs && carbsAmount <= 0)

                Spacer()

                // Tap the amount/time to choose what the Digital Crown edits, matching Loop's watch flow.
                VStack(spacing: 2) {
                    Text(String(format: "%.0f \(String(localized: "g", comment: "gram of carbs"))", carbsAmount))
                        .fontWeight(.bold)
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(
                            carbsAmount > 0.0 && carbsAmount >= effectiveCarbsLimit ? .loopRed :
                                (inputMode == .carbs ? .primary : .secondary)
                        )

                    if carbsDateWasEdited {
                        Text(carbsDate, style: .time)
                            .font(.footnote)
                            .foregroundStyle(inputMode == .date ? Color.orange : Color.secondary)
                    } else {
                        Text("Now")
                            .font(.footnote)
                            .foregroundStyle(inputMode == .date ? Color.orange : Color.secondary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    inputMode.toggle()
                    isCrownFocused = true
                }
                .focusable(true)
                .focused($isCrownFocused)
                .digitalCrownRotation(
                    crownValue,
                    from: crownRange.lowerBound,
                    through: crownRange.upperBound,
                    by: 1,
                    sensitivity: .medium,
                    isContinuous: false,
                    isHapticFeedbackEnabled: true
                )

                Spacer()

                // "+" Button
                Button(action: {
                    switch inputMode {
                    case .carbs:
                        carbsAmount = min(effectiveCarbsLimit, carbsAmount + 5)
                    case .date:
                        carbsDate = WatchCarbEntryTiming.clamped(
                            carbsDate.addingTimeInterval(WatchCarbEntryTiming.buttonStep),
                            relativeTo: initialDate
                        )
                        carbsDateWasEdited = true
                    }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                        .tint(.orange)
                }
                .buttonStyle(.borderless)
                .disabled(inputMode == .carbs && carbsAmount >= effectiveCarbsLimit)
            }.padding(.horizontal)

            Text("Carbohydrates")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .padding(.bottom)

            Spacer()

            if carbsAmount > 0.0 && carbsAmount >= effectiveCarbsLimit {
                Text("Carbs Limit Reached!")
                    .font(.footnote)
                    .foregroundColor(.loopRed)
            }

            Button(buttonLabel) {
                if continueToBolus {
                    state.carbsAmount = Int(min(carbsAmount, effectiveCarbsLimit))
                    state.carbsDate = selectedCarbsDate
                    state.carbsDateWasEdited = carbsDateWasEdited
                    navigationPath.append(NavigationDestinations.bolusInput)
                } else {
                    state.sendCarbsRequest(Int(min(carbsAmount, effectiveCarbsLimit)), selectedCarbsDate)
                    navigationPath.append(NavigationDestinations.acknowledgmentPending)
                }
            }
            .buttonStyle(.bordered)
            .tint(.orange)
            .disabled(!(carbsAmount > 0.0) || carbsAmount > effectiveCarbsLimit)
        }
        .onAppear {
            if !hasInitializedDate {
                initialDate = Date()
                carbsDate = initialDate
                hasInitializedDate = true
            }
            isCrownFocused = true
        }
        .background(trioBackgroundColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "fork.knife")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
        }
    }
}
