import Foundation
import SwiftUI
import WatchKit

// MARK: - Bolus Input View

struct BolusInputView: View {
    @Binding var navigationPath: NavigationPath
    @State private var bolusAmount = 0.0
    @State private var hasManuallyEditedBolus = false

    let state: WatchState

    @FocusState private var isCrownFocused: Bool

    private var effectiveBolusLimit: Double {
        Double(truncating: state.maxBolus as NSNumber)
    }

    private var crownBolusAmount: Binding<Double> {
        Binding(
            get: { bolusAmount },
            set: { newValue in
                hasManuallyEditedBolus = true
                bolusAmount = min(max(newValue, 0), effectiveBolusLimit)
            }
        )
    }

    var trioBackgroundColor = LinearGradient(
        gradient: Gradient(colors: [Color.bgDarkBlue, Color.bgDarkerDarkBlue]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack {
            if state.showBolusCalculationProgress {
                ProgressView(String(
                    localized: "Calculating Bolus...",
                    comment: "Progress view text on watch when calculating bolus"
                ))
                Spacer()
            } else {
                if effectiveBolusLimit <= 0 {
                    VStack(spacing: 8) {
                        Text("Bolus limit cannot be fetched from phone!").font(.headline)
                        Text("Check device settings, connect to phone, and try again.").font(.caption)
                    }
                    .scenePadding()
                } else {
                    if state.carbsAmount > 0 {
                        // Display the current carb amount
                        HStack {
                            Text("Carbs:").bold().font(.subheadline).padding(.leading)
                            Text("\(state.carbsAmount) g").font(.subheadline).foregroundStyle(Color.orange)
                            if state.carbsDateWasEdited {
                                Text(state.carbsDate, style: .time).font(.caption2).foregroundStyle(Color.orange)
                            } else {
                                Text("Now").font(.caption2).foregroundStyle(Color.secondary)
                            }
                            Spacer()
                        }
                    }

                    Spacer()

                    HStack {
                        // "-" Button
                        Button(action: {
                            if bolusAmount > 0 {
                                hasManuallyEditedBolus = true
                                bolusAmount -= Double(truncating: state.bolusIncrement as NSNumber)
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .tint(Color.insulin)
                        }
                        .buttonStyle(.borderless)
                        .disabled(bolusAmount <= 0)

                        Spacer()

                        let bolusIncrement = Double(truncating: state.bolusIncrement as NSNumber)
                        let adjustedBolusAmount = floor(bolusAmount / bolusIncrement) * bolusIncrement

                        Text(String(format: "%.2f \(String(localized: "U", comment: "Insulin unit"))", adjustedBolusAmount))
                            .fontWeight(.bold)
                            .font(.system(.title2, design: .rounded))
                            .foregroundColor(bolusAmount > 0.0 && bolusAmount >= effectiveBolusLimit ? .loopRed : .primary)
                            .focusable(true)
                            .focused($isCrownFocused)
                            .digitalCrownRotation(
                                crownBolusAmount,
                                from: 0,
                                through: effectiveBolusLimit,
                                by: Double(truncating: state.bolusIncrement as NSNumber),
                                sensitivity: .medium,
                                isContinuous: false,
                                isHapticFeedbackEnabled: true
                            )

                        Spacer()

                        // "+" Button
                        Button(action: {
                            hasManuallyEditedBolus = true
                            bolusAmount = min(
                                effectiveBolusLimit,
                                bolusAmount + Double(truncating: state.bolusIncrement as NSNumber)
                            )
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .tint(Color.insulin)
                        }
                        .buttonStyle(.borderless)
                        .disabled(bolusAmount >= effectiveBolusLimit)
                    }.padding(.horizontal)

                    Text("Insulin")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .padding(.bottom)

                    Spacer()

                    if bolusAmount > 0.0 && bolusAmount >= effectiveBolusLimit {
                        Text("Bolus Limit Reached!")
                            .font(.footnote)
                            .foregroundColor(.loopRed)
                    }

                    Button("Enact Bolus") {
                        state.bolusAmount = min(bolusAmount, effectiveBolusLimit)
                        navigationPath.append(NavigationDestinations.bolusConfirm)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.insulin)
                    .disabled(!(bolusAmount > 0.0) || bolusAmount > effectiveBolusLimit)

                    Text(String(
                        format: "\(String(localized: "Recommended:", comment: "Recommended bolus on Watch")) %.1f \(String(localized: "U", comment: "Insulin unit"))",
                        NSDecimalNumber(decimal: state.recommendedBolus).doubleValue
                    ))
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if let recommendationError = state.bolusRecommendationError {
                        Text(recommendationError)
                            .font(.caption2)
                            .foregroundStyle(.yellow)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .background(trioBackgroundColor)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Image(systemName: "syringe.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .padding()
                    .background(Color.insulin)
                    .foregroundStyle(.white)
                    .clipShape(Circle())
            }
        }
        .onAppear {
            // Set initial bolus amount to recommended value
            // Only do this if user has not updated amount previously, e.g., when navigating to next and then back to this view
            if bolusAmount == 0 {
                hasManuallyEditedBolus = false
                state.requestBolusRecommendation()
                bolusAmount = Double(truncating: NSDecimalNumber(decimal: state.recommendedBolus))
            }
        }
        // Add onChange to update bolus amount when recommendation changes
        .onChange(of: state.recommendedBolus) { oldValue, newValue in
            // Only update if user hasn't modified the value OR if recommendation hasn't changed
            if !hasManuallyEditedBolus, oldValue != newValue {
                bolusAmount = Double(truncating: NSDecimalNumber(decimal: newValue))
            }
        }
        .onDisappear {
            state.cancelBolusRecommendationRequest()
        }
    }
}
