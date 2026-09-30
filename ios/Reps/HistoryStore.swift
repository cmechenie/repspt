import Foundation

/// Persists the list of completed sets to UserDefaults as JSON.
/// Injected as a @StateObject in RootView and passed down where needed.
@MainActor
final class HistoryStore: ObservableObject {
    @Published private(set) var sets: [SetResult] = []

    private static let key = "reps.history.v2"  // bumped: SetResult schema changed (exerciseId/exerciseName)

    init() { load() }

    func append(_ result: SetResult) {
        sets.insert(result, at: 0)   // newest first
        persist()
    }

    func delete(at offsets: IndexSet) {
        // Remove the video file from disk before dropping the history entry.
        // Silently ignores missing files (old temp-dir URLs that iOS already cleaned up).
        for i in offsets {
            try? FileManager.default.removeItem(at: sets[i].videoURL)
        }
        sets.remove(atOffsets: offsets)
        persist()
    }

    /// Delete a single set by ID — safe to use when the displayed list is
    /// filtered (e.g. the free-tier 30-day window), where IndexSet offsets
    /// into the visible list don't map 1-to-1 to offsets in `sets`.
    func delete(id: UUID) {
        guard let i = sets.firstIndex(where: { $0.id == id }) else { return }
        try? FileManager.default.removeItem(at: sets[i].videoURL)
        sets.remove(at: i)
        persist()
    }

    // MARK: - private

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.key),
              let decoded = try? JSONDecoder().decode([SetResult].self, from: data)
        else { return }
        sets = decoded
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(sets) else { return }
        UserDefaults.standard.set(data, forKey: Self.key)
    }
}
