import Foundation
import SwiftUI

// MARK: - Carbs Input View

struct CarbsInputView: View {
    private enum InputMode {
        case carbs
        case date
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
        let buttonLabel = continueToBolus ? String(localized: "Continue", comment: "Continue from carbs to bolus on Watch") :
            String(localized: "Save", comment: "Save carbs on Watch")

        // TODO: introduce meal setting fpu enablement to conditional handle FPU
        VStack(spacing: 8) {
            Spacer(minLength: 0)

            VStack(spacing: 8) {
                // The values are the mode selector. Keep both targets large enough to avoid
                // changing carbohydrates when the user intended to adjust the meal time.
                HStack(spacing: 6) {
                    Button {
                        inputMode = .carbs
                        isCrownFocused = true
                    } label: {
                        Text(String(format: "%.0f \(String(localized: "g", comment: "gram of carbs"))", carbsAmount))
                            .fontWeight(.bold)
                            .font(.system(.title2, design: .rounded))
                            .foregroundStyle(
                                carbsAmount > 0.0 && carbsAmount >= effectiveCarbsLimit ? .loopRed : .primary
                            )
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .background(inputMode == .carbs ? Color.orange.opacity(0.22) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(inputMode == .carbs ? Color.orange : Color.secondary.opacity(0.45), lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Carbohydrates")
                    .accessibilityValue(String(
                        format: "%.0f \(String(localized: "g", comment: "gram of carbs"))",
                        carbsAmount
                    ))
                    .accessibilityHint("Tap, then turn the Digital Crown to adjust")
                    .accessibilityAddTraits(inputMode == .carbs ? .isSelected : [])

                    Button {
                        inputMode = .date
                        isCrownFocused = true
                    } label: {
                        Group {
                            if carbsDateWasEdited {
                                Text(carbsDate, style: .time)
                            } else {
                                Text("Now")
                            }
                        }
                        .font(.body)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, minHeight: 36)
                        .background(inputMode == .date ? Color.orange.opacity(0.22) : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(inputMode == .date ? Color.orange : Color.secondary.opacity(0.45), lineWidth: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Time")
                    .accessibilityValue(
                        carbsDateWasEdited ? carbsDate.formatted(date: .omitted, time: .shortened) : String(localized: "Now")
                    )
                    .accessibilityHint("Tap, then turn the Digital Crown to adjust")
                    .accessibilityAddTraits(inputMode == .date ? .isSelected : [])
                }

                HStack {
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
                            .frame(width: 44, height: 34)
                    }
                    .buttonStyle(.borderless)
                    .tint(.orange)
                    .disabled(inputMode == .carbs && carbsAmount <= 0)
                    .accessibilityLabel(inputMode == .carbs ? "Decrease carbohydrates" : "Earlier meal time")

                    Spacer()

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
                            .frame(width: 44, height: 34)
                    }
                    .buttonStyle(.borderless)
                    .tint(.orange)
                    .disabled(inputMode == .carbs && carbsAmount >= effectiveCarbsLimit)
                    .accessibilityLabel(inputMode == .carbs ? "Increase carbohydrates" : "Later meal time")
                }
            }
            .padding(.horizontal)
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

            Spacer(minLength: 0)

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
