import SwiftUI
import UniformTypeIdentifiers

// =====================================================================
// ScorecardExport — Transferable wrapper that gives the PNG a proper
// filename (e.g. RepsPT_Hammer_Curl_2026-05-15.png) instead of the
// ugly system-generated .com.apple.Foundation.NSItemProvider.xxx.png
// =====================================================================

struct ScorecardExport: Transferable {
    let pngData: Data
    let filename: String   // e.g. "RepsPT_Hammer_Curl_2026-05-15.png"

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .png) { item in
            item.pngData
        }
        .suggestedFileName { item in item.filename }
    }
}

// =====================================================================
// ScorecardShareCard
//
// A fixed-width (390 pt) view rendered to a UIImage by ImageRenderer
// and shared via ShareLink in ResultsView.
//
// Self-contained: duplicates the small formatting helpers from
// ResultsView so it has no dependency on the live view hierarchy.
// =====================================================================

struct ScorecardShareCard: View {
    let result: SetResult

    // Card colour constants
    private let bg   = Color(red: 0.07, green: 0.07, blue: 0.07)
    private let card = Color(red: 0.11, green: 0.11, blue: 0.11)

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider().background(Color.white.opacity(0.08))
            stats
            if !result.reps.isEmpty {
                Divider().background(Color.white.opacity(0.08))
                cues
                Divider().background(Color.white.opacity(0.08))
                repRows
            }
            Divider().background(Color.white.opacity(0.08))
            footer
        }
        .background(bg)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(RoundedRectangle(cornerRadius: 20)
            .strokeBorder(Color.white.opacity(0.07), lineWidth: 1))
        .padding(16)
        .background(bg)
        .frame(width: 390)
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.title3.bold())
                .foregroundStyle(.green)
            Text("RepsPT")
                .font(.headline.bold())
                .foregroundStyle(.white)
            Spacer()
            Text(formattedDate)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.35))
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Stats block

    private var stats: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.exerciseName.uppercased())
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .kerning(1.2)

            HStack(alignment: .lastTextBaseline, spacing: 6) {
                Text("\(result.reps.count)")
                    .font(.system(size: 56, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("reps")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.5))
            }

            HStack(spacing: 8) {
                gradeBadge("\(result.ok) good",        color: .green)
                if result.borderline > 0 {
                    gradeBadge("\(result.borderline) ok", color: .yellow)
                }
                if result.bad > 0 {
                    gradeBadge("\(result.bad) bad",    color: .red)
                }
                Spacer()
                Text("\(Int(result.durationS))s")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }

    // MARK: - Coaching cues

    private var cues: some View {
        let issueCounts: [(Issue, Int)] = Issue.allCases.compactMap { issue in
            let n = result.reps.filter { $0.issues.contains(issue) }.count
            return n > 0 ? (issue, n) : nil
        }
        return VStack(alignment: .leading, spacing: 8) {
            if issueCounts.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text("Solid set — no issues flagged.")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            } else {
                Text("Coaching cues")
                    .font(.caption.bold())
                    .foregroundStyle(.white.opacity(0.4))
                    .kerning(1.2)
                    .textCase(.uppercase)
                ForEach(issueCounts, id: \.0) { (issue, count) in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 6, height: 6)
                        Text(cueTitle(issue))
                            .font(.subheadline.bold())
                            .foregroundStyle(.white)
                        Text("(\(count)×)")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.45))
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Per-rep rows (capped at 8 to keep card height reasonable)

    private var repRows: some View {
        let shown = Array(result.reps.prefix(8))
        let overflow = result.reps.count - shown.count
        return VStack(alignment: .leading, spacing: 0) {
            Text("Per-rep detail")
                .font(.caption.bold())
                .foregroundStyle(.white.opacity(0.4))
                .kerning(1.2)
                .textCase(.uppercase)
                .padding(.bottom, 8)
            ForEach(shown) { rep in
                HStack(spacing: 10) {
                    Text("#\(rep.index)")
                        .font(.caption.bold())
                        .foregroundStyle(gradeColor(rep.grade))
                        .frame(width: 26, alignment: .leading)
                    Text(repDetailText(rep))
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.75))
                    Spacer()
                    if !rep.issues.isEmpty {
                        Text(rep.issues.map { cueTitle($0) }.joined(separator: " · "))
                            .font(.caption2)
                            .foregroundStyle(gradeColor(rep.grade).opacity(0.75))
                    }
                }
                .padding(.vertical, 4)
                if rep.index < shown.last?.index ?? 0 {
                    Divider().background(Color.white.opacity(0.06))
                }
            }
            if overflow > 0 {
                Text("+ \(overflow) more rep\(overflow == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.3))
                    .padding(.top, 4)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }

    // MARK: - Footer

    private var footer: some View {
        Text("Recorded & analyzed with RepsPT")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.25))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }

    // MARK: - Helpers (self-contained copies of ResultsView formatting logic)

    private var isPressingExercise: Bool {
        result.exerciseDefinition?.repSignalJoint == .wrist
    }
    private var isRaiseExercise: Bool {
        result.exerciseDefinition?.id == "lateral_raise"
    }
    private var isCableCrunchExercise: Bool {
        result.exerciseDefinition?.id == "cable_crunch"
    }
    private var isDepthGradingMeaningless: Bool {
        let ids: Set<String> = ["push_up", "pull_up", "ab_wheel", "hanging_leg_raise"]
        return ids.contains(result.exerciseDefinition?.id ?? "")
    }
    private var showLeanAngle: Bool {
        !isPressingExercise && !isRaiseExercise && !isDepthGradingMeaningless
    }

    private func gradeColor(_ g: Grade) -> Color {
        switch g { case .good: return .green; case .borderline: return .yellow; case .bad: return .red }
    }

    private func romLabel(_ depth: DepthLabel) -> String {
        switch depth {
        case .good:       return isRaiseExercise ? "Full raise" : isPressingExercise ? "Full ROM" : "Full depth"
        case .atParallel: return isRaiseExercise ? "Partial raise" : "At parallel"
        case .shallow:    return isRaiseExercise ? "Too low" : "Shallow"
        }
    }

    private func repDetailText(_ rep: Rep) -> String {
        let tempo = "tempo \(f(rep.eccentricS))/\(f(rep.concentricS))s"
        if isDepthGradingMeaningless { return tempo }
        if showLeanAngle { return "\(romLabel(rep.depth)) · lean \(Int(rep.torsoLeanDeg))° · \(tempo)" }
        return "\(romLabel(rep.depth)) · \(tempo)"
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

    private func gradeBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 10).padding(.vertical, 3)
            .background(color.opacity(0.18))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private func f(_ s: Double) -> String { String(format: "%.1f", s) }

    private var formattedDate: String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        fmt.timeStyle = .none
        return fmt.string(from: result.date)
    }
}
