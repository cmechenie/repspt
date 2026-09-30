import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: HistoryStore
    @Environment(EntitlementManager.self) private var entitlements

    @State private var selected: SetResult?
    @State private var showPaywall = false

    // MARK: - Free-tier filter

    private var cutoffDate: Date {
        Calendar.current.date(byAdding: .day, value: -30, to: .now) ?? .now
    }

    /// Sets visible to the current user (all for Pro; last 30 days for free).
    private var visibleSets: [SetResult] {
        guard !entitlements.isPro else { return store.sets }
        return store.sets.filter { $0.date >= cutoffDate }
    }

    /// How many sets are hidden behind the Pro gate.
    private var hiddenCount: Int {
        entitlements.isPro ? 0 : store.sets.count - visibleSets.count
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            Group {
                if store.sets.isEmpty {
                    emptyState
                } else {
                    setList
                }
            }
            .navigationTitle("History")
            .background(Color.black.ignoresSafeArea())
            .toolbarBackground(Color.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
        }
        .sheet(item: $selected) { s in
            ResultsView(result: s, onDismiss: { selected = nil })
        }
        .sheet(isPresented: $showPaywall) {
            ProPaywallView()
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "figure.strengthtraining.traditional")
                .font(.system(size: 52))
                .foregroundStyle(.white.opacity(0.25))
            Text("No sets recorded yet")
                .foregroundStyle(.white.opacity(0.4))
                .font(.headline)
            Text("Complete a set and the scorecard will appear here.")
                .foregroundStyle(.white.opacity(0.25))
                .font(.caption)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var setList: some View {
        List {
            ForEach(visibleSets) { set in
                Button { selected = set } label: {
                    SetRow(set: set)
                }
                .listRowBackground(Color.white.opacity(0.05))
                .listRowSeparatorTint(.white.opacity(0.1))
            }
            .onDelete { offsets in
                // Map offsets in the visible list back to IDs so deletes work
                // correctly when the list is filtered (free tier).
                for i in offsets {
                    store.delete(id: visibleSets[i].id)
                }
            }

            if hiddenCount > 0 {
                HistoryUpgradePrompt(hiddenCount: hiddenCount) {
                    showPaywall = true
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 0, trailing: 0))
            }
        }
        .listStyle(.plain)
        .background(Color.black)
        .scrollContentBackground(.hidden)
        .toolbar {
            EditButton()
                .foregroundStyle(.white)
        }
    }
}

// MARK: - Row

private struct SetRow: View {
    let set: SetResult

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    private var hasVideo: Bool {
        FileManager.default.fileExists(atPath: set.videoURL.path)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(set.exerciseName)
                    .font(.headline)
                    .foregroundStyle(.white)
                if hasVideo {
                    Image(systemName: "video.fill")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                Text(Self.dateFormatter.string(from: set.date))
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
            }
            HStack(spacing: 10) {
                Text("\(set.reps.count) reps · \(Int(set.durationS))s")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                Spacer()
                gradeBadge("\(set.ok) good", color: .green)
                if set.borderline > 0 { gradeBadge("\(set.borderline) ok", color: .yellow) }
                if set.bad > 0        { gradeBadge("\(set.bad) bad",  color: .red) }
            }
        }
        .padding(.vertical, 6)
    }

    private func gradeBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption.bold())
            .padding(.horizontal, 8).padding(.vertical, 2)
            .background(color.opacity(0.2))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}

// MARK: - Upgrade prompt

private struct HistoryUpgradePrompt: View {
    let hiddenCount: Int
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.4))
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(hiddenCount) older set\(hiddenCount == 1 ? "" : "s") hidden")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white.opacity(0.7))
                    Text("Pro shows your full history")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.35))
                }
                Spacer()
                Button(action: onUpgrade) {
                    Text("Unlock Pro")
                        .font(.caption.bold())
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                        .overlay(Capsule().strokeBorder(Color.white.opacity(0.15), lineWidth: 1))
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1))
        }
        .padding(.horizontal, 16)
    }
}
