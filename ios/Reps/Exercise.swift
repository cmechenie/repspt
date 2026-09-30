import Foundation

// =====================================================================
// Algorithm signal — determines which joint drives rep detection.
//   .hip   — squats, lunges, hinges: hip Y peak = bottom of rep
//   .wrist — presses, overhead:      wrist Y peak = bottom of rep
// Adding a new exercise type may require a new case here and a
// corresponding branch in RepDetector.process.
// =====================================================================
enum RepSignalJoint: String, Codable {
    case hip
    case wrist
}

// =====================================================================
// GestureKind — how the user signals the set is finished.
//
//   .thumbsUp — one hand raised with thumb up, held ~0.5 s.
//               Detected via VNDetectHumanHandPoseRequest.
//               Used when at least one hand can always be freed
//               safely after the last rep.
//
//   .headNod  — two deliberate downward nods within 2.5 s.
//               Detected from the neck–shoulder relative position
//               in the existing VNDetectHumanBodyPoseRequest stream,
//               so whole-body rep oscillations don't trigger it.
//               Used when both hands are occupied or planted
//               (goblet squat with heavy DB, push-up, pull-up,
//                ab wheel, hanging leg raise).
// =====================================================================
enum GestureKind: String, Codable {
    case thumbsUp
    case headNod
}

// =====================================================================
// Exercise category — user-facing taxonomy (muscle group).
// Matches how gym-goers plan sessions ("chest day", "leg day").
// Adding a new category: add a case + fill in the three properties.
// =====================================================================
enum ExerciseCategory: String, CaseIterable, Codable, Identifiable {
    case legs, chest, back, shoulders, arms, core

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .legs:      return "Legs"
        case .chest:     return "Chest"
        case .back:      return "Back"
        case .shoulders: return "Shoulders"
        case .arms:      return "Arms"
        case .core:      return "Core"
        }
    }

    var sfSymbol: String {
        switch self {
        case .legs:      return "figure.run"
        case .chest:     return "figure.arms.open"
        case .back:      return "figure.strengthtraining.functional"
        case .shoulders: return "figure.mixed.cardio"
        case .arms:      return "dumbbell"
        case .core:      return "circle.circle"
        }
    }

    var description: String {
        switch self {
        case .legs:      return "Squats, lunges, hinges"
        case .chest:     return "Presses & push-ups"
        case .back:      return "Pulls & rows"
        case .shoulders: return "Overhead press & raises"
        case .arms:      return "Curls & extensions"
        case .core:      return "Abs & planks"
        }
    }

    /// All exercises registered for this category.
    var exercises: [Exercise] { Exercise.all.filter { $0.category == self } }

    /// True when at least one exercise in this category is available to record.
    var hasAvailableExercises: Bool { exercises.contains { $0.isAvailable } }

    /// Count of exercises available to record.
    var availableCount: Int { exercises.filter { $0.isAvailable }.count }
}

// =====================================================================
// Exercise — one entry in the exercise library.
//
// Threshold fields are grouped by concern:
//   Rep detection  — prominenceFraction, dropFractionMin, tempoValid*
//   Depth / ROM    — depthGoodPx / depthParallelPx
//                    (for wrist exercises these represent wrist-drop px)
//   Lean grading   — leanBadDeg (hip→neck angle; set 999 to disable)
//   Bend-over filter — bendOverLean/TravelMax (squat family; 999 disables)
//   Arms check     — checksArms / armsLowRatio (goblet squat only)
//
// Adding a new exercise: one new `static let` below. Zero algorithm changes
// if the exercise uses an existing RepSignalJoint. New movement patterns
// (e.g. horizontal pull) may need a new signal case in RepDetector.
// =====================================================================
struct Exercise: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let category: ExerciseCategory
    let sfSymbol: String
    let description: String      // 1-line shown in picker card
    let cameraHint: String       // shown on-screen before recording
    let isAvailable: Bool        // false → "Coming Soon" in picker, unselectable

    // MARK: Algorithm routing
    let repSignalJoint: RepSignalJoint

    // MARK: Rep detection
    let prominenceFraction: Double   // min peak prominence as fraction of signal range
    let dropFractionMin: Double      // min drop from rep top → rep counted
    let tempoRushS: Double           // eccentric < this → .rushedDescent
    let tempoValidMin: Double        // reps outside [min, max] eccentric ignored
    let tempoValidMax: Double
    /// Minimum drop as a fraction of the person's torso height (hipY − shoulderY).
    /// Body-size-normalised filter that rejects walking/repositioning noise at
    /// any point in the clip — including background walkers and the subject
    /// walking to the phone after finishing.
    /// Walking oscillates < 10 % of torso height; real reps drop 15–80 %.
    /// RepDetector only applies this when medianTorso > 50 px, so it is
    /// automatically inactive for horizontal exercises (push-up, ab wheel):
    /// when lying flat hipY ≈ shoulderY → medianTorso ≈ 0, guard fires.
    /// Set 0.0 only when the exercise geometry makes the check meaningless
    /// even in the standing phase (e.g. "coming soon" placeholders).
    let minDropFracOfTorso: Double

    // MARK: Depth / ROM grading
    // For .hip:   primaryMetric = hipY_bottom − kneeY_bottom (px above/below knee)
    // For .wrist: primaryMetric = wristY_bottom − wristY_top (wrist drop in px)
    let depthGoodPx: Double          // primaryMetric > this → full depth / full ROM
    let depthParallelPx: Double      // primaryMetric > this → at-parallel / partial ROM

    // MARK: Lean grading (.hip only)
    let leanBadDeg: Double           // hip→neck angle > this → .forwardLean; 999 = disabled

    // MARK: Bend-over filter (.hip only)
    let bendOverLeanDeg: Double      // high lean + low knee travel → skip rep; 999 = disabled
    let bendOverTravelMax: Double

    // MARK: Arms check (goblet squat only)
    let checksArms: Bool
    let armsLowRatio: Double         // wrist/(torso height) ratio → .armsLow; 999 = disabled

    // MARK: End-of-set gesture
    let gestureKind: GestureKind
    /// Seconds before the gesture's first detected frame to trim from analysis.
    /// Removes the transition movement between the last rep and the gesture signal
    /// (e.g. lowering weights, stepping off bench) without cutting the last rep.
    let gestureBufferS: Double
    /// Brief instruction shown on-screen during recording so the user knows
    /// how to signal the end of the set.
    let gestureHint: String
}
