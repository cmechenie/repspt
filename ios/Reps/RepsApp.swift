import SwiftUI

@main
struct RepsPTApp: App {
    @State private var entitlements = EntitlementManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(entitlements)
        }
    }
}

/// Top-level state machine for the single-set MVP.
enum AppPhase {
    case idle                   // showing camera preview, waiting for user to tap Record
    case recording              // recording in progress
    case analyzing              // post-stop, running pose + metrics
    case results(SetResult)     // showing scorecard for the set
}

struct RootView: View {
    @State private var phase: AppPhase = .idle
    @State private var selectedExercise: Exercise = .gobletSquat
    @StateObject private var recorder = CameraRecorder()
    @StateObject private var history  = HistoryStore()

    /// Persists across launches. Flipped to true when the user completes or
    /// skips onboarding. Bump the key suffix to re-show onboarding after a
    /// major redesign (e.g. "repspt.onboarding.v2").
    @AppStorage("repspt.onboarding.v1") private var onboardingDone = false

    var body: some View {
        ZStack {
            switch phase {
            case .idle, .recording:
                RecordView(recorder: recorder,
                           phase: $phase,
                           history: history,
                           selectedExercise: $selectedExercise)
            case .analyzing:
                AnalyzingView()
            case .results(let result):
                ResultsView(result: result, onDismiss: { phase = .idle })
            }
        }
        .ignoresSafeArea()
        .preferredColorScheme(.dark)
        .fullScreenCover(isPresented: Binding(
            get: { !onboardingDone },
            set: { if !$0 { onboardingDone = true } }
        )) {
            OnboardingView { onboardingDone = true }
        }
    }
}
