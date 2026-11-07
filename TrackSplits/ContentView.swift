import SwiftUI

struct RunnerTimer: Identifiable, Equatable, Codable {
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

struct WorkoutSettings: Equatable, Codable {
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
    private let runnerRowStride: CGFloat = 82
    private static let runnersStorageKey = "tracksplits.ios.runners.v1"

    @State private var runners: [RunnerTimer] = ContentView.loadRunners()
    @State private var selectedRunnerID: UUID?
    @State private var draggedRunnerID: UUID?
    @State private var dragStartIndex: Int?
    @State private var dragTargetIndex: Int?
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
                                runnerCard(for: $runner, now: timeline.date)
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
                dragStartIndex = nil
                dragTargetIndex = nil
                dragTranslation = 0
            }
            .onChange(of: runners) { _, updatedRunners in
                Self.saveRunners(updatedRunners)
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

    @ViewBuilder
    private func runnerCard(for runner: Binding<RunnerTimer>, now: Date) -> some View {
        let runnerID = runner.wrappedValue.id

        RunnerCard(
            runner: runner,
            now: now,
            dragOffset: dragOffset(for: runnerID),
            isDragging: draggedRunnerID == runnerID,
            isExpanded: selectedRunnerID == runnerID,
            onDragChanged: { translation in
                updateRunnerDrag(id: runnerID, translation: translation)
            },
            onDragEnded: {
                endRunnerDrag()
            },
            onToggleNotes: {
                commitRunnerName()
                toggleNotes(for: runnerID)
            },
            onDelete: {
                commitRunnerName()
                removeRunner(id: runnerID)
            }
        )
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

        if selectedRunnerID == id {
            selectedRunnerID = nil
        }
    }

    private func toggleNotes(for id: UUID) {
        withAnimation(.interactiveSpring(response: 0.24, dampingFraction: 0.9)) {
            selectedRunnerID = selectedRunnerID == id ? nil : id
        }
    }

    private func updateRunnerDrag(id: UUID, translation: CGFloat) {
        focusedRunnerID = nil

        if draggedRunnerID != id {
            draggedRunnerID = id
            dragStartIndex = runners.firstIndex { $0.id == id }
            dragTargetIndex = dragStartIndex
            dragTranslation = 0
        }

        guard let startIndex = dragStartIndex else {
            return
        }

        dragTranslation = translation

        let proposedIndex = startIndex + Int((translation / runnerRowStride).rounded())
        let targetIndex = min(max(proposedIndex, 0), runners.count - 1)

        if targetIndex != dragTargetIndex {
            withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.9)) {
                dragTargetIndex = targetIndex
            }
        }
    }

    private func endRunnerDrag() {
        guard let draggedRunnerID,
              let startIndex = dragStartIndex,
              let targetIndex = dragTargetIndex else {
            resetDrag()
            return
        }

        var transaction = Transaction()
        transaction.disablesAnimations = true

        withTransaction(transaction) {
            if startIndex != targetIndex,
               let currentIndex = runners.firstIndex(where: { $0.id == draggedRunnerID }) {
                let runner = runners.remove(at: currentIndex)
                let insertionIndex = min(max(targetIndex, 0), runners.count)
                runners.insert(runner, at: insertionIndex)
            }

            resetDrag()
        }
    }

    private func resetDrag() {
        draggedRunnerID = nil
        dragStartIndex = nil
        dragTargetIndex = nil
        dragTranslation = 0
    }

    private func dragOffset(for id: UUID) -> CGFloat {
        guard let draggedRunnerID,
              let startIndex = dragStartIndex,
              let targetIndex = dragTargetIndex else {
            return 0
        }

        if draggedRunnerID == id {
            return 0
        }

        guard let index = runners.firstIndex(where: { $0.id == id }) else {
            return 0
        }

        if targetIndex > startIndex, index > startIndex, index <= targetIndex {
            return -runnerRowStride
        }

        if targetIndex < startIndex, index >= targetIndex, index < startIndex {
            return runnerRowStride
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

    private static func defaultRunners() -> [RunnerTimer] {
        (1...4).map { RunnerTimer(name: "Runner \($0)") }
    }

    private static func loadRunners() -> [RunnerTimer] {
        guard let data = UserDefaults.standard.data(forKey: runnersStorageKey) else {
            return defaultRunners()
        }

        do {
            let decodedRunners = try JSONDecoder().decode([RunnerTimer].self, from: data)
            return decodedRunners.isEmpty ? defaultRunners() : decodedRunners
        } catch {
            return defaultRunners()
        }
    }

    private static func saveRunners(_ runners: [RunnerTimer]) {
        guard let data = try? JSONEncoder().encode(runners) else {
            return
        }

        UserDefaults.standard.set(data, forKey: runnersStorageKey)
    }
}

private struct StopwatchLogo: View {
    let size: CGFloat

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { timeline in
            let angles = handAngles(for: timeline.date)

            ZStack {
                RoundedRectangle(cornerRadius: size * 0.13)
                    .fill(Color.white.opacity(0.92))
                    .frame(width: size * 0.38, height: size * 0.2)
                    .offset(y: -size * 0.36)

                RoundedRectangle(cornerRadius: size * 0.11)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: size * 0.17, height: size * 0.29)
                    .rotationEffect(.degrees(42))
                    .offset(x: size * 0.34, y: -size * 0.2)

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
                            .stroke(Color.white.opacity(0.25), lineWidth: size * 0.06)
                    )
                    .shadow(color: Color.softGreen.opacity(0.26), radius: 10, x: 0, y: 5)

                ClockHand(length: size * 0.19, width: size * 0.07)
                    .fill(Color.black.opacity(0.82))
                    .rotationEffect(.degrees(angles.hour))

                ClockHand(length: size * 0.25, width: size * 0.05)
                    .fill(Color.black.opacity(0.82))
                    .rotationEffect(.degrees(angles.minute))
            }
            .frame(width: size, height: size)
            .accessibilityHidden(true)
        }
    }

    private func handAngles(for date: Date) -> (hour: Double, minute: Double) {
        let components = Calendar.current.dateComponents([.hour, .minute, .second], from: date)
        let seconds = Double(components.second ?? 0)
        let minutes = Double(components.minute ?? 0) + seconds / 60
        let hours = Double((components.hour ?? 0) % 12) + minutes / 60

        return (hours * 30, minutes * 6)
    }
}

