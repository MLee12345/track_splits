import SwiftUI

struct RunnerTimer: Identifiable, Equatable {
    let id: UUID
    var name: String
    var elapsedBeforeStart: TimeInterval
    var startedAt: Date?
    var workout: WorkoutSettings

    init(
        id: UUID = UUID(),
        name: String,
        elapsedBeforeStart: TimeInterval = 0,
        startedAt: Date? = nil,
        workout: WorkoutSettings = WorkoutSettings()
    ) {
        self.id = id
        self.name = name
        self.elapsedBeforeStart = elapsedBeforeStart
        self.startedAt = startedAt
        self.workout = workout
    }

    var isRunning: Bool {
        startedAt != nil
    }

    func elapsed(at now: Date) -> TimeInterval {
        guard let startedAt else {
            return elapsedBeforeStart
        }

        return elapsedBeforeStart + now.timeIntervalSince(startedAt)
    }

    mutating func toggle(at now: Date) {
        if let startedAt {
            elapsedBeforeStart += now.timeIntervalSince(startedAt)
            self.startedAt = nil
        } else {
            startedAt = now
        }
    }

    mutating func reset(at now: Date) {
        elapsedBeforeStart = 0

        if isRunning {
            startedAt = now
        }
    }
}

struct WorkoutSettings: Equatable {
    var workoutType = "Intervals"
    var target = "5K"
    var repetitions = 6
    var workDistance = "400 m"
    var targetPace = "Current VDOT"
    var recovery = "200 m jog"
    var effort = "Threshold"
    var notes = ""
}

struct ContentView: View {
    @State private var runners: [RunnerTimer] = (1...4).map { RunnerTimer(name: "Runner \($0)") }
    @State private var selectedRunnerID: UUID?
    @State private var draggedRunnerID: UUID?
    @State private var dragTranslation: CGFloat = 0
    @FocusState private var focusedRunnerID: UUID?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 60.0)) { timeline in
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    header

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach($runners) { $runner in
                                RunnerCard(
                                    runner: $runner,
                                    now: timeline.date,
                                    dragOffset: dragOffset(for: runner.id),
                                    isDragging: draggedRunnerID == runner.id,
                                    onDragChanged: { translation in
                                        updateRunnerDrag(id: runner.id, translation: translation)
                                    },
                                    onDragEnded: {
                                        endRunnerDrag()
                                    },
                                    onOpenNotes: {
                                        commitRunnerName()
                                        selectedRunnerID = runner.id
                                    },
                                    onDelete: {
                                        commitRunnerName()
                                        removeRunner(id: runner.id)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 104)
                    }
                    .scrollDismissesKeyboard(.interactively)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        commitRunnerName()
                    }
                }

                Button(action: {
                    commitRunnerName()
                    addRunner()
                }) {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .frame(width: 62, height: 62)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.softGreen))
                        .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 7)
                }
                .accessibilityLabel("Add runner")
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
            .onAppear {
                selectedRunnerID = nil
                focusedRunnerID = nil
                draggedRunnerID = nil
                dragTranslation = 0
            }
            .sheet(isPresented: workoutSheetIsPresented) {
                if let selectedRunnerBinding {
                    WorkoutDetailView(runner: selectedRunnerBinding)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            StopwatchLogo(size: 48)

            VStack(alignment: .leading, spacing: 3) {
                Text("TrackSplits")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("\(runners.count) \(runners.count == 1 ? "runner" : "runners")")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 18)
        .padding(.top, 14)
        .padding(.bottom, 10)
        .background(Color.black)
        .contentShape(Rectangle())
        .onTapGesture {
            commitRunnerName()
        }
    }

    private func commitRunnerName() {
        for index in runners.indices {
            let trimmedName = runners[index].name.trimmingCharacters(in: .whitespacesAndNewlines)
            runners[index].name = trimmedName.isEmpty ? "Runner \(index + 1)" : trimmedName
        }

        focusedRunnerID = nil
    }

    private func addRunner() {
        runners.append(RunnerTimer(name: nextDefaultRunnerName()))
    }

    private func removeRunner(id: UUID) {
        runners.removeAll { $0.id == id }
    }

    private func updateRunnerDrag(id: UUID, translation: CGFloat) {
        focusedRunnerID = nil

        if draggedRunnerID != id {
            draggedRunnerID = id
            dragTranslation = 0
        }

        dragTranslation = translation
    }

    private func endRunnerDrag() {
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.86)) {
            dragTranslation = 0
        }

        draggedRunnerID = nil
    }

    private func dragOffset(for id: UUID) -> CGFloat {
        if draggedRunnerID == id {
            return dragTranslation
        }

        return 0
    }

    private func nextDefaultRunnerName() -> String {
        var runnerNumber = 1

        while runners.contains(where: { $0.name == "Runner \(runnerNumber)" }) {
            runnerNumber += 1
        }

        return "Runner \(runnerNumber)"
    }

    private var selectedRunnerBinding: Binding<RunnerTimer>? {
        guard let selectedRunnerID,
              let selectedRunnerIndex = runners.firstIndex(where: { $0.id == selectedRunnerID }) else {
            return nil
        }

        return $runners[selectedRunnerIndex]
    }

    private var workoutSheetIsPresented: Binding<Bool> {
        Binding(
            get: { selectedRunnerID != nil },
            set: { isPresented in
                if !isPresented {
                    selectedRunnerID = nil
                }
            }
        )
    }
}

