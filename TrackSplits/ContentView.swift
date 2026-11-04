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
                                    focusedRunnerID: $focusedRunnerID,
                                    onCommitName: commitRunnerName,
                                    onMoveUp: { moveRunner(id: runner.id, offset: -1) },
                                    onMoveDown: { moveRunner(id: runner.id, offset: 1) },
                                    onOpenWorkout: {
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

    private func moveRunner(id: UUID, offset: Int) {
        guard let currentIndex = runners.firstIndex(where: { $0.id == id }) else {
            return
        }

        let newIndex = currentIndex + offset
        guard runners.indices.contains(newIndex) else {
            return
        }

        runners.swapAt(currentIndex, newIndex)
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
            ForEach(0..<3) { index in
                let offset = CGFloat(index - 1) * size * 0.18
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
                            .stroke(Color.white.opacity(0.24), lineWidth: 1)
                    )
                    .overlay(
                        ClockHands()
                            .stroke(Color.black.opacity(0.72), style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .padding(size * 0.22)
                    )
                    .frame(width: size * 0.62, height: size * 0.62)
                    .offset(x: offset, y: CGFloat(index % 2) * size * 0.08)
                    .shadow(color: Color.softGreen.opacity(0.20), radius: 7, x: 0, y: 4)
            }

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.78))
                .frame(width: size * 0.28, height: size * 0.08)
                .offset(y: -size * 0.34)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

private struct ClockHands: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)

        path.move(to: center)
        path.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
        path.move(to: center)
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY + rect.height * 0.22))

        return path
    }
}

private extension Color {
    static let softGreen = Color(red: 0.44, green: 0.78, blue: 0.54)
    static let softRed = Color(red: 0.86, green: 0.38, blue: 0.38)
    static let softCyan = Color(red: 0.35, green: 0.77, blue: 0.86)
}

private struct RunnerCard: View {
    @Binding var runner: RunnerTimer
    let now: Date
    var focusedRunnerID: FocusState<UUID?>.Binding
    let onCommitName: () -> Void
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onOpenWorkout: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            Menu {
                Button("Workout Settings", systemImage: "figure.run") {
                    focusedRunnerID.wrappedValue = nil
                    onOpenWorkout()
                }
                Button("Move Up", systemImage: "arrow.up") {
                    focusedRunnerID.wrappedValue = nil
                    onMoveUp()
                }
                Button("Move Down", systemImage: "arrow.down") {
                    focusedRunnerID.wrappedValue = nil
                    onMoveDown()
                }
            } label: {
                Image(systemName: "ellipsis.vertical")
                    .font(.system(size: 18, weight: .bold))
                    .frame(width: 24, height: 50)
                    .foregroundStyle(.white.opacity(0.72))
            }
            .accessibilityLabel("Arrange \(runner.name)")

            VStack(alignment: .leading, spacing: 4) {
                TextField("Runner", text: nameBinding, axis: .vertical)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .focused(focusedRunnerID, equals: runner.id)
                    .onSubmit(onCommitName)
                    .lineLimit(1...4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(minWidth: 34, maxWidth: .infinity, alignment: .leading)

                FocusUnderline(isFocused: focusedRunnerID.wrappedValue == runner.id)
            }
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
                focusedRunnerID.wrappedValue = nil
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
                focusedRunnerID.wrappedValue = nil
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
                focusedRunnerID.wrappedValue = nil
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
        .onTapGesture {
            guard focusedRunnerID.wrappedValue != runner.id else {
                return
            }

            onOpenWorkout()
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

    private var nameBinding: Binding<String> {
        Binding(
            get: { runner.name },
            set: { newValue in
                guard newValue.contains("\n") else {
                    runner.name = newValue
                    return
                }

                runner.name = newValue
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                onCommitName()
            }
        )
    }
}

private struct FocusUnderline: View {
    let isFocused: Bool

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.4, paused: !isFocused)) { timeline in
            Rectangle()
                .fill(Color.white.opacity(underlineOpacity(at: timeline.date)))
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

    private let workoutTypes = ["Intervals", "Tempo", "Easy", "Long Run", "Race"]
    private let efforts = ["Easy", "Marathon", "Threshold", "Interval", "Repetition"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Runner") {
                    TextField("Name", text: $runner.name)
                    Text("Elapsed \(formattedElapsed)")
                        .font(.system(.headline, design: .monospaced))
                        .monospacedDigit()
                }

                Section("Workout") {
                    Picker("Type", selection: $runner.workout.workoutType) {
                        ForEach(workoutTypes, id: \.self) { workoutType in
                            Text(workoutType)
                        }
                    }

                    TextField("Target", text: $runner.workout.target)
                    Stepper("Reps: \(runner.workout.repetitions)", value: $runner.workout.repetitions, in: 1...40)
                    TextField("Work", text: $runner.workout.workDistance)
                    TextField("Recovery", text: $runner.workout.recovery)
                }

                Section("Pace Guidance") {
                    Picker("Effort", selection: $runner.workout.effort) {
                        ForEach(efforts, id: \.self) { effort in
                            Text(effort)
                        }
                    }

                    TextField("Target Pace", text: $runner.workout.targetPace)
                    Text("Coach-facing setup inspired by pace calculator workflows: choose the workout type, set reps and recovery, then keep target pace and effort visible with the runner.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Notes") {
                    TextField("Workout notes", text: $runner.workout.notes, axis: .vertical)
                        .lineLimit(3...6)
                }
            }
            .navigationTitle(runner.name)
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
