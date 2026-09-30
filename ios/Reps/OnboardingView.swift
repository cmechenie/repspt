import SwiftUI

// =====================================================================
// Onboarding — shown on first launch only.
// Gated by @AppStorage("repspt.onboarding.v1") in RootView.
// Three swipeable pages:
//   1. What RepsPT does
//   2. How to set up your camera
//   3. How to read your scorecard  →  "Get Started"
// =====================================================================

struct OnboardingView: View {
    let onDone: () -> Void
    @State private var page = 0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Color.black.ignoresSafeArea()

            TabView(selection: $page) {
                WhatItDoesPage().tag(0)
                CameraSetupPage().tag(1)
                ScorecardPage(onDone: onDone).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            // Skip — lets experienced users jump straight in
            Button("Skip") { onDone() }
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.45))
                .padding(.top, 56)
                .padding(.trailing, 20)
        }
    }
}

// =====================================================================
// Page 1 — What RepsPT does
// =====================================================================
private struct WhatItDoesPage: View {
    var body: some View {
        OnboardingPageShell {
            VStack(spacing: 0) {
                // Icon cluster
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 56))
                        .foregroundStyle(.green)
                }
                .padding(.bottom, 36)

                Text("Your AI form coach")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 16)

                Text("Point your phone at yourself during a set. RepsPT counts every rep and grades your form — depth, tempo, and posture — then gives you coaching cues at the end.")
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                Text("Swipe to continue")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.bottom, 60)
            }
        }
    }
}

// =====================================================================
// Page 2 — Camera setup
// =====================================================================
private struct CameraSetupPage: View {
    private let tips: [(String, String, String)] = [
        ("3 – 8 ft away",    "ruler",               "Your full body should be in frame from head to toe."),
        ("Hip height",        "arrow.up.and.down",   "Works for most exercises. Pull-ups need ~10 ft."),
        ("Any orientation",   "iphone.landscape",    "Landscape or portrait — the app handles both."),
        ("Steady the phone",  "camera.on.rectangle", "Lean it on a water bottle, bag, or use a mini tripod."),
    ]

    var body: some View {
        OnboardingPageShell {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "camera.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.blue)
                }
                .padding(.bottom, 36)

                Text("Set up your camera")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 20) {
                    ForEach(tips, id: \.0) { tip in
                        TipRow(symbol: tip.1, title: tip.0, description: tip.2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()

                Text("The app shows a specific hint for each exercise before you record.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.35))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 60)
            }
        }
    }
}

private struct TipRow: View {
    let symbol:      String
    let title:       String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundStyle(.white)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// =====================================================================
// Page 3 — Scorecard legend + Get Started
// =====================================================================
private struct ScorecardPage: View {
    let onDone: () -> Void

    private let grades: [(String, Color, String)] = [
        ("Good",        .green,  "Depth, tempo, and posture all on point."),
        ("Borderline",  .yellow, "One minor issue — single coaching cue."),
        ("Bad",         .red,    "Forward lean or two or more issues combined."),
    ]

    var body: some View {
        OnboardingPageShell {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.12))
                        .frame(width: 120, height: 120)
                    Image(systemName: "chart.bar.fill")
                        .font(.system(size: 50))
                        .foregroundStyle(.orange)
                }
                .padding(.bottom, 36)

                Text("Read your scorecard")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 24)

                VStack(alignment: .leading, spacing: 18) {
                    ForEach(grades, id: \.0) { grade in
                        GradeRow(label: grade.0, color: grade.1, description: grade.2)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.bottom, 32)

                Text("Watch the video replay at the top of the scorecard while reading the cues below it.")
                    .font(.footnote)
                    .foregroundStyle(.white.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .padding(.bottom, 32)

                Spacer()

                // Primary CTA
                Button(action: onDone) {
                    Text("Get Started")
                        .font(.headline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.bottom, 52)
            }
        }
    }
}

private struct GradeRow: View {
    let label:       String
    let color:       Color
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Circle()
                .fill(color.opacity(0.25))
                .overlay(Circle().strokeBorder(color, lineWidth: 1.5))
                .frame(width: 14, height: 14)
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline.bold())
                    .foregroundStyle(color)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// =====================================================================
// Shared page container
// =====================================================================
private struct OnboardingPageShell<Content: View>: View {
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack {
            content()
        }
        .padding(.horizontal, 32)
        .padding(.top, 80)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}
