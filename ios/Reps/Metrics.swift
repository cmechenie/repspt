import Foundation
import CoreGraphics

/// Single-set rep detection + grading. Operates on PoseFrames from PoseAnalyzer.
///
/// Algorithm overview
/// ──────────────────
/// 1. Pick the camera-near body side (higher Vision confidence).
/// 2. Extract and smooth joint series for that side.
/// 3. Choose the primary rep signal based on exercise.repSignalJoint:
///      .hip   → hip Y series   (squats, lunges — hip peaks at bottom of rep)
///      .wrist → wrist Y series (presses — wrist peaks when lowered to chest)
/// 4. Find peaks in the primary Y series (local maxima above prominence threshold).
/// 5. For each peak, find the surrounding local minima (rep top) and validate
///    eccentric/concentric tempo + minimum drop fraction.
/// 6. Compute per-rep metrics and flag issues.
///
/// Adding a new exercise type (new RepSignalJoint): add a case to the switch
/// statements below and define appropriate metrics.
struct RepDetector {

    // MARK: - Tuning constants
    // Frame counts assume ~30 fps video.

    /// Minimum frames between two rep-bottom peaks (~1.5 s — no legal rep is faster).
    private static let minPeakDistanceFrames = 45
    /// How far around a peak to search for the rep tops (local minima), ~3 s.
    private static let repWindowFrames = 90
    /// Torso height (px) below which the body-size-normalised drop filter is
    /// skipped — the person is horizontal (push-up, ab wheel) so hipY ≈ shoulderY.
    private static let torsoFilterMinPx: Double = 50
    /// Longest run of missing joint values (frames) that gets linearly interpolated.
    private static let interpMaxGapFrames = 30
    /// Window (frames) for the median + mean smoothing passes.
    private static let smoothWindowFrames = 7

    // Camera-note thresholds (fractions of frames with the body detected).
    private static let detectionVeryPoor = 0.35
    private static let detectionPartial  = 0.70
    /// Per-joint confidence above which a joint counts as "seen" in a frame.
    private static let jointSeenConfidence: Float = 0.15
    /// Region visibility rate below which a region-specific framing hint is shown.
    private static let regionVisibleMin = 0.40

