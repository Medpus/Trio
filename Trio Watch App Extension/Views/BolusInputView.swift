import Foundation
import SwiftUI
import WatchKit

// MARK: - Bolus Input View

struct BolusInputView: View {
    @Binding var navigationPath: NavigationPath
    @State private var bolusAmount: Decimal = 0
    @State private var hasManuallyEditedBolus = false
    @State private var showRecommendationError = false

    let state: WatchState

    @FocusState private var isCrownFocused: Bool

    private var maximumBolusStepCount: Int {
        WatchBolusDose.maximumStepCount(maximum: state.maxBolus, increment: state.bolusIncrement)
    }

    private var selectedBolusAmount: Decimal {
        WatchBolusDose.normalized(
            bolusAmount,
            increment: state.bolusIncrement,
            maximum: state.maxBolus
        )
    }

    private var selectedBolusStepCount: Int {
        WatchBolusDose.stepCount(
            for: bolusAmount,
            increment: state.bolusIncrement,
            maximum: state.maxBolus
        )
    }

    private var crownBolusStep: Binding<Double> {
        Binding(
            get: { Double(selectedBolusStepCount) },
            set: { newValue in
                guard newValue.isFinite else { return }
                hasManuallyEditedBolus = true
                bolusAmount = WatchBolusDose.amount(
                    stepCount: Int(newValue.rounded()),
                    increment: state.bolusIncrement,
                    maximum: state.maxBolus
                )
            }
        )
    }

    private func selectRecommendation(_ recommendation: Decimal) {
        bolusAmount = WatchBolusDose.normalized(
            recommendation,
            increment: state.bolusIncrement,
            maximum: state.maxBolus
        )
    }

    var trioBackgroundColor = LinearGradient(
        gradient: Gradient(colors: [Color.bgDarkBlue, Color.bgDarkerDarkBlue]),
        startPoint: .top,
        endPoint: .bottom
    )

    var body: some View {
        VStack(spacing: 4) {
            if state.showBolusCalculationProgress {
                ProgressView(String(
                    localized: "Calculating Bolus...",
                    comment: "Progress view text on watch when calculating bolus"
                ))
                Spacer()
            } else {
                if maximumBolusStepCount <= 0 {
                    VStack(spacing: 8) {
                        Text("Bolus limit cannot be fetched from phone!").font(.headline)
                        Text("Check device settings, connect to phone, and try again.").font(.caption)
                    }
                    .scenePadding()
                } else {
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
                        .font(.caption2)
                        .foregroundStyle(Color.orange)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Carbohydrates")
                        .accessibilityValue(
                            "\(state.carbsAmount) g, \(state.carbsDateWasEdited ? state.carbsDate.formatted(date: .omitted, time: .shortened) : String(localized: "Now"))"
                        )
                    }

                    Spacer(minLength: 0)

                    HStack {
                        // "-" Button
                        Button(action: {
                            if selectedBolusStepCount > 0 {
                                hasManuallyEditedBolus = true
                                bolusAmount = WatchBolusDose.amount(
                                    stepCount: selectedBolusStepCount - 1,
                                    increment: state.bolusIncrement,
                                    maximum: state.maxBolus
                                )
                            }
                        }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .tint(Color.insulin)
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedBolusStepCount <= 0)
                        .accessibilityLabel("Decrease bolus")

                        Spacer()

                        Text(
                            "\(WatchBolusDose.formatted(selectedBolusAmount, increment: state.bolusIncrement)) \(String(localized: "U", comment: "Insulin unit"))"
                        )
                        .fontWeight(.bold)
                        .font(.system(.title2, design: .rounded))
                        .foregroundColor(
                            selectedBolusStepCount > 0 && selectedBolusStepCount >= maximumBolusStepCount ? .loopRed : .primary
                        )
                        .focusable(true)
                        .focused($isCrownFocused)
                        .digitalCrownRotation(
                            crownBolusStep,
                            from: 0,
                            through: Double(maximumBolusStepCount),
                            by: 1,
                            sensitivity: .medium,
                            isContinuous: false,
                            isHapticFeedbackEnabled: true
                        )

                        Spacer()

                        // "+" Button
                        Button(action: {
                            hasManuallyEditedBolus = true
                            bolusAmount = WatchBolusDose.amount(
                                stepCount: selectedBolusStepCount + 1,
                                increment: state.bolusIncrement,
                                maximum: state.maxBolus
                            )
                        }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .tint(Color.insulin)
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedBolusStepCount >= maximumBolusStepCount)
                        .accessibilityLabel("Increase bolus")
                    }.padding(.horizontal)

                    Spacer(minLength: 0)

                    if selectedBolusStepCount > 0 && selectedBolusStepCount >= maximumBolusStepCount {
                        Text("Bolus Limit Reached!")
                            .font(.footnote)
                            .foregroundColor(.loopRed)
                    }

                    Button("Enact Bolus") {
                        state.bolusAmount = selectedBolusAmount
                        navigationPath.append(NavigationDestinations.bolusConfirm)
                    }
                    .buttonStyle(.bordered)
                    .tint(Color.insulin)
                    .disabled(selectedBolusStepCount <= 0 || selectedBolusStepCount > maximumBolusStepCount)

                    if let recommendationError = state.bolusRecommendationError {
                        Button {
                            showRecommendationError = true
                        } label: {
                            Label("No recommendation", systemImage: "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(.yellow)
                                .frame(maxWidth: .infinity, minHeight: 28)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(recommendationError)
                        .alert("No recommendation", isPresented: $showRecommendationError) {
                            Button("OK", role: .cancel) {}
                        } message: {
                            Text(recommendationError)
                        }
                    } else {
                        Text(String(
                            format: "\(String(localized: "Recommended:", comment: "Recommended bolus on Watch")) %@ \(String(localized: "U", comment: "Insulin unit"))",
                            WatchBolusDose.formatted(
                                WatchBolusDose.normalized(
                                    state.recommendedBolus,
                                    increment: state.bolusIncrement,
                                    maximum: state.maxBolus
                                ),
                                increment: state.bolusIncrement
                            )
                        ))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
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
                selectRecommendation(state.recommendedBolus)
            }
        }
        // Add onChange to update bolus amount when recommendation changes
        .onChange(of: state.recommendedBolus) { oldValue, newValue in
            // Only update if user hasn't modified the value OR if recommendation hasn't changed
            if !hasManuallyEditedBolus, oldValue != newValue {
                selectRecommendation(newValue)
            }
        }
        .onChange(of: state.bolusIncrement) { _, _ in
            bolusAmount = selectedBolusAmount
        }
        .onChange(of: state.maxBolus) { _, _ in
            bolusAmount = selectedBolusAmount
        }
        .onDisappear {
            state.cancelBolusRecommendationRequest()
        }
    }
}
