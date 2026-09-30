import SwiftUI

// =====================================================================
// Two-level exercise picker:
//   Sheet → Category grid → Exercise grid within category
//
// Adding a new category: add it to ExerciseCategory + Exercise.all.
// Adding a new exercise: add it to Exercise.all with the right category.
// No changes needed here.
//
// TODO: Replace static SF Symbol icons with short looping GIFs / video
// previews showing correct form for each exercise. Tapping an exercise
// card should open a "Learn" screen (technique cues + demo) BEFORE the
// user starts recording — mirroring how a PT works: show first, grade
// second. This also sets the user's expectation for what "good" looks
// like before they attempt the set.
// Consider: store demo assets in the app bundle (keeps it offline) or
// stream from a CDN if bundle size becomes a concern.
// =====================================================================
struct ExercisePickerView: View {
    @Binding var selected: Exercise
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            CategoryGridView(selected: $selected, onDismiss: { dismiss() })
                .navigationTitle("Select Exercise")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.white)
                    }
                }
                .toolbarBackground(Color.black, for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .toolbarColorScheme(.dark, for: .navigationBar)
        }
    }
}

// MARK: - Category grid

private struct CategoryGridView: View {
    @Binding var selected: Exercise
    let onDismiss: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ExerciseCategory.allCases) { category in
                    NavigationLink {
                        ExerciseGridView(
                            category: category,
                            selected: $selected,
                            onDismiss: onDismiss
                        )
                    } label: {
                        CategoryCard(
                            category: category,
                            isCurrentCategory: category == selected.category
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(!category.hasAvailableExercises)
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
    }
}

// MARK: - Exercise grid within a category

private struct ExerciseGridView: View {
    let category: ExerciseCategory
    @Binding var selected: Exercise
    let onDismiss: () -> Void

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(category.exercises.filter { $0.isAvailable }) { exercise in
                    ExerciseCard(exercise: exercise, isSelected: exercise.id == selected.id)
                        .onTapGesture {
                            selected = exercise
                            onDismiss()
                        }
                }
            }
            .padding()
        }
        .background(Color.black.ignoresSafeArea())
        .navigationTitle(category.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(Color.black, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
    }
}

// MARK: - Category card

private struct CategoryCard: View {
    let category: ExerciseCategory
    let isCurrentCategory: Bool

    var body: some View {
        let available = category.hasAvailableExercises
        VStack(spacing: 10) {
            Image(systemName: category.sfSymbol)
                .font(.system(size: 32))
                .foregroundStyle(isCurrentCategory ? .black : .white)
            Text(category.displayName)
                .font(.subheadline.bold())
                .foregroundStyle(isCurrentCategory ? .black : .white)
            Text(available
                 ? "\(category.availableCount) exercise\(category.availableCount == 1 ? "" : "s")"
                 : "Coming soon")
                .font(.caption2)
                .foregroundStyle(
                    (isCurrentCategory ? Color.black : Color.white).opacity(0.55)
                )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .padding(.horizontal, 10)
        .background(
            isCurrentCategory
                ? Color.white
                : Color.white.opacity(available ? 0.08 : 0.03)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isCurrentCategory
                        ? Color.white
                        : Color.white.opacity(available ? 0.12 : 0.05),
                    lineWidth: 1
                )
        )
        .opacity(available ? 1.0 : 0.45)
    }
}

// MARK: - Exercise card

private struct ExerciseCard: View {
    let exercise: Exercise
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: exercise.sfSymbol)
                .font(.system(size: 30))
                .foregroundStyle(isSelected ? .black : .white)
            Text(exercise.name)
                .font(.subheadline.bold())
                .foregroundStyle(isSelected ? .black : .white)
                .multilineTextAlignment(.center)
            Text(exercise.description)
                .font(.caption2)
                .foregroundStyle(
                    (isSelected ? Color.black : Color.white).opacity(0.55)
                )
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .padding(.horizontal, 10)
        .background(
            isSelected
                ? Color.white
                : Color.white.opacity(0.07)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    isSelected
                        ? Color.white
                        : Color.white.opacity(0.12),
                    lineWidth: 1
                )
        )
    }
}