    static func process(frames: [PoseFrame], exercise: Exercise) -> SetResult {
        guard !frames.isEmpty else {
            return SetResult(videoURL: URL(fileURLWithPath: "/dev/null"),
                             reps: [], durationS: 0,
                             detectedSide: .right,
                             cameraNote: "no frames",
                             exercise: exercise)
        }
        let duration = (frames.last?.timeSeconds ?? 0) - (frames.first?.timeSeconds ?? 0)

        // ---- pick camera-near side ----
        let side       = pickSide(frames: frames)
        let hipJ:      Joint = side == .right ? .rHip      : .lHip
        let kneeJ:     Joint = side == .right ? .rKnee     : .lKnee
        let wristJ:    Joint = side == .right ? .rWrist    : .lWrist
        let shoulderJ: Joint = side == .right ? .rShoulder : .lShoulder
        let neckJ:     Joint = .neck

        // ---- extract & smooth all series ----
        let times     = frames.map { $0.timeSeconds }
        let hipY      = smooth(seriesY(frames, joint: hipJ))
        let hipX      = smooth(seriesX(frames, joint: hipJ))
        let kneeY     = smooth(seriesY(frames, joint: kneeJ))
        let kneeX     = smooth(seriesX(frames, joint: kneeJ))
        let neckY     = smooth(seriesY(frames, joint: neckJ))
        let neckX     = smooth(seriesX(frames, joint: neckJ))
        let wristY    = smooth(seriesY(frames, joint: wristJ))

        let shoulderY = smooth(seriesY(frames, joint: shoulderJ))

        // ---- choose primary rep signal ----
        // Both signals use the same peak-finding algorithm.
        // In image coords (Y grows downward), the primary joint is at its
        // MAXIMUM Y value at the bottom of each rep, giving us local peaks.
        let primaryY: [Double?]
        switch exercise.repSignalJoint {
        case .hip:   primaryY = hipY
        case .wrist: primaryY = wristY
        }

        // ---- detection ----
        let yRange     = (primaryY.compactMap { $0 }.max() ?? 0)
                       - (primaryY.compactMap { $0 }.min() ?? 0)
        let prominence = exercise.prominenceFraction * yRange
        let peaks      = findPeaks(primaryY, minDistanceFrames: minPeakDistanceFrames, minProminence: prominence)

        // ---- body-size-normalised drop floor ----
        // Torso height (hipY − shoulderY in pixels) scales automatically with
        // camera distance, giving a body-relative reference.
        // Walking oscillations are ≈ 5–10 % of torso height; real squat/lunge
        // reps are ≈ 25–80 %.  medianTorso is used in the rep-validation loop.
        let torsoHeights: [Double] = zip(hipY, shoulderY).compactMap { hy, sy in
            guard let h = hy, let s = sy, h > s else { return nil }
            return h - s
        }
        let medianTorso: Double = {
            let sorted = torsoHeights.sorted()
            guard !sorted.isEmpty else { return 0 }
            return sorted[sorted.count / 2]
        }()

        // ---- validate each peak as a rep ----
        let windowFrames = repWindowFrames
        var reps: [Rep] = []

        for p in peaks {
            // vStart / vEnd are the rep tops (primary signal minima around the peak)
            guard let vStart = argmin(primaryY, from: max(0, p - windowFrames), to: p),
                  let vEnd   = argmin(primaryY, from: p, to: min(primaryY.count, p + windowFrames))
            else { continue }

            let ecc = times[p] - times[vStart]   // eccentric (lowering) duration
            let con = times[vEnd] - times[p]      // concentric (lifting) duration
            guard ecc >= exercise.tempoValidMin, ecc <= exercise.tempoValidMax,
                  con >= exercise.tempoValidMin, con <= exercise.tempoValidMax else { continue }

            let drop = (primaryY[p] ?? 0) - (primaryY[vStart] ?? 0)
            guard drop >= exercise.dropFractionMin * yRange else { continue }

            // ---- body-size-normalised noise filter ----
            // Rejects walking / repositioning oscillations that survive the
            // yRange check (which gets inflated when the person walks toward
            // the camera, or at the end of the clip when they walk to the phone).
            // medianTorso > torsoFilterMinPx is the only gate: for floor exercises
            // (push-up, ab wheel) the person lies flat so hipY ≈ shoulderY,
            // medianTorso collapses to near-zero, and the check is skipped
            // automatically — no per-exercise opt-out needed.
            if medianTorso > torsoFilterMinPx {
                guard drop / medianTorso >= exercise.minDropFracOfTorso else { continue }
            }

            // ---- bend-over filter (hip-signal exercises only) ----
            // Skips deadlift-style movements that share the hip-peak signal
            // but aren't squats.
            if exercise.repSignalJoint == .hip {
                if let provLean   = leanDeg(hipX[p], hipY[p], neckX[p], neckY[p]),
                   let provTravel = travelRatio(kneeX[p], kneeX[vStart], kneeY[vStart], hipY[vStart]),
                   provLean   > exercise.bendOverLeanDeg,
                   provTravel < exercise.bendOverTravelMax {
                    continue
                }
            }

            // ---- per-rep metrics (branched by signal type) ----
            // primaryMetric is stored in Rep.belowKneePx.
            // For .hip:   hipY_bottom − kneeY_bottom  (positive = hip below knee)
            // For .wrist: wristY_bottom − wristY_top  (positive = wrist descended)
            let primaryMetric: Double
            let lean: Double
            let travel: Double

            switch exercise.repSignalJoint {
            case .hip:
                primaryMetric = (hipY[p] ?? 0) - (kneeY[p] ?? 0)
                lean          = leanDeg(hipX[p], hipY[p], neckX[p], neckY[p]) ?? 0
                travel        = travelRatio(kneeX[p], kneeX[vStart], kneeY[vStart], hipY[vStart]) ?? 0
            case .wrist:
                primaryMetric = (wristY[p] ?? 0) - (wristY[vStart] ?? 0)  // wrist drop
                lean          = 0    // not applicable for press exercises
                travel        = 0
            }

            // ---- issue flags ----
            let depth = depthLabel(primaryMetric, exercise: exercise)
            var issues: [Issue] = []
            if depth == .shallow { issues.append(.shallow) }
            // Forward lean only meaningful for hip-signal exercises
            if exercise.repSignalJoint == .hip, lean > exercise.leanBadDeg {
                issues.append(.forwardLean)
            }
            if ecc < exercise.tempoRushS { issues.append(.rushedDescent) }

            // Arms check — goblet squat only
            if exercise.checksArms,
               let wy = wristY[p], let sy = shoulderY[p], let hy = hipY[p] {
                let torso = hy - sy
                if torso > 1 {
                    let wristRatio = (wy - sy) / torso
                    if wristRatio > exercise.armsLowRatio { issues.append(.armsLow) }
                }
            }

            reps.append(Rep(
                id: UUID(),
                index: reps.count + 1,
                tStart: times[vStart], tBottom: times[p], tEnd: times[vEnd],
                belowKneePx: primaryMetric,
                torsoLeanDeg: lean,
                kneeTravelRatio: travel,
                eccentricS: ecc, concentricS: con,
                depth: depth, issues: issues
            ))
        }

        // re-index after validation
        let final = reps.enumerated().map { (i, r) in
            Rep(id: r.id,
                index: i + 1, tStart: r.tStart, tBottom: r.tBottom, tEnd: r.tEnd,
                belowKneePx: r.belowKneePx, torsoLeanDeg: r.torsoLeanDeg,
                kneeTravelRatio: r.kneeTravelRatio,
                eccentricS: r.eccentricS, concentricS: r.concentricS,
                depth: r.depth, issues: r.issues)
        }

        let detectedRate = Self.detectionRate(frames: frames)
        let cameraNote   = makeCameraNote(frames: frames, reps: final,
                                          exercise: exercise, detectedRate: detectedRate)
        return SetResult(videoURL: URL(fileURLWithPath: "/dev/null"),
                         reps: final, durationS: duration,
                         detectedSide: side, cameraNote: cameraNote,
                         exercise: exercise, poseDetectionRate: detectedRate)
    }