private struct ClockHand: Shape {
    let length: CGFloat
    let width: CGFloat

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        path.addRoundedRect(
            in: CGRect(
                x: center.x - width / 2,
                y: center.y - length,
                width: width,
                height: length
            ),
            cornerSize: CGSize(width: width / 2, height: width / 2)
        )
        return path
    }
}

private extension Color {
    static let softGreen = Color(red: 0.44, green: 0.78, blue: 0.54)
    static let softRed = Color(red: 0.86, green: 0.38, blue: 0.38)
    static let softCyan = Color(red: 0.35, green: 0.77, blue: 0.86)
}

private struct CardMoveHandle: View {
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
    }
}

private struct RunnerCard: View {
    @Binding var runner: RunnerTimer
    let now: Date
    let dragOffset: CGFloat
    let isDragging: Bool
    let isExpanded: Bool
    let onDragChanged: (CGFloat) -> Void
    let onDragEnded: () -> Void
    let onToggleNotes: () -> Void
    let onDelete: () -> Void
    @GestureState private var fingerOffset: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 3) {
                CardMoveHandle()
                    .accessibilityLabel("Card handle")
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .updating($fingerOffset) { value, state, transaction in
                                transaction.animation = nil
                                state = value.translation.height
                            }
                            .onChanged { value in
                                onDragChanged(value.translation.height)
                            }
                            .onEnded { _ in
                                onDragEnded()
                            }
                    )

                TextField("", text: $runner.name, axis: .vertical)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .textInputAutocapitalization(.never)
                    .tint(Color.softGreen)
                    .lineLimit(1...4)
                    .padding(.leading, 8)
                    .frame(minWidth: 34, maxWidth: .infinity, minHeight: 50, alignment: .leading)
                    .layoutPriority(0)

                Text(formattedElapsed)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .monospacedDigit()
                    .foregroundStyle(Color.white)
                    .frame(width: 104, alignment: .leading)
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
                        .frame(width: 46, height: 50)
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
                        .frame(width: 50, height: 50)
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
                UnevenRoundedRectangle(
                    topLeadingRadius: 8,
                    bottomLeadingRadius: isExpanded ? 0 : 8,
                    bottomTrailingRadius: isExpanded ? 0 : 8,
                    topTrailingRadius: 8
                )
                .fill(Color(white: 0.11))
                .overlay(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 8,
                        bottomLeadingRadius: isExpanded ? 0 : 8,
                        bottomTrailingRadius: isExpanded ? 0 : 8,
                        topTrailingRadius: 8
                    )
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                onToggleNotes()
            }

            if isExpanded {
                VStack(spacing: 0) {
                    TextField("Notes", text: $runner.workout.notes, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .tint(Color.softGreen)
                        .lineLimit(1...8)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.white.opacity(0.06))
                        )
                        .padding(12)
                }
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 0,
                        bottomLeadingRadius: 8,
                        bottomTrailingRadius: 8,
                        topTrailingRadius: 0
                    )
                    .fill(Color(white: 0.11))
                    .overlay(
                        UnevenRoundedRectangle(
                            topLeadingRadius: 0,
                            bottomLeadingRadius: 8,
                            bottomTrailingRadius: 8,
                            topTrailingRadius: 0
                        )
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                    )
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .top).combined(with: .opacity)
                ))
            }
        }
        .offset(y: isDragging ? fingerOffset : dragOffset)
        .zIndex(isActiveDrag ? 1 : 0)
        .scaleEffect(isActiveDrag ? 1.015 : 1)
        .shadow(color: .black.opacity(isActiveDrag ? 0.28 : 0), radius: 10, x: 0, y: 6)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.9), value: dragOffset)
        .animation(.interactiveSpring(response: 0.24, dampingFraction: 0.9), value: isExpanded)
        .animation(.easeInOut(duration: 0.18), value: runner.isRunning)
    }

    private var formattedElapsed: String {
        let elapsed = max(0, runner.elapsed(at: now))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let hundredths = Int((elapsed * 100).rounded(.down)) % 100

        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }

    private var isActiveDrag: Bool {
        isDragging || fingerOffset != 0
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
                        .tint(Color.softGreen)
                        .frame(minHeight: 28)
                        .scrollContentBackground(.hidden)
                    Text("Elapsed \(formattedElapsed)")
                        .font(.system(.headline, design: .monospaced))
                        .monospacedDigit()
                }

                Section("Notes") {
                    TextField("Workout details, timing cues, splits, etc.", text: $runner.workout.notes, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .tint(Color.softGreen)
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
