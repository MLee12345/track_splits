import SwiftUI

struct RunnerTimer: Identifiable, Equatable {
    let id: UUID
    var name: String
    var elapsedBeforeStart: TimeInterval
    var startedAt: Date?

    init(id: UUID = UUID(), name: String, elapsedBeforeStart: TimeInterval = 0, startedAt: Date? = nil) {
        self.id = id
        self.name = name
        self.elapsedBeforeStart = elapsedBeforeStart
        self.startedAt = startedAt
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

struct ContentView: View {
    @State private var runners: [RunnerTimer] = (1...4).map { RunnerTimer(name: "Runner \($0)") }
    @State private var nextRunnerNumber = 5

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
                                onDelete: { removeRunner(id: runner.id) }
                            )
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                        .padding(.bottom, 104)
                    }
                    .scrollDismissesKeyboard(.interactively)
                }

                Button(action: addRunner) {
                    Image(systemName: "plus")
                        .font(.system(size: 26, weight: .bold))
                        .frame(width: 62, height: 62)
                        .foregroundStyle(.white)
                        .background(Circle().fill(Color.green))
                        .shadow(color: .black.opacity(0.45), radius: 12, x: 0, y: 7)
                }
                .accessibilityLabel("Add runner")
                .padding(.trailing, 20)
                .padding(.bottom, 24)
            }
            .background(Color.black.ignoresSafeArea())
        }
    }

    private var header: some View {
        HStack {
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
    }

    private func addRunner() {
        runners.append(RunnerTimer(name: "Runner \(nextRunnerNumber)"))
        nextRunnerNumber += 1
    }

    private func removeRunner(id: UUID) {
        runners.removeAll { $0.id == id }
    }
}

private struct RunnerCard: View {
    @Binding var runner: RunnerTimer
    let now: Date
    let onDelete: () -> Void

    @FocusState private var nameIsFocused: Bool

    var body: some View {
        HStack(spacing: 6) {
            TextField("Runner", text: $runner.name)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .focused($nameIsFocused)
                .onSubmit { nameIsFocused = false }
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(minWidth: 52, maxWidth: .infinity, alignment: .leading)

            Text(formattedElapsed)
                .font(.system(size: 23, weight: .semibold, design: .monospaced))
                .monospacedDigit()
                .foregroundStyle(runner.isRunning ? Color.yellow : Color.white)
                .opacity(readoutOpacity)
                .frame(width: 91, alignment: .trailing)
                .accessibilityLabel("Elapsed time \(formattedElapsed)")

            Button(action: { runner.toggle(at: Date()) }) {
                Text(runner.isRunning ? "Stop" : "Start")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 54, height: 50)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(runner.isRunning ? Color.red : Color.green)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(runner.isRunning ? "Stop \(runner.name)" : "Start \(runner.name)")

            Button(action: { runner.reset(at: Date()) }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: 17, weight: .bold))
                    .frame(width: 34, height: 50)
                    .foregroundStyle(.white)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.14))
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Reset \(runner.name)")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .bold))
                    .frame(width: 32, height: 50)
                    .foregroundStyle(.white.opacity(0.9))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Delete \(runner.name)")
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.11))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(runner.isRunning ? Color.yellow.opacity(0.8) : Color.white.opacity(0.08), lineWidth: runner.isRunning ? 2 : 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .animation(.easeInOut(duration: 0.18), value: runner.isRunning)
    }

    private var formattedElapsed: String {
        let elapsed = max(0, runner.elapsed(at: now))
        let minutes = Int(elapsed) / 60
        let seconds = Int(elapsed) % 60
        let hundredths = Int((elapsed * 100).rounded(.down)) % 100

        return String(format: "%02d:%02d.%02d", minutes, seconds, hundredths)
    }

    private var readoutOpacity: Double {
        guard runner.isRunning else {
            return 1
        }

        let pulse = sin(now.timeIntervalSinceReferenceDate * 5)
        return 0.86 + ((pulse + 1) / 2) * 0.14
    }
}

#Preview {
    ContentView()
}