    // MARK: - helpers

    private static func pickSide(frames: [PoseFrame]) -> SetResult.Side {
        var rScore: Double = 0, lScore: Double = 0
        for f in frames {
            rScore += Double(f.confidence(.rHip) + f.confidence(.rKnee) + f.confidence(.rShoulder))
            lScore += Double(f.confidence(.lHip) + f.confidence(.lKnee) + f.confidence(.lShoulder))
        }
        return rScore >= lScore ? .right : .left
    }

    private static func seriesY(_ frames: [PoseFrame], joint: Joint) -> [Double?] {
        frames.map { f in f.point(joint).map { Double($0.y) } }
    }
    private static func seriesX(_ frames: [PoseFrame], joint: Joint) -> [Double?] {
        frames.map { f in f.point(joint).map { Double($0.x) } }
    }

    /// Linear-interpolate short gaps, then median + mean smoothing passes.
    private static func smooth(_ s: [Double?]) -> [Double?] {
        let interp = interpolateGaps(s, maxGap: interpMaxGapFrames)
        let med    = rollingMedian(interp, win: smoothWindowFrames)
        return rollingMean(med, win: smoothWindowFrames)
    }

    private static func interpolateGaps(_ s: [Double?], maxGap: Int) -> [Double?] {
        var out = s
        var i = 0
        while i < out.count {
            if out[i] != nil { i += 1; continue }
            var j = i
            while j < out.count, out[j] == nil { j += 1 }
            let leftIdx  = i - 1
            let rightIdx = j
            let leftVal  = leftIdx  >= 0          ? out[leftIdx]  : nil
            let rightVal = rightIdx < out.count   ? out[rightIdx] : nil
            if (j - i) <= maxGap, let lv = leftVal, let rv = rightVal {
                let span = rightIdx - leftIdx
                for k in i..<j {
                    let frac = Double(k - leftIdx) / Double(span)
                    out[k] = lv + (rv - lv) * frac
                }
            }
            i = j
        }
        return out
    }

    private static func rollingMedian(_ s: [Double?], win: Int) -> [Double?] {
        let half = win / 2
        return (0..<s.count).map { i in
            let lo = max(0, i - half), hi = min(s.count - 1, i + half)
            let window = (lo...hi).compactMap { s[$0] }
            guard !window.isEmpty else { return nil }
            let sorted = window.sorted()
            return sorted[sorted.count / 2]
        }
    }
    private static func rollingMean(_ s: [Double?], win: Int) -> [Double?] {
        let half = win / 2
        return (0..<s.count).map { i in
            let lo = max(0, i - half), hi = min(s.count - 1, i + half)
            let window = (lo...hi).compactMap { s[$0] }
            guard !window.isEmpty else { return nil }
            return window.reduce(0, +) / Double(window.count)
        }
    }

    private static func argmin(_ s: [Double?], from: Int, to: Int) -> Int? {
        var best: (idx: Int, val: Double)?
        for i in from..<to {
            if let v = s[i], best == nil || v < best!.val { best = (i, v) }
        }
        return best?.idx
    }

