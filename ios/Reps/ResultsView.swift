import SwiftUI
import AVKit

// =====================================================================
// Results screen
// =====================================================================
struct ResultsView: View {
    let result: SetResult
    let onDismiss: () -> Void

    /// Video player — nil until startPlayer() confirms the file exists on disk.
    @State private var player: AVPlayer? = nil

    /// Pre-rendered scorecard export for ShareLink. Nil until onAppear fires.
    @State private var scorecardExport: ScorecardExport? = nil
    /// Thumbnail used in the SharePreview title card.
    @State private var scorecardPreview: Image? = nil

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // ── Video playback ──────────────────────────────────────
                    Group {
                        if let player {
                            VideoPlayer(player: player)
                                .frame(height: 260)
                        } else {
                            // Placeholder — visible until player loads or if
                            // the file is missing. Check Xcode console for why.
                            ZStack {
                                Color.black
                                VStack(spacing: 8) {
                                    Image(systemName: "video.slash")
                                        .font(.title2)
                                        .foregroundStyle(.white.opacity(0.3))
                                    Text("Video unavailable")
                                        .font(.caption)
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                            .frame(height: 260)
                        }
                    }

                    // ── Scorecard ───────────────────────────────────────────
                    VStack(alignment: .leading, spacing: 20) {
                        summaryHeader
                        if let note = result.cameraNote {
                            cameraNoteCard(note)
                        }
                        if !result.reps.isEmpty {
                            cuesSection
                            Divider().background(.white.opacity(0.2))
                            repList
                        } else {
                            Text("No reps detected.")
                                .foregroundStyle(.white.opacity(0.7))
                                .padding()
                        }
                    }
                    .padding()
                }
            }
            .background(Color.black.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    // Share menu — always visible; individual items appear
                    // only when the relevant asset exists.
                    Menu {
                        if let export = scorecardExport {
                            ShareLink(
                                item: export,
                                preview: SharePreview(
                                    "\(result.exerciseName) · \(result.reps.count) reps",
                                    image: scorecardPreview ?? Image(systemName: "chart.bar.doc.horizontal")
                                )
                            ) {
                                Label("Share Scorecard", systemImage: "chart.bar.doc.horizontal")
                            }
                        }
                        if FileManager.default.fileExists(atPath: result.videoURL.path) {
                            ShareLink(item: result.videoURL) {
                                Label("Share Video", systemImage: "video.badge.plus")
                            }
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(.white)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { onDismiss() }
                        .foregroundStyle(.white)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        // Lifecycle on NavigationStack, not the inner ScrollView — avoids
        // spurious onDisappear/onAppear from iOS 17 scroll view transitions
        // (e.g. when presented as a sheet from HistoryView) that would nil
        // the player while the view is still visible.
        .onAppear {
            startPlayer()
            renderCard()
        }
        .onDisappear { stopPlayer() }
    }

    // MARK: - Player lifecycle

    private func startPlayer() {
        let url = result.videoURL
        print("🎥 videoURL: \(url.path)")
        print("🎥 fileExists: \(FileManager.default.fileExists(atPath: url.path))")
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("🎥 file missing — player not started")
            return
        }
        let p = AVPlayer(url: url)
        p.play()
        player = p
        print("🎥 player started")
    }

    private func stopPlayer() {
        player?.pause()
        player = nil
    }

    /// Renders ScorecardShareCard to PNG at @3× scale.
    /// Produces a ScorecardExport (proper filename) + a preview Image.
    @MainActor
    private func renderCard() {
        let cardView = ScorecardShareCard(result: result)
            .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: cardView)
        renderer.scale = 3.0
        guard let uiImage = renderer.uiImage,
              let pngData = uiImage.pngData() else { return }

        // Filename: RepsPT_Hammer_Curl_2026-05-15.png
        let safeName = result.exerciseName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "_")
        let dateStr = ISO8601DateFormatter().string(from: result.date).prefix(10)
        let filename = "RepsPT_\(safeName)_\(dateStr).png"

