import Foundation
import CoreGraphics

/// Joint set we track. Backed by Vision joint names but expressed as a closed enum
/// so the rest of the app doesn't depend on the framework directly.
enum Joint: String, CaseIterable {
    case nose, neck
    case lShoulder, rShoulder
    case lElbow, rElbow
    case lWrist, rWrist
    case lHip, rHip
    case lKnee, rKnee
    case lAnkle, rAnkle
}

/// One pose observation at a frame. NaN means joint not detected.
struct PoseFrame {
    let frameIndex: Int
    let timeSeconds: Double
    let joints: [Joint: CGPoint]    // image coords (origin top-left)
    let confidences: [Joint: Float]

    func point(_ j: Joint) -> CGPoint? { joints[j] }
    func confidence(_ j: Joint) -> Float { confidences[j] ?? 0 }
}

/// Detected/graded rep within a set.
struct Rep: Identifiable, Codable {
    let id: UUID
    let index: Int                  // 1-based within the set

    let tStart: Double
    let tBottom: Double
    let tEnd: Double

    let belowKneePx: Double         // hip_y − knee_y at bottom (positive = below parallel)
    let torsoLeanDeg: Double        // 0 = upright, 90 = horizontal
    let kneeTravelRatio: Double     // |knee_x_bottom − knee_x_top| / thigh_length_top
    let eccentricS: Double
    let concentricS: Double

    let depth: DepthLabel
    let issues: [Issue]

    var grade: Grade {
        if issues.isEmpty { return .good }
        // Forward lean is always bad regardless of issue count —
        // it signals a spine/load-path problem, not just a minor correction.
        if issues.contains(.forwardLean) { return .bad }
        if issues.count >= 2 { return .bad }
        return .borderline   // single issue of shallow or rushed descent
    }
}

enum DepthLabel: String, Codable {
    case good, atParallel, shallow
    var label: String {
        switch self {
        case .good:       return "Good"
        case .atParallel: return "At parallel"
        case .shallow:    return "Shallow"
        }
    }
}
enum Grade: String, Codable { case good, borderline, bad }
enum Issue: String, CaseIterable, Codable {
    case shallow
    case forwardLean
    case rushedDescent
    case armsLow        // wrist dropped toward hip instead of staying at chest
}

/// The full scorecard returned to the UI after a set finishes.
struct SetResult: Identifiable, Codable {
    let id: UUID
    let videoURL: URL
    let reps: [Rep]
    let durationS: Double
    let detectedSide: Side          // which side of the body faced the camera
    let cameraNote: String?
    let date: Date
    let exerciseId: String          // stable identifier — used to look up Exercise
    let exerciseName: String        // display name — always readable even if catalog changes
    let poseDetectionRate: Double   // 0.0–1.0; fraction of frames where body was detected

    enum Side: String, Codable { case left, right }

    /// Look up the full Exercise definition. Nil only if the exercise was removed from the catalog.
    var exerciseDefinition: Exercise? {
        Exercise.all.first { $0.id == exerciseId }
    }

    init(videoURL: URL, reps: [Rep], durationS: Double,
         detectedSide: Side, cameraNote: String?,
         date: Date = Date(), exercise: Exercise,
         poseDetectionRate: Double = 1.0) {
        self.id = UUID()
        self.videoURL = videoURL
        self.reps = reps
        self.durationS = durationS
        self.detectedSide = detectedSide
        self.cameraNote = cameraNote
        self.date = date
        self.exerciseId        = exercise.id
        self.exerciseName      = exercise.name
        self.poseDetectionRate = poseDetectionRate
    }

    // Custom decoder: poseDetectionRate defaults to 1.0 for records saved before
    // this field existed, so old history keeps loading without a key bump.
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id             = try c.decode(UUID.self,           forKey: .id)
        videoURL       = try c.decode(URL.self,            forKey: .videoURL)
        reps           = try c.decode([Rep].self,          forKey: .reps)
        durationS      = try c.decode(Double.self,         forKey: .durationS)
        detectedSide   = try c.decode(Side.self,           forKey: .detectedSide)
        cameraNote     = try c.decodeIfPresent(String.self, forKey: .cameraNote)
        date           = try c.decode(Date.self,           forKey: .date)
        exerciseId     = try c.decode(String.self,         forKey: .exerciseId)
        exerciseName   = try c.decode(String.self,         forKey: .exerciseName)
        poseDetectionRate = (try? c.decodeIfPresent(Double.self, forKey: .poseDetectionRate)) ?? 1.0
    }

    var ok: Int         { reps.filter { $0.grade == .good }.count }
    var bad: Int        { reps.filter { $0.grade == .bad }.count }
    var borderline: Int { reps.filter { $0.grade == .borderline }.count }
}

// Thresholds are now per-exercise — see Exercise.swift.