    /// Find indices of local maxima with prominence/distance thresholds.
    private static func findPeaks(_ s: [Double?], minDistanceFrames: Int, minProminence: Double) -> [Int] {
        var candidates: [(idx: Int, val: Double)] = []
        for i in 1..<s.count - 1 {
            guard let v = s[i], let l = s[i-1], let r = s[i+1] else { continue }
            if v > l, v >= r { candidates.append((i, v)) }
        }
        let window = 2 * minDistanceFrames
        let kept = candidates.filter { c in
            let lo = max(0, c.idx - window), hi = min(s.count - 1, c.idx + window)
            var leftMin = Double.infinity, rightMin = Double.infinity
            for k in lo..<c.idx           { if let v = s[k], v < leftMin  { leftMin  = v } }
            for k in (c.idx+1)...hi       { if let v = s[k], v < rightMin { rightMin = v } }
            return (c.val - max(leftMin, rightMin)) >= minProminence
        }
        let sorted = kept.sorted { $0.val > $1.val }
        var selected: [Int] = []
        for c in sorted {
            if selected.allSatisfy({ abs($0 - c.idx) >= minDistanceFrames }) {
                selected.append(c.idx)
            }
        }
        return selected.sorted()
    }

    // MARK: - per-rep math

    private static func leanDeg(_ hx: Double?, _ hy: Double?, _ nx: Double?, _ ny: Double?) -> Double? {
        guard let hx, let hy, let nx, let ny else { return nil }
        let dy = hy - ny, dx = hx - nx
        return atan2(abs(dx), max(dy, 1e-3)) * 180 / .pi
    }

    private static func travelRatio(_ kxBottom: Double?, _ kxTop: Double?,
                                    _ kyTop: Double?, _ hyTop: Double?) -> Double? {
        guard let kxBottom, let kxTop, let kyTop, let hyTop,
              (kyTop - hyTop) > 0 else { return nil }
        return abs(kxBottom - kxTop) / (kyTop - hyTop)
    }

    private static func depthLabel(_ metric: Double, exercise: Exercise) -> DepthLabel {
        if metric > exercise.depthGoodPx      { return .good }
        if metric >= exercise.depthParallelPx { return .atParallel }
        return .shallow
    }

    private static func detectionRate(frames: [PoseFrame]) -> Double {
        Double(frames.filter { !$0.joints.isEmpty }.count) / Double(max(frames.count, 1))
    }

    private static func makeCameraNote(frames: [PoseFrame], reps: [Rep],
                                        exercise: Exercise, detectedRate: Double) -> String? {
        let pct = Int(detectedRate * 100)

        // ── Very poor detection ──────────────────────────────────────────────
        if detectedRate < detectionVeryPoor {
            return "Body barely detected (\(pct)%). Check: \(exercise.cameraHint.lowercased()), fully side-on, no obstructions."
        }

        // ── Partial detection — diagnose which body region is missing ────────
        if detectedRate < detectionPartial {
            let total     = Double(max(frames.count, 1))
            let headRate  = Double(frames.filter { $0.confidence(.neck) > jointSeenConfidence }.count) / total
            let ankleRate = Double(frames.filter {
                $0.confidence(.lAnkle) > jointSeenConfidence || $0.confidence(.rAnkle) > jointSeenConfidence
            }.count) / total
            let wristRate = Double(frames.filter {
                $0.confidence(.lWrist) > jointSeenConfidence || $0.confidence(.rWrist) > jointSeenConfidence
            }.count) / total

            if headRate < regionVisibleMin {
                return "Upper body often out of frame (\(pct)% detected). Lower the camera or move further back so your head and shoulders are visible."
            }
            if ankleRate < regionVisibleMin, exercise.repSignalJoint == .hip {
                return "Lower body often cut off (\(pct)% detected). Raise the camera or step further back so your feet are visible."
            }
            if wristRate < regionVisibleMin, exercise.repSignalJoint == .wrist {
                return "Arms often out of frame (\(pct)% detected). Ensure your full arm arc is visible — \(exercise.cameraHint.lowercased())."
            }
            return "Partial body detection (\(pct)%). Stay fully side-on and ensure nothing blocks the view."
        }

        // ── Good detection but no reps counted ──────────────────────────────
        if reps.isEmpty {
            let hint = exercise.repSignalJoint == .hip
                ? "hip height, ~8 ft, fully side-on"
                : "bench height, ~6 ft, fully side-on"
            return "Body detected well but no reps counted. Check: camera at \(hint). Motions at the very start/end of the clip (e.g. picking up weights) may sometimes be counted — try to start recording once you're already in position."
        }

        return nil
    }
}