private struct StopwatchLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.softGreen, Color.softCyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.25), lineWidth: 1)
                )

            Image(systemName: "stopwatch.fill")
                .font(.system(size: size * 0.53, weight: .black))
                .foregroundStyle(.black.opacity(0.82))
                .shadow(color: .white.opacity(0.28), radius: 1, x: 0, y: 1)
        }
        .frame(width: size, height: size)
        .shadow(color: Color.softGreen.opacity(0.26), radius: 10, x: 0, y: 5)
        .accessibilityHidden(true)
    }
}

private extension Color {
    static let softGreen = Color(red: 0.44, green: 0.78, blue: 0.54)
    static let softRed = Color(red: 0.86, green: 0.38, blue: 0.38)
    static let softCyan = Color(red: 0.35, green: 0.77, blue: 0.86)
}

private struct CardMoveHandle: View {
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void

    var body: some View {
        VStack(spacing: 3) {
            ForEach(0..<3) { _ in
                Circle()
                    .fill(Color.gray.opacity(0.95))
                    .frame(width: 3.5, height: 3.5)
            }
        }
        .frame(width: 14, height: 50)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    onDragChanged(value.translation.height)
                }
                .onEnded { value in
                    _ = value
                    onDragEnded()
                }
        )
    }
}

private struct RunnerCard: View {
    @Binding var runner: RunnerTimer
    let now: Date
    let dragOffset: CGFloat
    let isDragging: Bool
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    let onOpenNotes: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            CardMoveHandle(
                onDragChanged: { translation in
                    onDragChanged(translation)
                },
                onDragEnded: {
                    onDragEnded()
                }
            )
                .accessibilityLabel("Card handle")

            Text(runner.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
                .frame(minWidth: 34, maxWidth: .infinity, minHeight: 50, alignment: .center)
                .layoutPriority(0)

            Text(formattedElapsed)
                .font(.system(size: 20, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(Color.white)
                .frame(width: 112, alignment: .leading)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: true, vertical: false)
                .layoutPriority(3)
                .accessibilityLabel("Elapsed time \(formattedElapsed)")

            Button(action: {
                runner.toggle(at: Date())
            }) {
                Text(runner.isRunning ? "Stop" : "Start")
                    .font(.system(size: 14, weight: .bold))
                    .frame(width: 49, height: 50)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(runner.isRunning ? Color.softRed : Color.softGreen)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(runner.isRunning ? "Stop \(runner.name)" : "Start \(runner.name)")

            Button(action: {
                runner.reset(at: Date())
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 33, height: 50)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset \(runner.name)")

            Button(role: .destructive, action: {
                onDelete()
            }) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 28, height: 50)
                    .foregroundStyle(.white.opacity(0.86))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(runner.name)")
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .offset(y: dragOffset)
        .zIndex(isDragging ? 1 : 0)
        .scaleEffect(isDragging ? 1.015 : 1)
        .shadow(color: .black.opacity(isDragging ? 0.28 : 0), radius: 10, x: 0, y: 6)
        .onTapGesture {
            onOpenNotes()
        }
        .animation(.easeInOut(duration: 0.18), value: runner.isRunning)
    }

    private var formattedElapsed: String {
        let elapsed = max(0, runner.elapsed(at: now))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let hundredths = Int((elapsed * 100).rounded(.down)) % 100

        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}

private struct FocusUnderline: View {
    let isFocused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.4, paused: !isFocused)) { timeline in
            Rectangle()
                .fill(Color.softGreen.opacity(underlineOpacity(at: timeline.date)))
                .frame(height: 2)
                .opacity(isFocused ? 1 : 0)
                .animation(.easeInOut(duration: 0.15), value: isFocused)
        }
    }

    private func underlineOpacity(at date: Date) -> Double {
        guard isFocused else {
            return 0
        }

        return sin(date.timeIntervalSinceReferenceDate * 6) > 0 ? 0.95 : 0.2
    }
}

private struct WorkoutDetailView: View {
    @Binding var runner: RunnerTimer
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Runner") {
                    TextEditor(text: $runner.name)
                        .font(.body)
                        .textInputAutocapitalization(.never)
                        .frame(minHeight: 28)
                        .scrollContentBackground(.hidden)
                    Text("Elapsed \(formattedElapsed)")
                        .font(.system(.headline, design: .monospaced))
                        .monospacedDigit()
                }

                Section("Notes") {
                    TextField("Workout details, timing cues, splits, etc.", text: $runner.workout.notes, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .lineLimit(6...12)
                }
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var formattedElapsed: String {
        let elapsed = runner.elapsed(at: Date())
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let hundredths = Int((elapsed * 100).rounded(.down)) % 100

        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }
}

#Preview {
    ContentView()
}