        scorecardExport  = ScorecardExport(pngData: pngData, filename: filename)
        scorecardPreview = Image(uiImage: uiImage)
    }

    private var isPressingExercise: Bool {
        result.exerciseDefinition?.repSignalJoint == .wrist
    }

    /// True for raise-pattern exercises where "shallow" means the arm didn't
    /// reach high enough (not that weight didn't lower far enough).
    private var isRaiseExercise: Bool {
        result.exerciseDefinition?.id == "lateral_raise"
    }

    /// True for cable crunch — wrist signal but cue text differs from presses.
    private var isCableCrunchExercise: Bool {
        result.exerciseDefinition?.id == "cable_crunch"
    }

    /// Hip-signal exercises where the hip−knee depth metric is meaningless
    /// (body is horizontal, hanging, or rolling). Depth label is omitted from
    /// per-rep detail; only tempo is shown.
    private var isDepthGradingMeaningless: Bool {
        let ids: Set<String> = ["push_up", "pull_up", "ab_wheel", "hanging_leg_raise"]
        return ids.contains(result.exerciseDefinition?.id ?? "")
    }

    /// Lean angle is meaningful only for standing hip-signal exercises (squat
    /// family). Suppress it for pressing/curling, raise exercises, and the
    /// depth-disabled group (horizontal, hanging, or rolling body).
    private var showLeanAngle: Bool {
        !isPressingExercise && !isRaiseExercise && !isDepthGradingMeaningless
    }

    private var summaryHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(result.exerciseName)
                .font(.subheadline)
                .foregroundStyle(.white.opacity(0.55))
            Text("\(result.reps.count) reps").font(.largeTitle.bold())
                .foregroundStyle(.white)
            HStack(spacing: 16) {
                badge("\(result.ok) good", color: .green)
                badge("\(result.borderline) borderline", color: .yellow)
                badge("\(result.bad) bad", color: .red)
            }
            HStack(spacing: 12) {
                Text("\(format(result.durationS))s · \(result.detectedSide.rawValue) side")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
                detectionBadge
            }
        }
    }

    private var detectionBadge: some View {
        let rate = result.poseDetectionRate
        let color: Color = rate >= 0.70 ? .green : rate >= 0.40 ? .yellow : .red
        let label = rate >= 0.70 ? "Good framing" : rate >= 0.40 ? "Partial framing" : "Poor framing"
        return HStack(spacing: 4) {
            Image(systemName: "camera.viewfinder")
            Text("\(label) · \(Int(rate * 100))%")
        }
        .font(.caption)
        .foregroundStyle(color)
    }

    private func badge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.25))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func cameraNoteCard(_ note: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.yellow)
            Text(note).foregroundStyle(.white).font(.callout)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cuesSection: some View {
        let issueCounts: [(Issue, Int)] = Issue.allCases.compactMap { issue in
            let n = result.reps.filter { $0.issues.contains(issue) }.count
            return n > 0 ? (issue, n) : nil
        }
        return VStack(alignment: .leading, spacing: 10) {
            if issueCounts.isEmpty {
                Text("Solid set. No issues flagged.")
                    .foregroundStyle(.green)
                    .font(.headline)
            } else {
                Text("Coaching cues").font(.headline).foregroundStyle(.white)
                ForEach(issueCounts, id: \.0) { (issue, count) in
                    HStack(alignment: .top, spacing: 10) {
                        Text("•").foregroundStyle(.white.opacity(0.6))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cueTitle(issue) + " (\(count)×)")
                                .font(.subheadline.bold())
                                .foregroundStyle(.white)
                            Text(cueBody(issue))
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }

    private var repList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per-rep detail").font(.headline).foregroundStyle(.white)
            ForEach(result.reps) { rep in
                HStack(spacing: 12) {
                    Text("#\(rep.index)")
                        .font(.headline)
                        .foregroundStyle(gradeColor(rep.grade))
                        .frame(width: 32, alignment: .leading)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(repDetailText(rep))
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                        if !rep.issues.isEmpty {
                            Text(rep.issues.map { cueTitle($0) }.joined(separator: " · "))
                                .font(.caption2)
                                .foregroundStyle(gradeColor(rep.grade).opacity(0.8))
                        }
                    }
                    Spacer()
                }
                .padding(.vertical, 6)
                Divider().background(.white.opacity(0.1))
            }
        }
    }

    // helpers
    private func format(_ s: Double) -> String { String(format: "%.1f", s) }

    /// Per-rep summary line. Suppresses lean for press/raise/push-up exercises
    /// where the angle is either irrelevant or misleading (push-ups read ~85–90°).
    private func repDetailText(_ rep: Rep) -> String {
        let tempo = "tempo \(format(rep.eccentricS))/\(format(rep.concentricS))s"
        // Depth-disabled exercises: only show tempo (hip−knee metric is meaningless).
        if isDepthGradingMeaningless { return tempo }
        if showLeanAngle {
            return "\(romLabel(rep.depth)) · lean \(Int(rep.torsoLeanDeg))° · \(tempo)"
        }
        return "\(romLabel(rep.depth)) · \(tempo)"
    }
    private func gradeColor(_ g: Grade) -> Color {
        switch g { case .good: return .green; case .borderline: return .yellow; case .bad: return .red }
    }

    /// Depth label that avoids the word "Good" (which conflicts visually with the
    /// overall rep grade). "Full depth" / "Full ROM" are unambiguous.
    /// Only called for exercises where depth grading is meaningful.
    /// Depth-disabled exercises (push-up, pull-up, ab wheel, hanging leg raise)
    /// are handled by isDepthGradingMeaningless in repDetailText — they never
    /// reach this function.
    private func romLabel(_ depth: DepthLabel) -> String {
        switch depth {
        case .good:       return isRaiseExercise ? "Full raise" : isPressingExercise ? "Full ROM" : "Full depth"
        case .atParallel: return isRaiseExercise ? "Partial raise" : "At parallel"
        case .shallow:    return isRaiseExercise ? "Too low" : "Shallow"
        }
    }
    private func cueTitle(_ i: Issue) -> String {
        switch i {
        case .shallow:
            if isCableCrunchExercise { return "Crunch deeper" }
            if isRaiseExercise       { return "Raise higher" }
            if isPressingExercise    { return "Full range of motion" }
            return "Drive deeper"
        case .forwardLean:   return "Stay tall"
        case .rushedDescent:
            if isCableCrunchExercise { return "Control the crunch" }
            return isPressingExercise ? "Control the lowering" : "Slow the descent"
        case .armsLow:       return "Keep the weight up"
        }
    }

    private func cueBody(_ i: Issue) -> String {
        switch i {
        case .shallow:
            if isCableCrunchExercise {
                return "Didn't crunch far enough. Pull the rope until your elbows meet your knees — feel the peak contraction."
            }
            if isRaiseExercise {
                return "Arm didn't reach shoulder height. Raise until parallel to the floor — control the whole arc."
            }
            if isPressingExercise {
                return "Weight didn't lower far enough. Let your elbows drop past the bench level each rep."
            }
            return "Hip didn't pass below the kneecap. Cue: knees out, butt back, sit between the legs."
        case .forwardLean:
            return "Torso collapsed forward at the bottom. Cue: chest up, dumbbell into the ribs."
        case .rushedDescent:
            if isCableCrunchExercise {
                return "Crunched too fast. Take 1–1.5 seconds to curl down — slow reps build more tension in the abs."
            }
            if isRaiseExercise {
                return "Arm dropped too fast. Take 1–2 seconds to lower it — resisting gravity keeps tension on the delts."
            }
            if isPressingExercise {
                return "Weight dropped too fast. Take 1.5–2.0 seconds to lower the dumbbells."
            }
            return "Took less than half a second to drop. Take 1.5–2.0 seconds on the way down."
        case .armsLow:
            return "Dumbbell dropped toward the hips instead of staying at chest height. Cue: elbows up, squeeze the weight into your chest throughout."
        }
    }
}
